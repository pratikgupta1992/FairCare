// General Care quick-log task: canonical values, dropdown
// ordering (pinned first regardless of stored sort), and the
// local repository's idempotent ensure step.
import 'package:faircare/models.dart';
import 'package:faircare/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical General Care task', () {
    test('carries the agreed values', () {
      final gc = generalCareTask();
      expect(gc.name, 'General Care');
      expect(gc.emoji, '⭐'); // from the original's example line
      expect(gc.weight, 1.0);
      expect(gc.eligibility, Eligibility.anyone);
      expect(gc.countsTowardBalance, isTrue);
      expect(gc.id, kGeneralCareTaskId);
      expect(gc.sort, lessThan(0)); // before every default task
    });

    test('name matching is case-insensitive and trims', () {
      expect(isGeneralCareTask(generalCareTask()), isTrue);
      expect(
        isGeneralCareTask(
            const CareTask(name: 'general care', emoji: 'x')),
        isTrue,
      );
      expect(
        isGeneralCareTask(
            const CareTask(name: '  General Care ', emoji: 'x')),
        isTrue,
      );
      expect(
        isGeneralCareTask(
            const CareTask(name: 'Bottle feed', emoji: '🍼')),
        isFalse,
      );
    });

    test('needsGeneralCare reflects presence', () {
      expect(needsGeneralCare(defaultTasks()), isTrue);
      expect(needsGeneralCare([generalCareTask()]), isFalse);
      expect(needsGeneralCare(const []), isTrue);
    });
  });

  group('dropdown ordering', () {
    test('General Care pins first even when its stored sort is largest',
        () {
      // An existing baby could hold a General Care with any sort
      // (e.g. hand-created as a custom task at the end).
      final gc = generalCareTask().copyWith(sort: 99, isCustom: true);
      final tasks = [...defaultTasks(), gc];
      final ordered = orderTasksForDropdown(tasks);
      expect(ordered.first.name, 'General Care');
      expect(ordered.length, tasks.length);
      // The rest keep their incoming (stored-sort) order.
      expect(ordered.skip(1).map((t) => t.name),
          defaultTasks().map((t) => t.name));
    });

    test('ordering is unchanged when there is no General Care', () {
      final tasks = defaultTasks();
      expect(orderTasksForDropdown(tasks).map((t) => t.name),
          tasks.map((t) => t.name));
    });

    test('a lowercase hand-created General Care also pins first', () {
      const handMade = CareTask(name: 'general care', emoji: '⭐', sort: 42);
      final ordered =
          orderTasksForDropdown([...defaultTasks(), handMade]);
      expect(ordered.first.name, 'general care');
    });
  });

  group('LocalFairCareRepository ensure', () {
    test('init adds General Care once, sorted first', () async {
      final repo = LocalFairCareRepository.memory();
      await repo.init();
      final matches = repo.tasks.where(isGeneralCareTask).toList();
      expect(matches, hasLength(1));
      expect(repo.tasks.first.name, 'General Care');
      expect(repo.tasks, hasLength(13)); // 12 defaults + General Care
      expect(matches.single.emoji, '⭐');
      expect(matches.single.weight, 1.0);
    });

    test('a second launch over the same store creates nothing new',
        () async {
      final store = MemoryKeyValueStore();
      final first = LocalFairCareRepository(store);
      await first.init();
      final countAfterFirst = first.tasks.length;
      final gcId = first.tasks.firstWhere(isGeneralCareTask).id;

      final second = LocalFairCareRepository(store);
      await second.init();
      expect(second.tasks, hasLength(countAfterFirst));
      expect(second.tasks.where(isGeneralCareTask), hasLength(1));
      expect(second.tasks.firstWhere(isGeneralCareTask).id, gcId);
    });

    test('concurrent inits over the same store still yield one', () async {
      final store = MemoryKeyValueStore();
      final a = LocalFairCareRepository(store);
      final b = LocalFairCareRepository(store);
      await Future.wait([a.init(), b.init()]);
      // Whichever state won the save race, a fresh reader sees
      // exactly one General Care.
      final reader = LocalFairCareRepository(store);
      await reader.init();
      expect(reader.tasks.where(isGeneralCareTask), hasLength(1));
    });

    test('deleting General Care re-ensures it on the next launch',
        () async {
      final store = MemoryKeyValueStore();
      final first = LocalFairCareRepository(store);
      await first.init();
      final gc = first.tasks.firstWhere(isGeneralCareTask);
      await first.deleteTask(gc.id);
      expect(first.tasks.where(isGeneralCareTask), isEmpty);

      final second = LocalFairCareRepository(store);
      await second.init();
      expect(second.tasks.where(isGeneralCareTask), hasLength(1));
    });
  });
}
