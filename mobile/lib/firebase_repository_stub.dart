/// Firebase backend — STUB, not yet wired.
///
/// This class marks exactly where the real backend will plug in.
/// It is **not** used by the app today (the app runs on
/// [LocalFairCareRepository]) and contains **no** Firebase config
/// — do not invent `google-services.json` / `GoogleService-Info.plist`
/// values; they come from the Firebase project Pratik creates under
/// his own Google account (see COUPLES_SPEC.md and BUILD_NOTES.md).
///
/// Planned mapping (Firebase Auth + Cloud Firestore, Spark tier):
///   users/{uid}                     profile + display name
///   babies/{babyId}                 name, color, connectCode, memberUids
///   babies/{babyId}/caregivers/{id} Caregiver docs
///   babies/{babyId}/tasks/{id}      CareTask docs
///   babies/{babyId}/entries/{id}    LogEntry docs (+ createdBy uid)
///   connectCodes/{code}             -> babyId (lookup doc for joins)
///
/// Firestore's realtime listeners + offline persistence replace the
/// local repository's JSON save; the screens keep using this same
/// interface, with lists exposed the same way.
library;

import 'models.dart';
import 'repository.dart';

class FirebaseFairCareRepository implements FairCareRepository {
  FirebaseFairCareRepository();

  static const String _todo =
      'Firebase is not wired yet: create the Firebase project, add the '
      'FlutterFire config, then implement this class (see BUILD_NOTES.md).';

  @override
  Future<void> init() => throw UnimplementedError(_todo);

  @override
  List<Baby> get babies => throw UnimplementedError(_todo);
  @override
  List<Caregiver> get caregivers => throw UnimplementedError(_todo);
  @override
  List<CareTask> get tasks => throw UnimplementedError(_todo);
  @override
  List<LogEntry> get entries => throw UnimplementedError(_todo);
  @override
  List<LogEntry> entriesForBaby(int babyId) =>
      throw UnimplementedError(_todo);
  @override
  Map<int, CareTask> get taskById => throw UnimplementedError(_todo);
  @override
  Map<int, Caregiver> get caregiverById =>
      throw UnimplementedError(_todo);
  @override
  Future<Baby> createBaby(String name, {int? color}) =>
      throw UnimplementedError(_todo);
  @override
  Future<void> deleteBaby(int babyId) => throw UnimplementedError(_todo);
  @override
  String? connectCodeFor(int babyId) => throw UnimplementedError(_todo);
  @override
  Future<String> regenerateConnectCode(int babyId) =>
      throw UnimplementedError(_todo);
  @override
  Baby? babyForCode(String code) => throw UnimplementedError(_todo);
  @override
  Future<Caregiver> addCaregiver(
          String name, CaregiverType type, int color) =>
      throw UnimplementedError(_todo);
  @override
  Future<CareTask> addTask(CareTask task) =>
      throw UnimplementedError(_todo);
  @override
  Future<LogEntry> addEntry(LogEntry entry) =>
      throw UnimplementedError(_todo);
  @override
  Future<void> updateEntry(LogEntry entry) =>
      throw UnimplementedError(_todo);
  @override
  Future<void> deleteEntry(int entryId) =>
      throw UnimplementedError(_todo);
}
