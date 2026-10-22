// Regression tests for the duplicate-baby bug (Oct 21, 2026):
// the Babies screen listed "Nyra — Connect code: AW6FN7" twice.
//
// Root cause was in the Firestore repository's cache: createBaby
// mirrored the new baby into the cache with an unconditional add
// while the snapshot listener applied the same document, so one
// baby occupied two slots. The repository now upserts, and these
// tests pin the controller-level safety net: joinedBabies never
// renders the same baby id — or the same connect code — twice,
// and concurrent createBaby calls coalesce into one create.
import 'dart:async';

import 'package:faircare/app_controller.dart';
import 'package:faircare/models.dart';
import 'package:faircare/repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal fake whose babies list can contain the corruption
/// shapes the real backend produced / could produce.
class FakeRepository implements FairCareRepository {
  FakeRepository(this._babies, this._codes);

  final List<Baby> _babies;
  final Map<int, String> _codes;

  int createCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  List<Baby> get babies => _babies;

  @override
  List<Caregiver> get caregivers => const [];

  @override
  List<CareTask> get tasks => const [];

  @override
  List<LogEntry> get entries => const [];

  @override
  List<LogEntry> entriesForBaby(int babyId) => const [];

  @override
  Map<int, CareTask> get taskById => const {};

  @override
  Map<int, Caregiver> get caregiverById => const {};

  @override
  Future<Baby> createBaby(String name, {int? color}) async {
    createCalls++;
    // Simulate a slow network create so concurrent calls overlap.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final baby = Baby(id: 100 + createCalls, name: name, color: 0);
    _babies.add(baby);
    _codes[baby.id] = 'CODE${baby.id}';
    return baby;
  }

  @override
  Future<void> deleteBaby(int babyId) async {}

  @override
  String? connectCodeFor(int babyId) => _codes[babyId];

  @override
  Future<String> regenerateConnectCode(int babyId) async => 'XXXXXX';

  @override
  Future<Baby?> joinWithCode(String code) async => null;

  @override
  Future<Caregiver> addCaregiver(
          String name, CaregiverType type, int color) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCaregiver(int caregiverId) async {}

  @override
  Future<CareTask> addTask(CareTask task) => throw UnimplementedError();

  @override
  Future<void> updateTask(CareTask task) async {}

  @override
  Future<void> deleteTask(int taskId) async {}

  @override
  Future<LogEntry> addEntry(LogEntry entry) => throw UnimplementedError();

  @override
  Future<void> updateEntry(LogEntry entry) async {}

  @override
  Future<void> deleteEntry(int entryId) async {}
}

void main() {
  group('AppController.joinedBabies dedupe', () {
    test('same baby id listed twice renders once', () async {
      const nyra = Baby(id: 7, name: 'Nyra', color: 0xFFFFD54F);
      final repo = FakeRepository(
        // The createBaby mirror/listener race shape: one document,
        // two cache entries with the same id.
        [nyra, nyra],
        {7: 'AW6FN7'},
      );
      final controller = AppController(repo, MemoryKeyValueStore());
      await controller.init();
      expect(controller.joinedBabies, hasLength(1));
      expect(controller.joinedBabies.single.id, 7);
    });

    test('two records sharing a connect code render once (first kept)',
        () async {
      final repo = FakeRepository(
        [
          const Baby(id: 7, name: 'Nyra', color: 0xFFFFD54F),
          const Baby(id: 9, name: 'Nyra', color: 0xFFFFD54F),
          const Baby(id: 11, name: 'Other', color: 0xFF90CAF9),
        ],
        {7: 'AW6FN7', 9: 'AW6FN7', 11: 'K7QX2M'},
      );
      final controller = AppController(repo, MemoryKeyValueStore());
      await controller.init();
      expect(controller.joinedBabies.map((b) => b.id), [7, 11]);
    });
  });

  group('AppController.createBaby coalescing', () {
    test('concurrent calls create exactly one baby', () async {
      final repo = FakeRepository([], {});
      final controller = AppController(repo, MemoryKeyValueStore());
      await controller.init();
      final results = await Future.wait([
        controller.createBaby('Nyra'),
        controller.createBaby('Nyra'),
      ]);
      expect(repo.createCalls, 1);
      expect(results[0].id, results[1].id);
      expect(controller.joinedBabies, hasLength(1));
    });

    test('sequential calls still create separate babies', () async {
      final repo = FakeRepository([], {});
      final controller = AppController(repo, MemoryKeyValueStore());
      await controller.init();
      await controller.createBaby('Nyra');
      await controller.createBaby('Second');
      expect(repo.createCalls, 2);
      expect(controller.joinedBabies, hasLength(2));
    });
  });
}
