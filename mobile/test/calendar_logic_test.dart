// Tests for the Calendar tab's pure date/score helpers
// (lib/calendar_logic.dart), ported from CalendarScreen.kt.
import 'package:faircare/calendar_logic.dart';
import 'package:flutter_test/flutter_test.dart';

int ms(int y, int mo, int d, [int h = 0, int mi = 0]) =>
    DateTime(y, mo, d, h, mi).millisecondsSinceEpoch;

void main() {
  group('monthStart / yearStart', () {
    test('monthStart is local midnight on the 1st', () {
      expect(monthStart(ms(2026, 10, 21, 15, 30)), ms(2026, 10, 1));
    });
    test('yearStart is local midnight on Jan 1', () {
      expect(yearStart(ms(2026, 10, 21)), ms(2026, 1, 1));
    });
  });

  group('addMonths / addYears', () {
    test('addMonths crosses the year boundary both ways', () {
      expect(addMonths(ms(2026, 10, 1), 4), ms(2027, 2, 1));
      expect(addMonths(ms(2026, 1, 1), -1), ms(2025, 12, 1));
    });
    test('addYears shifts the year', () {
      expect(addYears(ms(2026, 1, 1), 1), ms(2027, 1, 1));
      expect(addYears(ms(2026, 1, 1), -1), ms(2025, 1, 1));
    });
  });

  group('monthTitle / labels', () {
    test('monthTitle', () {
      expect(monthTitle(ms(2026, 10, 1)), 'October 2026');
    });
    test('fullDayLabel', () {
      // Oct 21, 2026 is a Wednesday.
      expect(fullDayLabel(ms(2026, 10, 21)), 'Wednesday, Oct 21');
    });
    test('fullDateLabel', () {
      expect(fullDateLabel(ms(2026, 10, 21)), 'Oct 21, 2026');
    });
  });

  group('monthCells', () {
    test('October 2026: Thursday start -> 4 lead blanks, 31 days', () {
      final cells = monthCells(ms(2026, 10, 1));
      expect(cells.length, 35);
      expect(cells.take(4), everyElement(isNull));
      expect(cells[4], ms(2026, 10, 1));
      expect(cells.last, ms(2026, 10, 31));
    });
    test('February 2026: Sunday start -> no padding, 28 cells', () {
      final cells = monthCells(ms(2026, 2, 1));
      expect(cells.length, 28);
      expect(cells.first, ms(2026, 2, 1));
      expect(cells.last, ms(2026, 2, 28));
    });
    test('every row has 7 cells', () {
      for (var m = 1; m <= 12; m++) {
        expect(monthCells(ms(2026, m, 1)).length % 7, 0);
      }
    });
  });

  group('scoreTint bands', () {
    test('band boundaries', () {
      expect(scoreTint(100), 0xFFC8E6C9);
      expect(scoreTint(80), 0xFFC8E6C9);
      expect(scoreTint(79.9), 0xFFFFF9C4);
      expect(scoreTint(60), 0xFFFFF9C4);
      expect(scoreTint(59.9), 0xFFFFE0B2);
      expect(scoreTint(40), 0xFFFFE0B2);
      expect(scoreTint(39.9), 0xFFFFCDD2);
      expect(scoreTint(0), 0xFFFFCDD2);
    });
  });
}
