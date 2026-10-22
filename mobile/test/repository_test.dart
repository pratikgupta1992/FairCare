import 'package:faircare/app_controller.dart';
import 'package:faircare/models.dart';
import 'package:faircare/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalFairCareRepository', () {
    late LocalFairCareRepository repo;

    setUp(() async {
      repo = LocalFairCareRepository.memory();
      await repo.init();
    });

    test('seeds Mom/Dad, default tasks, and one baby (like the Android app)',
        () {
      expect(repo.caregivers.map((c) => c.name), containsAll(['Mom', 'Dad']));
      expect(repo.tasks.length, 12);
      expect(repo.tasks.first.name, 'Breastfeeding');
      expect(repo.babies.length, 1);
    });

    test('creating a baby generates a 6-char connect code', () async {
      final baby = await repo.createBaby('Nyra');
      final code = repo.connectCodeFor(baby.id);
      expect(code, isNotNull);
      expect(code!.length, connectCodeLength);
      expect(
          code
              .split('')
              .every((ch) => connectCodeAlphabet.contains(ch)),
          isTrue);
    });

    test('baby can be found by its connect code, case-insensitively',
        () async {
      final baby = await repo.createBaby('Nyra');
      final code = repo.connectCodeFor(baby.id)!;
      expect(repo.babyForCode(code)?.id, baby.id);
      expect(repo.babyForCode(code.toLowerCase())?.id, baby.id);
      expect(repo.babyForCode('ZZZZZZ'), isNull);
    });

    test('regenerating a code invalidates the old one', () async {
      final baby = await repo.createBaby('Nyra');
      final old = repo.connectCodeFor(baby.id)!;
      final fresh = await repo.regenerateConnectCode(baby.id);
      expect(fresh, isNot(old));
      expect(repo.babyForCode(old), isNull);
      expect(repo.babyForCode(fresh)?.id, baby.id);
    });

    test('connect codes are unique across babies', () async {
      final codes = <String>{};
      for (var i = 0; i < 25; i++) {
        final b = await repo.createBaby('Baby $i');
        codes.add(repo.connectCodeFor(b.id)!);
      }
      expect(codes.length, 25);
    });

    test('entries CRUD round-trips', () async {
      final baby = repo.babies.first;
      final e = await repo.addEntry(LogEntry(
        babyId: baby.id,
        caregiverId: repo.caregivers.first.id,
        taskId: repo.tasks.first.id,
        startMillis: DateTime(2026, 10, 21, 10).millisecondsSinceEpoch,
        endMillis: DateTime(2026, 10, 21, 11).millisecondsSinceEpoch,
        note: 'first',
        createdBy: 'Me',
      ));
      expect(e.id, isNonZero);
      expect(repo.entriesForBaby(baby.id).single.note, 'first');

      await repo.updateEntry(e.copyWith(note: 'edited'));
      expect(repo.entriesForBaby(baby.id).single.note, 'edited');

      await repo.deleteEntry(e.id);
      expect(repo.entriesForBaby(baby.id), isEmpty);
    });
  });

  group('AppController: join + default role', () {
    late LocalFairCareRepository repo;
    late AppController controller;

    setUp(() async {
      repo = LocalFairCareRepository.memory();
      controller = AppController(repo, MemoryKeyValueStore());
      await controller.init();
    });

    test('seeded baby is joined by default', () {
      expect(controller.joinedBabies.length, 1);
      expect(controller.selectedBaby, isNotNull);
    });

    test('join by code adds the baby; wrong code does not', () async {
      // Simulate a second baby "owned" by someone else: create it
      // directly on the repo (not via the controller).
      final other = await repo.createBaby('Other Baby');
      final code = repo.connectCodeFor(other.id)!;
      expect(controller.isJoined(other.id), isFalse);

      final joined = await controller.joinBabyByCode(code);
      expect(joined?.id, other.id);
      expect(controller.isJoined(other.id), isTrue);
      expect(controller.selectedBaby?.id, other.id);

      final failed = await controller.joinBabyByCode('ZZZZZZ');
      expect(failed, isNull);
    });

    test('default caregiver is per baby and can be cleared', () async {
      final baby = controller.selectedBaby!;
      final dad =
          repo.caregivers.firstWhere((c) => c.type == CaregiverType.father);
      final mom =
          repo.caregivers.firstWhere((c) => c.type == CaregiverType.mother);

      expect(controller.defaultCaregiverFor(baby.id), isNull);

      await controller.setDefaultCaregiver(baby.id, dad.id);
      expect(controller.defaultCaregiverFor(baby.id)?.id, dad.id);

      // A second baby has its own independent default.
      final other = await controller.createBaby('Second');
      expect(controller.defaultCaregiverFor(other.id), isNull);
      await controller.setDefaultCaregiver(other.id, mom.id);
      expect(controller.defaultCaregiverFor(other.id)?.id, mom.id);
      expect(controller.defaultCaregiverFor(baby.id)?.id, dad.id);

      await controller.setDefaultCaregiver(baby.id, null);
      expect(controller.defaultCaregiverFor(baby.id), isNull);
    });
  });
}
