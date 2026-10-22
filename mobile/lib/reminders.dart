/// Hourly logging-reminder preferences and quiet-hours logic —
/// port of the Kotlin `data/ReminderPrefs.kt`. Pure Dart; the
/// platform scheduling lives in `reminder_service.dart`.
library;

/// Reminder settings: on/off plus the quiet-hours window in
/// minutes since midnight (defaults 10:00 PM – 7:00 AM, as in
/// the original).
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.quietStartMin = 22 * 60,
    this.quietEndMin = 7 * 60,
  });

  final bool enabled;
  final int quietStartMin;
  final int quietEndMin;

  ReminderSettings copyWith({
    bool? enabled,
    int? quietStartMin,
    int? quietEndMin,
  }) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        quietStartMin: quietStartMin ?? this.quietStartMin,
        quietEndMin: quietEndMin ?? this.quietEndMin,
      );

  /// Is [minutesOfDay] inside the quiet window? Port of the
  /// Kotlin `isQuietNow`: a window that wraps past midnight
  /// (start > end) covers late evening OR early morning.
  bool isQuietAt(int minutesOfDay) {
    final s = quietStartMin;
    final e = quietEndMin;
    if (s <= e) return minutesOfDay >= s && minutesOfDay < e;
    return minutesOfDay >= s || minutesOfDay < e;
  }

  /// Hours of the day (0–23) at whose start a reminder may fire:
  /// every hour whose HH:00 moment is outside quiet hours. Used
  /// to (re)build the daily notification schedule.
  List<int> get allowedHours =>
      [for (var h = 0; h < 24; h++) if (!isQuietAt(h * 60)) h];
}

/// 22*60 -> "10:00 PM" (port of `ReminderPrefs.fmt`).
String fmtMinutesOfDay(int min) {
  final h24 = (min ~/ 60) % 24;
  final m = min % 60;
  final ampm = h24 < 12 ? 'AM' : 'PM';
  final h = h24 % 12;
  final h12 = h == 0 ? 12 : h;
  return '$h12:${m.toString().padLeft(2, '0')} $ampm';
}
