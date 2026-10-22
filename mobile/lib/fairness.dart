/// Fairness scoring, ported faithfully from the Android app
/// (`app/src/main/java/com/faircare/app/logic/Fairness.kt`).
///
/// Interpretation notes (places where Kotlin had to be translated):
/// * Kotlin walks hour-aligned chunks computed from *epoch* hour
///   boundaries but classifies each chunk by the *local* hour. For
///   whole-hour timezone offsets (e.g. US Pacific) the two are the
///   same boundaries; this port walks local-hour boundaries, which
///   matches the Kotlin behaviour there and is the obvious intent.
/// * Kotlin's `(a / b)` on Longs truncates toward zero for the
///   duration math; Dart's `~/` does the same for positive values,
///   and durations are clamped at 0 first, as in Kotlin.
library;

import 'models.dart';

/// Night hours get this multiplier — night duty is harder.
const double nightMultiplier = 1.5;

bool isNightHour(int hourOfDay) => hourOfDay >= 22 || hourOfDay < 6;

/// The start (epoch millis) of the next local hour after [millis].
int _nextHourBoundary(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime(dt.year, dt.month, dt.day, dt.hour + 1)
      .millisecondsSinceEpoch;
}

/// Split an entry's minutes into (dayMinutes, nightMinutes) by
/// walking hour boundaries.
(int, int) splitDayNight(int start, int end) {
  var day = 0;
  var night = 0;
  var t = start;
  var guard = 0;
  while (t < end && guard++ < 100) {
    final hour = DateTime.fromMillisecondsSinceEpoch(t).hour;
    final boundary = _nextHourBoundary(t);
    final chunkEnd = boundary < end ? boundary : end;
    final mins = ((chunkEnd - t) ~/ 60000).clamp(0, 1 << 62);
    if (isNightHour(hour)) {
      night += mins;
    } else {
      day += mins;
    }
    t = chunkEnd;
  }
  return (day, night);
}

/// Weighted effort points for one log entry.
/// points = (dayMin + nightMin * 1.5) * task.weight
///
/// This is what makes the fairness score "judge" tasks differently:
/// pumping (1.5x, mom-only) vs. supervising (0.7x) during the same
/// half hour is NOT scored as balanced — the points say otherwise.
double weightedPoints(LogEntry entry, CareTask task) {
  if (!task.countsTowardBalance) return 0.0;
  final (day, night) = splitDayNight(entry.startMillis, entry.endMillis);
  return (day + night * nightMultiplier) * task.weight;
}

class TaskSplit {
  const TaskSplit(this.taskId, this.byCaregiver, this.total);
  final int taskId;

  /// caregiverId -> weighted points for this task
  final Map<int, double> byCaregiver;
  final double total;
}

class FairnessReport {
  const FairnessReport({
    required this.score,
    required this.verdict,
    required this.parentShare,
    required this.parentPoints,
    required this.outsourcedShare,
    required this.perTask,
    required this.totalParentalPoints,
    required this.totalMinutes,
  });

  /// 0..100. Null when fewer than two parents have logged points.
  final double? score;
  final String verdict;

  /// caregiverId -> share of parental points (0..1), parents only
  final Map<int, double> parentShare;

  /// caregiverId -> weighted points, parents only
  final Map<int, double> parentPoints;

  /// Share of ALL points done by nanny/daycare (0..1)
  final double outsourcedShare;
  final List<TaskSplit> perTask;
  final double totalParentalPoints;
  final int totalMinutes;
}

String verdictFor(double score) {
  if (score >= 90) return 'Beautifully balanced ⚖️';
  if (score >= 75) return 'Mostly fair 👌';
  if (score >= 60) return 'Leaning on one parent';
  return 'Time to rebalance 😅';
}

