/// CSV export of the care log — port of the Kotlin
/// `util/CsvExport.kt` (`buildCsv`). The share-sheet half lives
/// in the Analytics screen (share_plus); this half is pure and
/// unit-tested.
library;

import 'fairness.dart' show splitDayNight;
import 'models.dart';

/// `caregiver_type` values as the Kotlin app writes them (its
/// enum constant names).
String _kotlinTypeName(CaregiverType t) => switch (t) {
      CaregiverType.mother => 'MOTHER',
      CaregiverType.father => 'FATHER',
      CaregiverType.otherParent => 'OTHER_PARENT',
      CaregiverType.nanny => 'NANNY',
      CaregiverType.daycare => 'DAYCARE',
      CaregiverType.family => 'FAMILY',
    };

String _pad2(int v) => v.toString().padLeft(2, '0');

/// "yyyy-MM-dd HH:mm" in local time.
String _fmtDateTime(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)} '
      '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
}

/// "yyyy-MM-dd" in local time.
String _fmtDate(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)}';
}

/// Builds the CSV exactly as the Android app does: same header,
/// rows sorted by start, quoted/escaped text fields, day/night
/// minute split per row. (Kotlin writes the weight via
/// `Float.toString()` — "1.5", "1.0" — which matches Dart's
/// `double.toString()` for these values.)
String buildCsv(
  List<LogEntry> entries,
  Map<int, Baby> babies,
  Map<int, Caregiver> caregivers,
  Map<int, CareTask> tasks,
) {
  String esc(String s) => '"${s.replaceAll('"', '""')}"';
  final sorted = List<LogEntry>.of(entries)
    ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
  final sb = StringBuffer()
    ..writeln(
        'start,end,date,duration_min,day_min,night_min,baby,caregiver,caregiver_type,task,task_weight,note');
  for (final e in sorted) {
    final (day, night) = splitDayNight(e.startMillis, e.endMillis);
    final cg = caregivers[e.caregiverId];
    final task = tasks[e.taskId];
    sb.writeln([
      _fmtDateTime(e.startMillis),
      _fmtDateTime(e.endMillis),
      _fmtDate(e.startMillis),
      '${e.durationMin}',
      '$day',
      '$night',
      esc(babies[e.babyId]?.name ?? '?'),
      esc(cg?.name ?? '?'),
      cg == null ? '?' : _kotlinTypeName(cg.type),
      esc(task?.name ?? '?'),
      '${task?.weight ?? 1.0}',
      esc(e.note),
    ].join(','));
  }
  return sb.toString();
}
