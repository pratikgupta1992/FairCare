// CRUD coverage for the repository methods the parity pass added
// to the interface (task edit/delete, caregiver delete) on the
// local backend.
import 'package:faircare/models.dart';
import 'package:faircare/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task add / update / delete round-trips', () async {
    final repo = LocalFairCareRepository.memory();
    await repo.init();
    final seededCount = repo.tasks.length;

    final added = await repo.addTask(const CareTask(
      name: 'Tummy time',
      emoji: '🐢',
      weight: 1.1,
      eligibility: Eligibility.anyone,
      countsTowardBalance: false,
      isCustom: true,
      sort: 99,
    ));
    expect(added.id, isNonZero);
    expect(repo.tasks, hasLength(seededCount + 1));
    expect(repo.taskById[added.id]?.name, 'Tummy time');

    await repo.updateTask(added.copyWith(weight: 2.0, name: 'Tummy time+'));
    expect(repo.taskById[added.id]?.weight, 2.0);
    expect(repo.taskById[added.id]?.name, 'Tummy time+');

    await repo.deleteTask(added.id);
    expect(repo.tasks, hasLength(seededCount));
    expect(repo.taskById[added.id], isNull);
  });

  test('caregiver delete removes only that caregiver', () async {
    final repo = LocalFairCareRepository.memory();
    await repo.init();
    final before = repo.caregivers.length;
    final extra =
        await repo.addCaregiver('Nana', CaregiverType.family, 0xFF81C784);
    expect(repo.caregivers, hasLength(before + 1));
    await repo.deleteCaregiver(extra.id);
    expect(repo.caregivers, hasLength(before));
    expect(repo.caregiverById[extra.id], isNull);
  });

  test('createBaby honors an explicit color', () async {
    final repo = LocalFairCareRepository.memory();
    await repo.init();
    final baby = await repo.createBaby('Pia', color: 0xFF4DB6AC);
    expect(baby.color, 0xFF4DB6AC);
    final defaulted = await repo.createBaby('Rio');
    expect(defaulted.color, 0xFFFFD54F);
  });
}
