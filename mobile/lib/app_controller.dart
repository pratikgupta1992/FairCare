/// App-wide state: which babies this user has joined, who they are,
/// and their per-baby default caregiver ("role").
///
/// This is the couples-version addition: in the Android app there is
/// a single implicit user. Here, membership and defaults are per
/// user and persisted alongside (but separately from) the shared
/// repository data — with Firebase they will live under
/// `users/{uid}`; locally they live in the same key/value store
/// under a different key.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'reminders.dart';
import 'repository.dart';
import 'theme.dart';

class AppController extends ChangeNotifier {
  AppController(
    this.repo,
    this._prefsStore, {
    this.backendLabel = 'Local (on-device only)',
    this.accountLabel,
    this.onSignOut,
  });

  final FairCareRepository repo;
  final KeyValueStore _prefsStore;

  /// Human-readable backend name, shown in Settings.
  final String backendLabel;

  /// Signed-in account (email) in Firebase mode; null locally.
  final String? accountLabel;

  /// Sign-out action in Firebase mode; null in local mode.
  final Future<void> Function()? onSignOut;

  /// Invoked after reminder settings change, so the app entry
  /// point can (re)build the platform notification schedule.
  /// Null in tests (no platform plugins there).
  void Function()? onRemindersChanged;

  StreamSubscription<void>? _repoSub;

  static const String _prefsKey = 'faircare_user_v1';

  String _userName = 'Me';

  /// Babies this user has created or joined with a connect code.
  final Set<int> _joinedBabyIds = {};

  /// babyId -> caregiverId: this user's default role for that baby.
  final Map<int, int> _defaultCaregiverByBaby = {};

  int? _selectedBabyId;

  ReminderSettings _reminderSettings = const ReminderSettings();

  ThemeMode _themeMode = ThemeMode.system;

  String get userName => _userName;

  /// Appearance choice (Settings → Appearance). Defaults to
  /// [ThemeMode.system] — existing installs have no stored value
  /// and follow the device, which is the behavior Pratik asked
  /// for as the default.
  ThemeMode get themeMode => _themeMode;

  /// Hourly logging-reminder settings (original app's
  /// ReminderPrefs, kept per user/device like the default role).
  ReminderSettings get reminderSettings => _reminderSettings;

  List<Baby> get joinedBabies {
    // Dedupe by id first (a repository cache glitch once surfaced
    // the same baby twice in the Babies list), then defensively by
    // connect code: a code is the join credential and the backend's
    // lookup can only point at one baby, so if two records ever
    // share a code the later one is a phantom — keep the first,
    // which is the one loaded from the backend / pointed to.
    final byId = <int, Baby>{};
    for (final b in repo.babies) {
      if (_joinedBabyIds.contains(b.id)) byId.putIfAbsent(b.id, () => b);
    }
    final seenCodes = <String>{};
    final out = <Baby>[];
    for (final b in byId.values) {
      final code = repo.connectCodeFor(b.id);
      if (code != null && !seenCodes.add(code)) continue;
      out.add(b);
    }
    return out;
  }

  Baby? get selectedBaby {
    final babies = joinedBabies;
    if (babies.isEmpty) return null;
    for (final b in babies) {
      if (b.id == _selectedBabyId) return b;
    }
    return babies.first;
  }

