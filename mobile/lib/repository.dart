/// Backend abstraction for FairCare.
///
/// The couples app talks to data only through [FairCareRepository].
/// Today the working implementation is [LocalFairCareRepository]
/// (on-device, JSON-persisted). The Firebase implementation
/// (see `firebase_repository_stub.dart`) will implement this same
/// interface once a Firebase project exists, so no screen code
/// changes when the backend swaps.
library;

import 'dart:convert';
import 'dart:math';

import 'models.dart';

/// Minimal key/value storage so the repository can persist without
/// depending directly on a platform plugin (tests use the in-memory
/// implementation).
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

abstract class FairCareRepository {
  Future<void> init();

  List<Baby> get babies;
  List<Caregiver> get caregivers;
  List<CareTask> get tasks;

  /// All entries, oldest first.
  List<LogEntry> get entries;
  List<LogEntry> entriesForBaby(int babyId);

  Map<int, CareTask> get taskById;
  Map<int, Caregiver> get caregiverById;

  // --- Babies & connect codes ---
  /// Creates a baby and generates its connect code.
  Future<Baby> createBaby(String name, {int? color});
  Future<void> deleteBaby(int babyId);

  /// The connect code for [babyId], or null if none exists.
  String? connectCodeFor(int babyId);

  /// Generates a fresh connect code for [babyId], invalidating the
  /// old one. Returns the new code.
  Future<String> regenerateConnectCode(int babyId);

  /// Looks up a baby by its connect code (case-insensitive).
  Baby? babyForCode(String code);

  // --- Caregivers & tasks ---
  Future<Caregiver> addCaregiver(String name, CaregiverType type, int color);
  Future<CareTask> addTask(CareTask task);

  // --- Entries ---
  Future<LogEntry> addEntry(LogEntry entry);
  Future<void> updateEntry(LogEntry entry);
  Future<void> deleteEntry(int entryId);
}

/// Alphabet for connect codes: no easily-confused characters
/// (no 0/O, 1/I/L).
const String connectCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int connectCodeLength = 6;

String generateConnectCode(Random rng, Set<String> taken) {
  var code = '';
  do {
    code = List.generate(connectCodeLength,
        (_) => connectCodeAlphabet[rng.nextInt(connectCodeAlphabet.length)]).join();
  } while (taken.contains(code));
  return code;
}

/// Working local backend: everything lives on this device, persisted
/// as a single JSON blob in the [KeyValueStore].
///
/// NOTE on connect codes: in the Firebase version, codes are
/// generated and resolved server-side (Firestore). Here they are
/// generated locally, which is enough to build and test the full
/// create/join UX on one device.
class LocalFairCareRepository implements FairCareRepository {
  LocalFairCareRepository(this._store, {Random? random})
      : _rng = random ?? Random.secure();

  /// In-memory only — handy for tests and previews.
  factory LocalFairCareRepository.memory() =>
      LocalFairCareRepository(MemoryKeyValueStore());

  static const String _storageKey = 'faircare_local_state_v1';

  final KeyValueStore _store;
  final Random _rng;

  final List<Baby> _babies = [];
  final List<Caregiver> _caregivers = [];
  final List<CareTask> _tasks = [];
  final List<LogEntry> _entries = [];
  final Map<int, String> _codes = {}; // babyId -> connect code

  int _nextBabyId = 1;
  int _nextCaregiverId = 1;
  int _nextTaskId = 1;
  int _nextEntryId = 1;

  @override
  Future<void> init() async {
    final raw = await _store.read(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      _loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } else {
      _seed();
      await _save();
    }
  }

  void _seed() {
    // Same seed data as the Android app's Db.ensureSeeded().
    _caregivers.add(Caregiver(
        id: _nextCaregiverId++,
        name: 'Mom',
        type: CaregiverType.mother,
        color: 0xFFE57373));
    _caregivers.add(Caregiver(
        id: _nextCaregiverId++,
        name: 'Dad',
        type: CaregiverType.father,
        color: 0xFF64B5F6));
    for (final t in defaultTasks()) {
      _tasks.add(t.copyWith(id: _nextTaskId++));
    }
    final baby = Baby(id: _nextBabyId++, name: 'Baby', color: 0xFFFFD54F);
    _babies.add(baby);
    _codes[baby.id] = generateConnectCode(_rng, _codes.values.toSet());
  }