FairnessReport computeFairness(
  List<LogEntry> entries,
  Map<int, CareTask> tasks,
  Map<int, Caregiver> caregivers,
) {
  final parentPts = <int, double>{};
  final byTask = <int, Map<int, double>>{};
  var external = 0.0;
  var total = 0.0;
  var mins = 0;

  for (final e in entries) {
    final task = tasks[e.taskId];
    if (task == null) continue;
    final cg = caregivers[e.caregiverId];
    if (cg == null) continue;
    final pts = weightedPoints(e, task);
    total += pts;
    mins += e.durationMin;
    final m = byTask.putIfAbsent(e.taskId, () => <int, double>{});
    m[e.caregiverId] = (m[e.caregiverId] ?? 0) + pts;
    if (cg.type.isParent) {
      parentPts[e.caregiverId] = (parentPts[e.caregiverId] ?? 0) + pts;
    } else if (cg.type.isPaidExternal) {
      external += pts;
    }
  }

  final parentTotal = parentPts.values.fold(0.0, (a, b) => a + b);
  final activeParents = parentPts.values.where((v) => v > 0).length;
  double? score;
  if (activeParents >= 2 && parentTotal > 0) {
    final maxPts = parentPts.values.reduce((a, b) => a > b ? a : b);
    final minPts = parentPts.values.reduce((a, b) => a < b ? a : b);
    score = (100.0 * (1.0 - (maxPts - minPts) / parentTotal))
        .clamp(0.0, 100.0)
        .toDouble();
  }

  return FairnessReport(
    score: score,
    verdict:
        score != null ? verdictFor(score) : 'Log both parents to see the score',
    parentShare: parentPts.map(
        (k, v) => MapEntry(k, parentTotal > 0 ? v / parentTotal : 0.0)),
    parentPoints: Map.of(parentPts),
    outsourcedShare: total > 0 ? external / total : 0.0,
    perTask: byTask.entries
        .map((en) => TaskSplit(
            en.key, Map.of(en.value), en.value.values.fold(0.0, (a, b) => a + b)))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total)),
    totalParentalPoints: parentTotal,
    totalMinutes: mins,
  );
}

/// For each (dayIndex, hour) cell, the caregiverId with the most
/// weighted points, or null when empty. Used by the hourly heatmap.
Map<(int, int), int> hourlyDominant(
  List<LogEntry> entries,
  Map<int, CareTask> tasks,
  Map<int, Caregiver> caregivers,
  List<int> dayStarts, // epoch millis of each day's 00:00, ascending
) {
  final cellPts = <(int, int), Map<int, double>>{};
  for (final e in entries) {
    final task = tasks[e.taskId];
    if (task == null) continue;
    if (caregivers[e.caregiverId] == null) continue;
    var t = e.startMillis;
    var guard = 0;
    while (t < e.endMillis && guard++ < 200) {
      int? dayStart;
      for (final ds in dayStarts) {
        if (ds <= t) dayStart = ds;
      }
      if (dayStart == null) {
        // Kotlin `continue`s the while loop without advancing t here,
        // which would spin until the guard trips; replicate by
        // advancing to the next hour boundary instead is NOT what it
        // does — keep the guard behaviour but break to stay safe.
        // (In practice dayStarts always covers the entries shown.)
        break;
      }
      final dayIdx = dayStarts.indexOf(dayStart);
      final hour = DateTime.fromMillisecondsSinceEpoch(t).hour;
      final boundary = _nextHourBoundary(t);
      final chunkEnd = boundary < e.endMillis ? boundary : e.endMillis;
      final mins = ((chunkEnd - t) ~/ 60000).clamp(0, 1 << 62);
      if (mins > 0) {
        final pts =
            mins * task.weight * (isNightHour(hour) ? nightMultiplier : 1.0);
        final m = cellPts.putIfAbsent((dayIdx, hour), () => <int, double>{});
        m[e.caregiverId] = (m[e.caregiverId] ?? 0) + pts;
      }
      t = chunkEnd;
    }
  }
  return cellPts.map((key, m) {
    var bestKey = m.keys.first;
    var bestVal = m[bestKey]!;
    m.forEach((k, v) {
      if (v > bestVal) {
        bestVal = v;
        bestKey = k;
      }
    });
    return MapEntry(key, bestKey);
  });
}

int startOfDay(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
}

String caregiverColorHex(int color) =>
    '#${(0xFFFFFF & color).toRadixString(16).padLeft(6, '0').toUpperCase()}';