  Future<void> init() async {
    await repo.init();
    final raw = await _prefsStore.read(_prefsKey);
    final isFirstRun = raw == null || raw.isEmpty;
    if (!isFirstRun) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _userName = (j['userName'] as String?) ?? 'Me';
      _joinedBabyIds
        ..clear()
        ..addAll((j['joinedBabyIds'] as List? ?? []).map((e) => e as int));
      _defaultCaregiverByBaby
        ..clear()
        ..addAll((j['defaultCaregiverByBaby'] as Map? ?? {}).map(
            (k, v) => MapEntry(int.parse(k as String), v as int)));
      _selectedBabyId = j['selectedBabyId'] as int?;
      _reminderSettings = ReminderSettings(
        enabled: (j['remindersEnabled'] as bool?) ?? false,
        quietStartMin:
            (j['quietStartMin'] as int?) ?? const ReminderSettings().quietStartMin,
        quietEndMin:
            (j['quietEndMin'] as int?) ?? const ReminderSettings().quietEndMin,
      );
      _themeMode = themeModeFromName(j['themeMode'] as String?);
    }
    // First run on this device: every baby the backend already
    // shows this user counts as joined — locally that's the seeded
    // baby (its creator); on Firestore the query only returns
    // babies whose memberUids contain this user, i.e. exactly the
    // ones they created or joined before (e.g. on another phone).
    if (isFirstRun) {
      _joinedBabyIds.addAll(repo.babies.map((b) => b.id));
    }
    // Drop memberships/defaults for babies that no longer exist.
    final existing = repo.babies.map((b) => b.id).toSet();
    _joinedBabyIds.retainAll(existing);
    _defaultCaregiverByBaby.removeWhere((k, _) => !existing.contains(k));
    await _savePrefs();
    // Realtime: when the backend announces new data (e.g. a
    // Firestore snapshot with the other parent's entries), rebuild.
    _repoSub = repo.changes.listen((_) {
      final existingNow = repo.babies.map((b) => b.id).toSet();
      _joinedBabyIds.retainAll(existingNow);
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _repoSub?.cancel();
    super.dispose();
  }

  Future<void> _savePrefs() async {
    await _prefsStore.write(
      _prefsKey,
      jsonEncode({
        'userName': _userName,
        'joinedBabyIds': _joinedBabyIds.toList(),
        'defaultCaregiverByBaby': _defaultCaregiverByBaby
            .map((k, v) => MapEntry(k.toString(), v)),
        'selectedBabyId': _selectedBabyId,
        'remindersEnabled': _reminderSettings.enabled,
        'quietStartMin': _reminderSettings.quietStartMin,
        'quietEndMin': _reminderSettings.quietEndMin,
        'themeMode': themeModeName(_themeMode),
      }),
    );
  }

  Future<void> setRemindersEnabled(bool enabled,
      {bool notifyService = true}) async {
    _reminderSettings = _reminderSettings.copyWith(enabled: enabled);
    await _savePrefs();
    notifyListeners();
    if (notifyService) onRemindersChanged?.call();
  }

  Future<void> setQuietHours(int startMin, int endMin) async {
    _reminderSettings = _reminderSettings.copyWith(
        quietStartMin: startMin, quietEndMin: endMin);
    await _savePrefs();
    notifyListeners();
    onRemindersChanged?.call();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim().isEmpty ? 'Me' : name.trim();
    await _savePrefs();
    notifyListeners();
  }

  void selectBaby(int babyId) {
    _selectedBabyId = babyId;
    _savePrefs();
    notifyListeners();
  }

  /// In-flight create, used to coalesce concurrent calls (e.g. a
  /// double-tap on a create button that has no busy state of its
  /// own) into a single baby instead of two.
  Future<Baby>? _createInFlight;

  /// Creates a baby (repository generates its connect code) and
  /// joins the current user to it. Concurrent calls share the
  /// in-flight create and all resolve to the same baby.
  Future<Baby> createBaby(String name, {int? color}) async {
    final inFlight = _createInFlight;
    if (inFlight != null) return inFlight;
    final future = _createBaby(name, color: color);
    _createInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_createInFlight, future)) _createInFlight = null;
    }
  }

  Future<Baby> _createBaby(String name, {int? color}) async {
    final baby = await repo.createBaby(name, color: color);
    _joinedBabyIds.add(baby.id);
    _selectedBabyId = baby.id;
    await _savePrefs();
    notifyListeners();
    return baby;
  }

  /// Joins the baby identified by [code]. Returns the baby, or null
  /// when the code doesn't match any baby.
  Future<Baby?> joinBabyByCode(String code) async {
    final baby = await repo.joinWithCode(code);
    if (baby == null) return null;
    _joinedBabyIds.add(baby.id);
    _selectedBabyId = baby.id;
    await _savePrefs();
    notifyListeners();
    return baby;
  }

  bool isJoined(int babyId) => _joinedBabyIds.contains(babyId);

  // --- Default role (default caregiver per baby) ---

  /// This user's default caregiver for [babyId], or null if unset.
  int? defaultCaregiverIdFor(int babyId) => _defaultCaregiverByBaby[babyId];

  Caregiver? defaultCaregiverFor(int babyId) {
    final id = _defaultCaregiverByBaby[babyId];
    if (id == null) return null;
    return repo.caregiverById[id];
  }

  Future<void> setDefaultCaregiver(int babyId, int? caregiverId) async {
    if (caregiverId == null) {
      _defaultCaregiverByBaby.remove(babyId);
    } else {
      _defaultCaregiverByBaby[babyId] = caregiverId;
    }
    await _savePrefs();
    notifyListeners();
  }

  /// Call after any repository mutation so screens rebuild.
  void refresh() => notifyListeners();
}

/// Tiny accessor so screens don't need a state-management package.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
