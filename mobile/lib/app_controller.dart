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

import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'models.dart';
import 'repository.dart';

class AppController extends ChangeNotifier {
  AppController(this.repo, this._prefsStore);

  final FairCareRepository repo;
  final KeyValueStore _prefsStore;

  static const String _prefsKey = 'faircare_user_v1';

  String _userName = 'Me';

  /// Babies this user has created or joined with a connect code.
  final Set<int> _joinedBabyIds = {};

  /// babyId -> caregiverId: this user's default role for that baby.
  final Map<int, int> _defaultCaregiverByBaby = {};

  int? _selectedBabyId;

  String get userName => _userName;

  List<Baby> get joinedBabies =>
      repo.babies.where((b) => _joinedBabyIds.contains(b.id)).toList();

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
    if (raw != null && raw.isNotEmpty) {
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
    }
    // First run: the seeded baby counts as joined by its creator.
    if (_joinedBabyIds.isEmpty && repo.babies.isNotEmpty) {
      _joinedBabyIds.add(repo.babies.first.id);
    }
    // Drop memberships/defaults for babies that no longer exist.
    final existing = repo.babies.map((b) => b.id).toSet();
    _joinedBabyIds.retainAll(existing);
    _defaultCaregiverByBaby.removeWhere((k, _) => !existing.contains(k));
    await _savePrefs();
    notifyListeners();
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
      }),
    );
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

  /// Creates a baby (repository generates its connect code) and
  /// joins the current user to it.
  Future<Baby> createBaby(String name) async {
    final baby = await repo.createBaby(name);
    _joinedBabyIds.add(baby.id);
    _selectedBabyId = baby.id;
    await _savePrefs();
    notifyListeners();
    return baby;
  }

  /// Joins the baby identified by [code]. Returns the baby, or null
  /// when the code doesn't match any baby.
  Future<Baby?> joinBabyByCode(String code) async {
    final baby = repo.babyForCode(code);
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
