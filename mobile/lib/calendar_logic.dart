/// Pure date/score helpers for the Calendar tab, ported from the
/// helpers at the bottom of the Kotlin `CalendarScreen.kt`.
/// All values are epoch millis in local time.
library;

const int dayMillis = 24 * 3600000;

const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday',
];

/// Local midnight of the 1st of the month containing [millis].
int monthStart(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime(dt.year, dt.month).millisecondsSinceEpoch;
}

/// Local midnight of Jan 1 of the year containing [millis].
int yearStart(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime(dt.year).millisecondsSinceEpoch;
}

/// [millis] shifted by [n] calendar months (Kotlin
/// `Calendar.add(MONTH, n)`; the day-of-month clamps to the
/// target month's length via [DateTime] normalization).
int addMonths(int millis, int n) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime(dt.year, dt.month + n, dt.day, dt.hour, dt.minute,
          dt.second, dt.millisecond)
      .millisecondsSinceEpoch;
}

/// [millis] shifted by [n] calendar years.
int addYears(int millis, int n) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime(dt.year + n, dt.month, dt.day, dt.hour, dt.minute,
          dt.second, dt.millisecond)
      .millisecondsSinceEpoch;
}

/// "October 2026" style title for a month-start instant.
String monthTitle(int monthStartMillis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(monthStartMillis);
  return '${monthNames[dt.month - 1]} ${dt.year}';
}

/// Grid cells for a month view: day-start millis for each day of
/// the month, with `null` padding so weeks start on Sunday and
/// every row has 7 cells (port of the Kotlin `monthCells`).
List<int?> monthCells(int monthStartMillis) {
  final first = DateTime.fromMillisecondsSinceEpoch(monthStartMillis);
  // Dart weekday: Mon=1..Sun=7; Kotlin Calendar: Sun=1..Sat=7.
  // Lead padding = days since Sunday.
  final lead = first.weekday % 7;
  final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
  final cells = <int?>[
    for (var i = 0; i < lead; i++) null,
    for (var d = 0; d < daysInMonth; d++)
      monthStartMillis + d * dayMillis,
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

/// Background tint (ARGB) for a day/month with this fairness
/// score — port of the Kotlin `scoreTint`.
int scoreTint(double score) {
  if (score >= 80) return 0xFFC8E6C9;
  if (score >= 60) return 0xFFFFF9C4;
  if (score >= 40) return 0xFFFFE0B2;
  return 0xFFFFCDD2;
}

/// Brightness-aware variant of [scoreTint]: the pastels above
/// are light-mode colors — in dark mode the (near-white) day
/// numbers would sit unreadably on them. So for dark mode the
/// pastel is alpha-blended over the theme's surface color,
/// keeping the hue (green/yellow/orange/red by band) while
/// landing at a dark-mode luminance the surface's text colors
/// stay readable on. Light mode returns the pastel unchanged.
int scoreTintArgb(double score,
    {required int surfaceArgb, required bool dark}) {
  final tint = scoreTint(score);
  if (!dark) return tint;
  const blend = 0.30; // pastel share; the rest is the surface
  int channel(int shift) {
    final t = (tint >> shift) & 0xFF;
    final s = (surfaceArgb >> shift) & 0xFF;
    return (t * blend + s * (1 - blend)).round();
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

/// "Wednesday, Oct 21" style label for the selected-day card
/// (Kotlin `SimpleDateFormat("EEEE, MMM d")`).
String fullDayLabel(int dayStartMillis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(dayStartMillis);
  const mon = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdayNames[dt.weekday - 1]}, ${mon[dt.month - 1]} ${dt.day}';
}

/// "Oct 21, 2026" style date (Kotlin `SimpleDateFormat("MMM d, yyyy")`).
String fullDateLabel(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  const mon = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${mon[dt.month - 1]} ${dt.day}, ${dt.year}';
}
