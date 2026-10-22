import 'package:faircare/fairness.dart';
import 'package:faircare/models.dart';
import 'package:flutter_test/flutter_test.dart';

int ms(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;

LogEntry entry({
  required int caregiverId,
  required int taskId,
  required int start,
  required int end,
  int babyId = 1,
}) =>
    LogEntry(
        babyId: babyId,
        caregiverId: caregiverId,
        taskId: taskId,
        startMillis: start,
        endMillis: end);

const mom = Caregiver(
    id: 1, name: 'Mom', type: CaregiverType.mother, color: 0xFFE57373);
const dad = Caregiver(
    id: 2, name: 'Dad', type: CaregiverType.father, color: 0xFF64B5F6);
const daycare = Caregiver(
    id: 3, name: 'Daycare', type: CaregiverType.daycare, color: 0xFF81C784);

const bottle = CareTask(id: 1, name: 'Bottle feed', emoji: '🍼', weight: 1.0);
const pumping = CareTask(
    id: 2,
    name: 'Pumping',
    emoji: '💦',
    weight: 1.5,
    eligibility: Eligibility.motherOnly);
const supervising =
    CareTask(id: 3, name: 'On-duty supervising', emoji: '👀', weight: 0.7);
const noCount = CareTask(
    id: 4, name: 'Background presence', emoji: '·', countsTowardBalance: false);

final tasks = {for (final t in [bottle, pumping, supervising, noCount]) t.id: t};
final caregivers = {for (final c in [mom, dad, daycare]) c.id: c};

void main() {
  group('splitDayNight / isNightHour', () {
    test('night is 10 PM - 6 AM', () {
      expect(isNightHour(22), isTrue);
      expect(isNightHour(23), isTrue);
      expect(isNightHour(0), isTrue);
      expect(isNightHour(5), isTrue);
      expect(isNightHour(6), isFalse);
      expect(isNightHour(21), isFalse);
      expect(isNightHour(12), isFalse);
    });

    test('pure daytime entry', () {
      final (day, night) = splitDayNight(ms(21, 14), ms(21, 15));
      expect(day, 60);
      expect(night, 0);
    });

    test('pure night entry', () {
      final (day, night) = splitDayNight(ms(21, 23), ms(22, 0));
      expect(day, 0);
      expect(night, 60);
    });

    test('entry crossing the 10 PM boundary splits', () {
      final (day, night) = splitDayNight(ms(21, 21), ms(21, 23));
      expect(day, 60);
      expect(night, 60);
    });

    test('entry crossing 6 AM splits', () {
      final (day, night) = splitDayNight(ms(21, 5), ms(21, 7));
      expect(day, 60);
      expect(night, 60);
    });
  });

  group('weightedPoints', () {
    test('daytime, weight 1.0: points = minutes', () {
      final e = entry(caregiverId: 1, taskId: 1, start: ms(21, 14), end: ms(21, 15));
      expect(weightedPoints(e, bottle), 60.0);
    });

    test('night hours get the 1.5x multiplier', () {
      final e = entry(caregiverId: 1, taskId: 1, start: ms(21, 23), end: ms(22, 0));
      expect(weightedPoints(e, bottle), 90.0);
    });

    test('mixed day/night: (60 + 60*1.5) * weight', () {
      final e = entry(caregiverId: 1, taskId: 1, start: ms(21, 21), end: ms(21, 23));
      expect(weightedPoints(e, bottle), 150.0);
    });

    test('pumping/breastfeeding weight 1.5x applies on top', () {
      final e = entry(caregiverId: 1, taskId: 2, start: ms(21, 14), end: ms(21, 15));
      expect(weightedPoints(e, pumping), 90.0);
    });

    test('pumping at night stacks both multipliers', () {
      final e = entry(caregiverId: 1, taskId: 2, start: ms(21, 23), end: ms(22, 0));
      // (60 * 1.5 night) * 1.5 task weight
      expect(weightedPoints(e, pumping), 135.0);
    });

    test('countsTowardBalance = false earns zero', () {
      final e = entry(caregiverId: 1, taskId: 4, start: ms(21, 14), end: ms(21, 15));
      expect(weightedPoints(e, noCount), 0.0);
    });

    test('same half hour, pumping (mom) vs supervising (dad) is not balanced', () {
      final momEntry =
          entry(caregiverId: 1, taskId: 2, start: ms(21, 14), end: ms(21, 14, 30));
      final dadEntry =
          entry(caregiverId: 2, taskId: 3, start: ms(21, 14), end: ms(21, 14, 30));
      final report = computeFairness([momEntry, dadEntry], tasks, caregivers);
      // Mom: 30 * 1.5 = 45, Dad: 30 * 0.7 = 21
      expect(report.parentPoints[1], 45.0);
      expect(report.parentPoints[2], 21.0);
      expect(report.score, isNot(100.0));
    });
  });

  group('computeFairness', () {
    test('equal parents -> score 100 and 50/50 shares', () {
      final entries = [
        entry(caregiverId: 1, taskId: 1, start: ms(21, 10), end: ms(21, 11)),
        entry(caregiverId: 2, taskId: 1, start: ms(21, 12), end: ms(21, 13)),
      ];
      final r = computeFairness(entries, tasks, caregivers);
      expect(r.score, 100.0);
      expect(r.verdict, 'Beautifully balanced ⚖️');
      expect(r.parentShare[1], 0.5);
      expect(r.parentShare[2], 0.5);
      expect(r.outsourcedShare, 0.0);
      expect(r.totalMinutes, 120);
    });

    test('one parent only -> score is null', () {
      final entries = [
        entry(caregiverId: 1, taskId: 1, start: ms(21, 10), end: ms(21, 11)),
      ];
      final r = computeFairness(entries, tasks, caregivers);
      expect(r.score, isNull);
      expect(r.verdict, 'Log both parents to see the score');
    });

    test('lopsided split lowers the score by the Kotlin formula', () {
      final entries = [
        entry(caregiverId: 1, taskId: 1, start: ms(21, 8), end: ms(21, 11)), // 180
        entry(caregiverId: 2, taskId: 1, start: ms(21, 12), end: ms(21, 13)), // 60
      ];
      final r = computeFairness(entries, tasks, caregivers);
      // 100 * (1 - (180-60)/240) = 50
      expect(r.score, 50.0);
      expect(r.parentShare[1], 0.75);
      expect(r.parentShare[2], 0.25);
    });

    test('daycare points count as outsourced, not parental', () {
      final entries = [
        entry(caregiverId: 1, taskId: 1, start: ms(21, 10), end: ms(21, 11)), // 60 parent
        entry(caregiverId: 3, taskId: 1, start: ms(21, 12), end: ms(21, 13)), // 60 daycare
      ];
      final r = computeFairness(entries, tasks, caregivers);
      expect(r.outsourcedShare, 0.5);
      expect(r.parentPoints.containsKey(3), isFalse);
      expect(r.totalParentalPoints, 60.0);
    });

    test('entries with unknown task or caregiver are skipped', () {
      final entries = [
        entry(caregiverId: 99, taskId: 1, start: ms(21, 10), end: ms(21, 11)),
        entry(caregiverId: 1, taskId: 99, start: ms(21, 10), end: ms(21, 11)),
      ];
      final r = computeFairness(entries, tasks, caregivers);
      expect(r.totalMinutes, 0);
      expect(r.score, isNull);
    });

    test('verdict thresholds', () {
      expect(verdictFor(95), 'Beautifully balanced ⚖️');
      expect(verdictFor(80), 'Mostly fair 👌');
      expect(verdictFor(65), 'Leaning on one parent');
      expect(verdictFor(10), 'Time to rebalance 😅');
    });
  });

  group('hourlyDominant', () {
    test('picks the caregiver with most weighted points in the cell', () {
      final dayStart = startOfDay(ms(21, 0));
      final entries = [
        entry(caregiverId: 1, taskId: 1, start: ms(21, 10), end: ms(21, 10, 30)),
        entry(caregiverId: 2, taskId: 1, start: ms(21, 10, 30), end: ms(21, 11)),
        entry(caregiverId: 2, taskId: 1, start: ms(21, 14), end: ms(21, 15)),
      ];
      final result = hourlyDominant(entries, tasks, caregivers, [dayStart]);
      // 10:00 cell: mom 30 pts vs dad 30 pts -> tie keeps first-seen max (mom,
      // matching Kotlin maxBy which returns the first maximal element).
      expect(result[(0, 10)], 1);
      expect(result[(0, 14)], 2);
    });
  });

  test('durationMin clamps at zero', () {
    final e = entry(caregiverId: 1, taskId: 1, start: ms(21, 11), end: ms(21, 10));
    expect(e.durationMin, 0);
  });
}
