/// Firebase backend — Cloud Firestore implementation of
/// [FairCareRepository] (replaces the scaffold's stub).
///
/// Schema (must stay in sync with `firestore.rules` next to
/// pubspec.yaml):
///   babies/{babyId}                  {id, name, color, connectCode,
///                                     memberUids: [uid...], createdBy,
///                                     createdAt, updatedAt}
///   babies/{babyId}/caregivers/{id} Caregiver fields (models.dart codec)
///   babies/{babyId}/tasks/{id}      CareTask fields (ditto)
///   babies/{babyId}/entries/{id}    LogEntry fields + createdAt/updatedAt
///   connectCodes/{CODE}              {babyId} — join lookup; the code
///                                    itself is the secret.
///
/// How it fits the (synchronous, cache-backed) interface:
/// - [init] does a one-shot load of everything this user can see,
///   then attaches Firestore snapshot listeners. All reads in the
///   app are served from the in-memory caches those listeners keep
///   current — that's the realtime path: when the other parent logs
///   an entry, a snapshot lands here, the cache updates, [changes]
///   emits, and the controller rebuilds the UI.
/// - Writes go to Firestore first, then are mirrored into the cache
///   immediately (the listener echo that follows writes the same
///   values again, so it is idempotent).
/// - Ids: the app model uses int ids (ported from the Android app).
///   Firestore document ids are those ints as strings. New ids are
///   epoch-millis — unique enough across a family's devices. Each
///   baby seeds its own caregivers (Mom id 1, Dad id 2) and the 12
///   default tasks (ids 1–12); the global `caregivers`/`tasks`
///   getters merge per-baby lists and dedupe by id, matching the
///   local repository's global view.
/// - Known adaptation: the interface's `addCaregiver`/`addTask`
///   have no baby parameter (caregivers/tasks are global in the
///   local model), so on Firestore a new caregiver/task is written
///   into EVERY baby this user belongs to (same id everywhere, so
///   the merged getter stays consistent).
library;

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'repository.dart';