  void _loadFromJson(Map<String, dynamic> j) {
    _babies
      ..clear()
      ..addAll((j['babies'] as List).map(
          (e) => Baby.fromJson((e as Map).cast<String, dynamic>())));
    _caregivers
      ..clear()
      ..addAll((j['caregivers'] as List).map(
          (e) => Caregiver.fromJson((e as Map).cast<String, dynamic>())));
    _tasks
      ..clear()
      ..addAll((j['tasks'] as List).map(
          (e) => CareTask.fromJson((e as Map).cast<String, dynamic>())));
    _entries
      ..clear()
      ..addAll((j['entries'] as List).map(
          (e) => LogEntry.fromJson((e as Map).cast<String, dynamic>())));
    _codes
      ..clear()
      ..addAll((j['codes'] as Map).map(
          (k, v) => MapEntry(int.parse(k as String), v as String)));
    _nextBabyId = j['nextBabyId'] as int;
    _nextCaregiverId = j['nextCaregiverId'] as int;
    _nextTaskId = j['nextTaskId'] as int;
    _nextEntryId = j['nextEntryId'] as int;
  }

  Future<void> _save() async {
    final j = <String, dynamic>{
      'babies': _babies.map((b) => b.toJson()).toList(),
      'caregivers': _caregivers.map((c) => c.toJson()).toList(),
      'tasks': _tasks.map((t) => t.toJson()).toList(),
      'entries': _entries.map((e) => e.toJson()).toList(),
      'codes': _codes.map((k, v) => MapEntry(k.toString(), v)),
      'nextBabyId': _nextBabyId,
      'nextCaregiverId': _nextCaregiverId,
      'nextTaskId': _nextTaskId,
      'nextEntryId': _nextEntryId,
    };
    await _store.write(_storageKey, jsonEncode(j));
  }

  @override
  List<Baby> get babies => List.unmodifiable(_babies);
  @override
  List<Caregiver> get caregivers => List.unmodifiable(_caregivers);
  @override
  List<CareTask> get tasks {
    final t = List<CareTask>.of(_tasks)
      ..sort((a, b) => a.sort != b.sort
          ? a.sort.compareTo(b.sort)
          : a.id.compareTo(b.id));
    return List.unmodifiable(t);
  }

  @override
  List<LogEntry> get entries {
    final e = List<LogEntry>.of(_entries)
      ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
    return List.unmodifiable(e);
  }

  @override
  List<LogEntry> entriesForBaby(int babyId) =>
      entries.where((e) => e.babyId == babyId).toList();

  @override
  Map<int, CareTask> get taskById => {for (final t in _tasks) t.id: t};
  @override
  Map<int, Caregiver> get caregiverById =>
      {for (final c in _caregivers) c.id: c};

  @override
  Future<Baby> createBaby(String name, {int? color}) async {
    final baby = Baby(
        id: _nextBabyId++,
        name: name.trim(),
        color: color ?? 0xFFFFD54F);
    _babies.add(baby);
    _codes[baby.id] = generateConnectCode(_rng, _codes.values.toSet());
    await _save();
    return baby;
  }

  @override
  Future<void> deleteBaby(int babyId) async {
    _entries.removeWhere((e) => e.babyId == babyId);
    _babies.removeWhere((b) => b.id == babyId);
    _codes.remove(babyId);
    await _save();
  }

  @override
  String? connectCodeFor(int babyId) => _codes[babyId];

  @override
  Future<String> regenerateConnectCode(int babyId) async {
    final code = generateConnectCode(_rng, _codes.values.toSet());
    _codes[babyId] = code;
    await _save();
    return code;
  }

  @override
  Baby? babyForCode(String code) {
    final norm = code.trim().toUpperCase();
    for (final entry in _codes.entries) {
      if (entry.value == norm) {
        return _babies.where((b) => b.id == entry.key).firstOrNull;
      }
    }
    return null;
  }

  @override
  Future<Caregiver> addCaregiver(
      String name, CaregiverType type, int color) async {
    final cg = Caregiver(
        id: _nextCaregiverId++, name: name.trim(), type: type, color: color);
    _caregivers.add(cg);
    await _save();
    return cg;
  }

  @override
  Future<CareTask> addTask(CareTask task) async {
    final t = task.copyWith(id: _nextTaskId++);
    _tasks.add(t);
    await _save();
    return t;
  }

  @override
  Future<LogEntry> addEntry(LogEntry entry) async {
    final e = entry.copyWith(id: _nextEntryId++);
    _entries.add(e);
    await _save();
    return e;
  }

  @override
  Future<void> updateEntry(LogEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) {
      _entries[i] = entry;
      await _save();
    }
  }

  @override
  Future<void> deleteEntry(int entryId) async {
    _entries.removeWhere((e) => e.id == entryId);
    await _save();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
