import 'package:faircare/models.dart';
import 'package:faircare/timeline_layout.dart';
import 'package:faircare/ui_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry entry(int id, int startMin, int endMin) => LogEntry(
      id: id,
      babyId: 1,
      caregiverId: 1,
      taskId: 1,
      startMillis: startMin * 60000,
      endMillis: endMin * 60000,
    );

void main() {
  group('assignLanes', () {
    test('non-overlapping entries share one lane', () {
      final lanes = assignLanes([
        entry(1, 0, 60),
        entry(2, 60, 120),
        entry(3, 120, 180),
      ]);
      for (final id in [1, 2, 3]) {
        expect(lanes[id]!.lane, 0);
        expect(lanes[id]!.laneCount, 1);
      }
    });

    test('two overlapping entries sit side by side', () {
      final lanes = assignLanes([
        entry(1, 0, 120),
        entry(2, 60, 180),
      ]);
      expect(lanes[1]!.lane, 0);
      expect(lanes[2]!.lane, 1);
      expect(lanes[1]!.laneCount, 2);
      expect(lanes[2]!.laneCount, 2);
    });

    test('three-way overlap gets three columns', () {
      final lanes = assignLanes([
        entry(1, 0, 180),
        entry(2, 30, 150),
        entry(3, 60, 120),
      ]);
      expect(lanes[1]!.lane, 0);
      expect(lanes[2]!.lane, 1);
      expect(lanes[3]!.lane, 2);
      for (final id in [1, 2, 3]) {
        expect(lanes[id]!.laneCount, 3);
      }
    });

    test('chain overlap shares the cluster lane count', () {
      // A overlaps B, B overlaps C, A and C do not overlap: lanes
      // are reused (A and C both lane 0) but the transitive cluster
      // still reports 2 columns for all three.
      final lanes = assignLanes([
        entry(1, 0, 90),
        entry(2, 60, 150),
        entry(3, 120, 210),
      ]);
      expect(lanes[1]!.lane, 0);
      expect(lanes[2]!.lane, 1);
      expect(lanes[3]!.lane, 0);
      for (final id in [1, 2, 3]) {
        expect(lanes[id]!.laneCount, 2);
      }
    });

    test('separate clusters keep independent lane counts', () {
      final lanes = assignLanes([
        entry(1, 0, 120),
        entry(2, 60, 180),
        entry(3, 300, 360),
      ]);
      expect(lanes[1]!.laneCount, 2);
      expect(lanes[2]!.laneCount, 2);
      expect(lanes[3]!.lane, 0);
      expect(lanes[3]!.laneCount, 1);
    });
  });

  group('snapMinutes', () {
    test('rounds to the nearest 15-minute grid point', () {
      expect(snapMinutes(0), 0);
      expect(snapMinutes(7), 0);
      expect(snapMinutes(8), 15);
      expect(snapMinutes(22), 15);
      expect(snapMinutes(23), 30);
      expect(snapMinutes(45), 45);
      expect(snapMinutes(60), 60);
    });
  });

  group('movedStartMin', () {
    test('drag down 32px moves the start 30 minutes later', () {
      expect(
        movedStartMin(startMin: 420, durationMin: 60, dyPx: 32),
        450,
      );
    });

    test('small drags snap back to the current slot', () {
      expect(
        movedStartMin(startMin: 420, durationMin: 60, dyPx: 5),
        420,
      );
    });

    test('clamps at the start of the day', () {
      expect(
        movedStartMin(startMin: 420, durationMin: 60, dyPx: -64 * 8),
        0,
      );
    });

    test('clamps so the entry ends by midnight', () {
      expect(
        movedStartMin(startMin: 1380, durationMin: 60, dyPx: 500),
        1380, // 1440 - 60
      );
    });
  });

  group('resizedDurationMin', () {
    test('dragging the edge down 32px adds 30 minutes', () {
      expect(
        resizedDurationMin(startMin: 420, durationMin: 60, dhPx: 32),
        90,
      );
    });

    test('snaps the new duration to the grid', () {
      expect(
        resizedDurationMin(startMin: 420, durationMin: 60, dhPx: 16),
        75,
      );
    });

    test('never shrinks below one snap step', () {
      expect(
        resizedDurationMin(startMin: 420, durationMin: 60, dhPx: -1000),
        15,
      );
    });

    test('clamps the end at midnight', () {
      expect(
        resizedDurationMin(startMin: 1400, durationMin: 30, dhPx: 1000),
        40, // 1440 - 1400
      );
    });
  });

  group('fmtDuration (ui_helpers)', () {
    test('formats durations the way the Android app does', () {
      expect(fmtDuration(0), '0m');
      expect(fmtDuration(45), '45m');
      expect(fmtDuration(60), '1h');
      expect(fmtDuration(90), '1h 30m'); // never a duplicate "1h"
      expect(fmtDuration(150), '2h 30m');
    });
  });

  group('fmtRange (ui_helpers)', () {
    test('shares AM/PM when both ends are in the same meridiem', () {
      final start = DateTime(2026, 10, 21, 19, 0);
      final end = DateTime(2026, 10, 21, 19, 15);
      expect(fmtRange(start, end), '7:00–7:15 PM');
    });

    test('repeats AM/PM across a meridiem boundary', () {
      final start = DateTime(2026, 10, 21, 11, 30);
      final end = DateTime(2026, 10, 21, 12, 15);
      expect(fmtRange(start, end), '11:30 AM–12:15 PM');
    });

    test('handles the midnight hour', () {
      final start = DateTime(2026, 10, 21, 0, 0);
      final end = DateTime(2026, 10, 21, 0, 30);
      expect(fmtRange(start, end), '12:00–12:30 AM');
    });
  });
}
