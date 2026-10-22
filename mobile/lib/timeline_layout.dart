/// Pure layout/time math for the day timeline, ported from the
/// Kotlin TodayScreen (`assignLanes` and the drag/resize commit
/// math in `EntryBlock`). Kept free of Flutter widgets so it can
/// be unit-tested directly.
library;

import 'models.dart';

/// Height of one hour row, in logical pixels (Kotlin `HOUR_HEIGHT`
/// = 64.dp).
const double kHourHeight = 64.0;

/// Drag/resize snapping interval in minutes (Kotlin `SNAP_MIN`).
const int kSnapMinutes = 15;

/// Minimum on-screen block height, in logical pixels (Kotlin
/// 30.dp). Short entries are drawn at least this tall so they
/// stay grabbable.
const double kMinBlockHeight = 30.0;

const int kMinutesPerDay = 24 * 60;

/// Where an entry sits in the side-by-side overlap layout:
/// [lane] is its column, [laneCount] the column count shared by
/// its whole overlap cluster.
class LaneInfo {
  const LaneInfo(this.lane, this.laneCount);

  final int lane;
  final int laneCount;
}

/// Assigns display lanes so overlapping entries sit side by side.
///
/// Direct port of the Kotlin `assignLanes`: greedy first-free-lane
/// assignment by start time, then transitive overlap clusters all
/// share the cluster's lane count — so a chain A–B–C (A and C not
/// themselves overlapping) renders at a uniform column count.
Map<int, LaneInfo> assignLanes(List<LogEntry> entries) {
  final sorted = List<LogEntry>.of(entries)
    ..sort((a, b) {
      final c = a.startMillis.compareTo(b.startMillis);
      if (c != 0) return c;
      final d = a.endMillis.compareTo(b.endMillis);
      return d != 0 ? d : a.id.compareTo(b.id);
    });

  final laneEnds = <int>[];
  final laneOf = <int, int>{};
  for (final e in sorted) {
    var lane = laneEnds.indexWhere((end) => end <= e.startMillis);
    if (lane == -1) {
      laneEnds.add(e.endMillis);
      lane = laneEnds.length - 1;
    } else {
      laneEnds[lane] = e.endMillis;
    }
    laneOf[e.id] = lane;
  }

  bool overlaps(LogEntry a, LogEntry b) =>
      a.startMillis < b.endMillis && b.startMillis < a.endMillis;

  final result = <int, LaneInfo>{};
  final visited = <int>{};
  for (final e in sorted) {
    if (visited.contains(e.id)) continue;
    final cluster = <LogEntry>[];
    final queue = <LogEntry>[e];
    visited.add(e.id);
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      cluster.add(cur);
      for (final o in sorted) {
        if (!visited.contains(o.id) && overlaps(cur, o)) {
          visited.add(o.id);
          queue.add(o);
        }
      }
    }
    var maxLane = 0;
    for (final c in cluster) {
      final l = laneOf[c.id] ?? 0;
      if (l > maxLane) maxLane = l;
    }
    for (final c in cluster) {
      result[c.id] = LaneInfo(laneOf[c.id] ?? 0, maxLane + 1);
    }
  }
  return result;
}

/// Snaps [minutes] to the nearest [kSnapMinutes] grid point
/// (Kotlin: `(x / SNAP_MIN).roundToInt() * SNAP_MIN`).
int snapMinutes(num minutes) =>
    (minutes / kSnapMinutes).round() * kSnapMinutes;

/// Start minute-of-day after dragging an entry [dyPx] pixels from
/// [startMin]: snapped to the grid and clamped so the whole entry
/// stays inside the day (port of the Kotlin move-commit math).
int movedStartMin({
  required int startMin,
  required int durationMin,
  required double dyPx,
  double hourPx = kHourHeight,
}) {
  final raw = snapMinutes(startMin + dyPx / hourPx * 60);
  var hi = kMinutesPerDay - durationMin;
  if (hi < 0) hi = 0;
  if (raw < 0) return 0;
  return raw > hi ? hi : raw;
}

/// Duration in minutes after resizing an entry by [dhPx] pixels:
/// snapped, never below one snap step, and the end stays inside
/// the day. (Kotlin's resize commit clamps only the minimum; the
/// day-end clamp is the one deliberate addition.)
int resizedDurationMin({
  required int startMin,
  required int durationMin,
  required double dhPx,
  double hourPx = kHourHeight,
}) {
  final raw = snapMinutes(durationMin + dhPx / hourPx * 60);
  var hi = kMinutesPerDay - startMin;
  if (hi < kSnapMinutes) hi = kSnapMinutes;
  if (raw < kSnapMinutes) return kSnapMinutes;
  return raw > hi ? hi : raw;
}