class FirestoreFairCareRepository implements FairCareRepository {
  FirestoreFairCareRepository({
    FirebaseFirestore? firestore,
    required this.uidProvider,
    Random? random,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _rng = random ?? Random.secure();

  final FirebaseFirestore _db;

  /// Supplies the signed-in user's uid (injected so the repository
  /// itself never depends on FirebaseAuth).
  final String Function() uidProvider;
  final Random _rng;

  final StreamController<void> _changes = StreamController.broadcast();

  final List<Baby> _babies = [];
  final Map<int, String> _codes = {}; // babyId -> connect code
  final Map<int, Map<int, Caregiver>> _caregiversByBaby = {};
  final Map<int, Map<int, CareTask>> _tasksByBaby = {};
  final Map<int, Map<int, LogEntry>> _entriesByBaby = {};

  /// Caregivers/tasks added before the user has any baby (rare —
  /// Settings is only reachable after onboarding). Kept in memory
  /// for this session so the getters stay honest.
  final Map<int, Caregiver> _extraCaregivers = {};
  final Map<int, CareTask> _extraTasks = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _babiesSub;
  final Map<int, List<StreamSubscription<dynamic>>> _babySubs = {};

  String get _uid => uidProvider();

  CollectionReference<Map<String, dynamic>> get _babiesCol =>
      _db.collection('babies');
  CollectionReference<Map<String, dynamic>> get _codesCol =>
      _db.collection('connectCodes');
  CollectionReference<Map<String, dynamic>> _sub(
          int babyId, String name) =>
      _babiesCol.doc('$babyId').collection(name);

  @override
  Stream<void> get changes => _changes.stream;

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  // ------------------------------------------------------------------
  // Init / listeners
  // ------------------------------------------------------------------

  @override
  Future<void> init() async {
    final query = _babiesCol.where('memberUids', arrayContains: _uid);
    // One-shot load first so the getters are populated when init()
    // returns; snapshot listeners then keep the caches live.
    final snap = await query.get();
    _applyBabies(snap.docs);
    for (final b in _babies) {
      await _loadSubcollectionsOnce(b.id);
    }
    _babiesSub = query.snapshots().listen((s) {
      _applyBabies(s.docs);
      _emit();
    });
    for (final b in _babies) {
      _subscribeSubcollections(b.id);
    }
    _emit();
  }

  /// Inserts [baby] into the cache, or replaces the cached copy
  /// with the same id. Every cache write goes through here so a
  /// baby id can never occupy two slots at once.
  void _upsertBaby(Baby baby) {
    final i = _babies.indexWhere((b) => b.id == baby.id);
    if (i >= 0) {
      _babies[i] = baby;
    } else {
      _babies.add(baby);
    }
  }

  void _applyBabies(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final seen = <int>{};
    for (final doc in docs) {
      final d = doc.data();
      final baby = Baby(
        id: (d['id'] as num).toInt(),
        name: d['name'] as String,
        color: (d['color'] as num).toInt(),
      );
      seen.add(baby.id);
      _upsertBaby(baby);
      final code = d['connectCode'] as String?;
      if (code != null) _codes[baby.id] = code;
    }
    // Self-heal: if a duplicate id ever slipped into the cache
    // (createBaby's mirror step used to add unconditionally while
    // the snapshot listener applied the same document — the baby
    // then rendered twice for the rest of the session), drop the
    // later copies here.
    final cachedIds = <int>{};
    _babies.removeWhere((b) => !cachedIds.add(b.id));
    // Babies that disappeared (deleted / membership removed).
    for (final b in _babies.where((b) => !seen.contains(b.id)).toList()) {
      _babies.removeWhere((x) => x.id == b.id);
      _codes.remove(b.id);
      _caregiversByBaby.remove(b.id);
      _tasksByBaby.remove(b.id);
      _entriesByBaby.remove(b.id);
      _cancelBabySubs(b.id);
    }
  }

  Future<void> _loadSubcollectionsOnce(int babyId) async {
    // The stored field shapes match the models.dart codecs exactly
    // (extra server-timestamp fields are ignored by fromJson).
    final cg = await _sub(babyId, 'caregivers').get();
    _caregiversByBaby[babyId] = {
      for (final d in cg.docs)
        (d.data()['id'] as num).toInt(): Caregiver.fromJson(d.data()),
    };
    final tk = await _sub(babyId, 'tasks').get();
    _tasksByBaby[babyId] = {
      for (final d in tk.docs)
        (d.data()['id'] as num).toInt(): CareTask.fromJson(d.data()),
    };
    final en = await _sub(babyId, 'entries').get();
    _entriesByBaby[babyId] = {
      for (final d in en.docs)
        (d.data()['id'] as num).toInt(): LogEntry.fromJson(d.data()),
    };
  }

  void _subscribeSubcollections(int babyId) {
    if (_babySubs.containsKey(babyId)) return;
    _babySubs[babyId] = [
      _sub(babyId, 'caregivers').snapshots().listen((s) {
        _caregiversByBaby[babyId] = {
          for (final d in s.docs)
            (d.data()['id'] as num).toInt():
                Caregiver.fromJson(d.data()),
        };
        _emit();
      }),
      _sub(babyId, 'tasks').snapshots().listen((s) {
        _tasksByBaby[babyId] = {
          for (final d in s.docs)
            (d.data()['id'] as num).toInt(): CareTask.fromJson(d.data()),
        };
        _emit();
      }),
      _sub(babyId, 'entries').snapshots().listen((s) {
        _entriesByBaby[babyId] = {
          for (final d in s.docs)
            (d.data()['id'] as num).toInt(): LogEntry.fromJson(d.data()),
        };
        _emit();
      }),
    ];
  }

  void _cancelBabySubs(int babyId) {
    final subs = _babySubs.remove(babyId);
    if (subs != null) {
      for (final s in subs) {
        s.cancel();
      }
    }
  }

  /// Cancels all listeners (app/session teardown; not part of the
  /// repository interface).
  Future<void> close() async {
    await _babiesSub?.cancel();
    for (final id in _babySubs.keys.toList()) {
      _cancelBabySubs(id);
    }
    await _changes.close();
  }

  // ------------------------------------------------------------------
  // Cache-backed getters
  // ------------------------------------------------------------------

  @override
  List<Baby> get babies {
    // Final safety net: never hand out the same baby id twice,
    // even if a duplicate somehow reaches the cache.
    final seen = <int>{};
    return List.unmodifiable(_babies.where((b) => seen.add(b.id)));
  }

  @override
  List<Caregiver> get caregivers {
    final merged = <int, Caregiver>{};
    for (final b in _babies) {
      final per = _caregiversByBaby[b.id];
      if (per == null) continue;
      final sorted = per.values.toList()
        ..sort((a, b2) => a.id.compareTo(b2.id));
      for (final c in sorted) {
        merged.putIfAbsent(c.id, () => c);
      }
    }
    for (final c in _extraCaregivers.values) {
      merged.putIfAbsent(c.id, () => c);
    }
    return List.unmodifiable(merged.values.toList());
  }

  @override
  List<CareTask> get tasks {
    final merged = <int, CareTask>{};
    for (final b in _babies) {
      final per = _tasksByBaby[b.id];
      if (per == null) continue;
      for (final t in per.values) {
        merged.putIfAbsent(t.id, () => t);
      }
    }
    for (final t in _extraTasks.values) {
      merged.putIfAbsent(t.id, () => t);
    }
    final list = merged.values.toList()
      ..sort((a, b) =>
          a.sort != b.sort ? a.sort.compareTo(b.sort) : a.id.compareTo(b.id));
    return List.unmodifiable(list);
  }

  @override
  List<LogEntry> get entries {
    final all = <LogEntry>[
      for (final per in _entriesByBaby.values) ...per.values,
    ]..sort((a, b) => a.startMillis.compareTo(b.startMillis));
    return List.unmodifiable(all);
  }

  @override
  List<LogEntry> entriesForBaby(int babyId) =>
      entries.where((e) => e.babyId == babyId).toList();

  @override
  Map<int, CareTask> get taskById => {for (final t in tasks) t.id: t};

  @override
  Map<int, Caregiver> get caregiverById =>
      {for (final c in caregivers) c.id: c};

  // ------------------------------------------------------------------
  // Babies & connect codes
  // ------------------------------------------------------------------

  int _newId(Set<int> taken) {
    var id = DateTime.now().millisecondsSinceEpoch;
    while (taken.contains(id)) {
      id++;
    }
    return id;
  }

  Future<String> _uniqueCode() async {
    final takenLocal = _codes.values.toSet();
    var code = generateConnectCode(_rng, takenLocal);
    // generateConnectCode only knows this device's cache; verify
    // against the server-side lookup collection before using it.
    while (true) {
      final doc = await _codesCol.doc(code).get();
      if (!doc.exists) return code;
      code = generateConnectCode(_rng, {...takenLocal, code});
    }
  }

  @override
  Future<Baby> createBaby(String name, {int? color}) async {
    final id = _newId(_babies.map((b) => b.id).toSet());
    final code = await _uniqueCode();
    final baby =
        Baby(id: id, name: name.trim(), color: color ?? 0xFFFFD54F);
    final ref = _babiesCol.doc('$id');
    // Phase 1: the baby doc alone. The firestore.rules for
    // connectCodes/subcollections check membership via get() on
    // the baby doc, and rule get() calls see the PRE-batch state —
    // so the baby must exist before anything that references it.
    await ref.set({
      'id': baby.id,
      'name': baby.name,
      'color': baby.color,
      'connectCode': code,
      'memberUids': [_uid],
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Phase 2: connect-code lookup doc + seed subcollections.
    final batch = _db.batch();
    batch.set(_codesCol.doc(code), {
      'babyId': id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Seed the same starter caregivers/tasks the local app uses.
    final seedCaregivers = [
      const Caregiver(
          id: 1, name: 'Mom', type: CaregiverType.mother, color: 0xFFE57373),
      const Caregiver(
          id: 2, name: 'Dad', type: CaregiverType.father, color: 0xFF64B5F6),
    ];
    for (final cg in seedCaregivers) {
      batch.set(ref.collection('caregivers').doc('${cg.id}'), cg.toJson());
    }
    var taskId = 1;
    for (final t in defaultTasks()) {
      final seeded = t.copyWith(id: taskId++);
      batch.set(
          ref.collection('tasks').doc('${seeded.id}'), seeded.toJson());
    }
    await batch.commit();

    // Mirror into the caches so getters are correct immediately.
    // Upsert, never blindly add: the snapshot listener may already
    // have applied this same document (Firestore delivers
    // latency-compensated local snapshots for our own writes,
    // usually before this mirror step runs), and an unconditional
    // add surfaced the baby twice in the list for the session.
    _upsertBaby(baby);
    _codes[id] = code;
    _caregiversByBaby[id] = {for (final cg in seedCaregivers) cg.id: cg};
    _tasksByBaby[id] = {
      for (var i = 0; i < defaultTasks().length; i++)
        i + 1: defaultTasks()[i].copyWith(id: i + 1),
    };
    _entriesByBaby[id] = {};
    _subscribeSubcollections(id);
    _emit();
    return baby;
  }

  @override
  Future<void> deleteBaby(int babyId) async {
    final ref = _babiesCol.doc('$babyId');
    final batch = _db.batch();
    for (final name in ['caregivers', 'tasks', 'entries']) {
      final s = await ref.collection(name).get();
      for (final d in s.docs) {
        batch.delete(d.reference);
      }
    }
    final code = _codes[babyId];
    if (code != null) batch.delete(_codesCol.doc(code));
    batch.delete(ref);
    await batch.commit();

    _cancelBabySubs(babyId);
    _babies.removeWhere((b) => b.id == babyId);
    _codes.remove(babyId);
    _caregiversByBaby.remove(babyId);
    _tasksByBaby.remove(babyId);
    _entriesByBaby.remove(babyId);
    _emit();
  }

  @override
  String? connectCodeFor(int babyId) => _codes[babyId];

  @override
  Future<String> regenerateConnectCode(int babyId) async {
    final fresh = await _uniqueCode();
    final batch = _db.batch();
    final old = _codes[babyId];
    if (old != null) batch.delete(_codesCol.doc(old));
    batch.set(_codesCol.doc(fresh), {
      'babyId': babyId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_babiesCol.doc('$babyId'), {
      'connectCode': fresh,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    _codes[babyId] = fresh;
    _emit();
    return fresh;
  }

  @override
  Future<Baby?> joinWithCode(String code) async {
    final norm = normalizeConnectCode(code);
    if (norm.isEmpty) return null;
    final codeDoc = await _codesCol.doc(norm).get();
    if (!codeDoc.exists) return null;
    final babyId = (codeDoc.data()!['babyId'] as num).toInt();
    final ref = _babiesCol.doc('$babyId');
    // Joining = adding my uid to memberUids. After this write the
    // security rules let me read the baby and its subcollections.
    await ref.update({
      'memberUids': FieldValue.arrayUnion([_uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    if (!snap.exists) return null;
    final d = snap.data()!;
    final baby = Baby(
      id: (d['id'] as num).toInt(),
      name: d['name'] as String,
      color: (d['color'] as num).toInt(),
    );
    if (_babies.every((b) => b.id != baby.id)) _babies.add(baby);
    final c = d['connectCode'] as String?;
    if (c != null) _codes[baby.id] = c;
    await _loadSubcollectionsOnce(baby.id);
    _subscribeSubcollections(baby.id);
    _emit();
    return baby;
  }

  // ------------------------------------------------------------------
  // Caregivers & tasks (global in the interface; written per baby —
  // see the library comment)
  // ------------------------------------------------------------------

  @override
  Future<Caregiver> addCaregiver(
      String name, CaregiverType type, int color) async {
    final cg = Caregiver(
      id: _newId(caregiverById.keys.toSet()),
      name: name.trim(),
      type: type,
      color: color,
    );
    if (_babies.isEmpty) {
      _extraCaregivers[cg.id] = cg;
    } else {
      final batch = _db.batch();
      for (final b in _babies) {
        batch.set(_sub(b.id, 'caregivers').doc('${cg.id}'), cg.toJson());
        (_caregiversByBaby[b.id] ??= {})[cg.id] = cg;
      }
      await batch.commit();
    }
    _emit();
    return cg;
  }

  @override
  Future<CareTask> addTask(CareTask task) async {
    final t = task.copyWith(id: _newId(taskById.keys.toSet()));
    if (_babies.isEmpty) {
      _extraTasks[t.id] = t;
    } else {
      final batch = _db.batch();
      for (final b in _babies) {
        batch.set(_sub(b.id, 'tasks').doc('${t.id}'), t.toJson());
        (_tasksByBaby[b.id] ??= {})[t.id] = t;
      }
      await batch.commit();
    }
    _emit();
    return t;
  }

  // ------------------------------------------------------------------
  // Entries
  // ------------------------------------------------------------------

  @override
  Future<LogEntry> addEntry(LogEntry entry) async {
    final per = _entriesByBaby[entry.babyId] ??= {};
    final e = entry.copyWith(
      id: _newId(per.keys.toSet()),
      createdBy: entry.createdBy.isEmpty ? _uid : entry.createdBy,
    );
    await _sub(entry.babyId, 'entries').doc('${e.id}').set({
      ...e.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    per[e.id] = e;
    _emit();
    return e;
  }

  @override
  Future<void> updateEntry(LogEntry entry) async {
    await _sub(entry.babyId, 'entries').doc('${entry.id}').update({
      ...entry.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    (_entriesByBaby[entry.babyId] ??= {})[entry.id] = entry;
    _emit();
  }

  @override
  Future<void> deleteEntry(int entryId) async {
    for (final per in _entriesByBaby.entries) {
      if (per.value.containsKey(entryId)) {
        await _sub(per.key, 'entries').doc('$entryId').delete();
        per.value.remove(entryId);
        _emit();
        return;
      }
    }
  }
}
