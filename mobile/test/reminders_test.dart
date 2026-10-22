// Tests for the reminder quiet-hours logic (lib/reminders.dart),
// ported from the Kotlin ReminderPrefs.
import 'package:faircare/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('default quiet hours 10 PM - 7 AM (wraps midnight)', () {
    const s = ReminderSettings();
    test('quiet late evening and early morning', () {
      expect(s.isQuietAt(22 * 60), isTrue);
      expect(s.isQuietAt(23 * 60 + 30), isTrue);
      expect(s.isQuietAt(0), isTrue);
      expect(s.isQuietAt(6 * 60 + 59), isTrue);
    });
    test('not quiet during the day', () {
      expect(s.isQuietAt(7 * 60), isFalse);
      expect(s.isQuietAt(12 * 60), isFalse);
      expect(s.isQuietAt(21 * 60 + 59), isFalse);
    });
    test('allowed hours are 7..21', () {
      expect(s.allowedHours, [for (var h = 7; h <= 21; h++) h]);
    });
  });

  group('non-wrapping quiet window', () {
    const s = ReminderSettings(quietStartMin: 13 * 60, quietEndMin: 14 * 60);
    test('quiet only inside the window', () {
      expect(s.isQuietAt(13 * 60), isTrue);
      expect(s.isQuietAt(13 * 60 + 59), isTrue);
      expect(s.isQuietAt(12 * 60 + 59), isFalse);
      expect(s.isQuietAt(14 * 60), isFalse);
    });
    test('allowed hours skip 13 only', () {
      expect(s.allowedHours, hasLength(23));
      expect(s.allowedHours, isNot(contains(13)));
    });
  });

  group('fmtMinutesOfDay', () {
    test('formats like the original', () {
      expect(fmtMinutesOfDay(0), '12:00 AM');
      expect(fmtMinutesOfDay(12 * 60), '12:00 PM');
      expect(fmtMinutesOfDay(13 * 60 + 5), '1:05 PM');
      expect(fmtMinutesOfDay(22 * 60), '10:00 PM');
      expect(fmtMinutesOfDay(7 * 60), '7:00 AM');
    });
  });
}
