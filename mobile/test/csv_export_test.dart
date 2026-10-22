// Tests for the CSV export builder (lib/csv_export.dart), a
// port of the Kotlin CsvExport.buildCsv.
import 'package:faircare/csv_export.dart';
import 'package:faircare/models.dart';
import 'package:flutter_test/flutter_test.dart';

int ms(int mo, int d, int h, [int mi = 0]) =>
    DateTime(2026, mo, d, h, mi).millisecondsSinceEpoch;

void main() {
  final babies = {1: const Baby(id: 1, name: 'Nyra', color: 0)};
  final caregivers = {
    1: const Caregiver(id: 1, name: 'Mom', type: CaregiverType.mother, color: 0),
    2: const Caregiver(id: 2, name: 'Dad', type: CaregiverType.father, color: 0),
    3: const Caregiver(
        id: 3, name: 'Nana', type: CaregiverType.family, color: 0),
  };
  final tasks = {
    1: const CareTask(id: 1, name: 'Bottle feed', emoji: '🍼', weight: 1.0),
    2: const CareTask(id: 2, name: 'Night soothing', emoji: '😴', weight: 1.5),
  };

  test('header matches the original exactly', () {
    final csv = buildCsv(const [], babies, caregivers, tasks);
    expect(csv.trim(),
        'start,end,date,duration_min,day_min,night_min,baby,caregiver,caregiver_type,task,task_weight,note');
  });

  test('rows are sorted by start, with day/night split', () {
    final night = LogEntry(
      id: 2,
      babyId: 1,
      caregiverId: 1,
      taskId: 2,
      startMillis: ms(10, 21, 23),
      endMillis: ms(10, 22, 1),
    );
    final day = LogEntry(
      id: 1,
      babyId: 1,
      caregiverId: 2,
      taskId: 1,
      startMillis: ms(10, 21, 10),
      endMillis: ms(10, 21, 11, 30),
      note: 'hungry',
    );
    final lines =
        buildCsv([night, day], babies, caregivers, tasks).trim().split('\n');
    expect(lines, hasLength(3));
    // Day entry first (earlier start), 90 day minutes.
    expect(
        lines[1],
        '2026-10-21 10:00,2026-10-21 11:30,2026-10-21,90,90,0,'
        '"Nyra","Dad",FATHER,"Bottle feed",1.0,"hungry"');
    // Night entry: 23:00-01:00 is entirely night hours.
    expect(
        lines[2],
        '2026-10-21 23:00,2026-10-22 01:00,2026-10-21,120,0,120,'
        '"Nyra","Mom",MOTHER,"Night soothing",1.5,""');
  });

  test('text fields are quoted with doubled inner quotes', () {
    final oddBabies = {1: const Baby(id: 1, name: 'A "quoted" baby', color: 0)};
    final e = LogEntry(
      id: 1,
      babyId: 1,
      caregiverId: 3,
      taskId: 1,
      startMillis: ms(10, 21, 9),
      endMillis: ms(10, 21, 9, 30),
      note: 'said "hi"',
    );
    final csv = buildCsv([e], oddBabies, caregivers, tasks);
    expect(csv, contains('"A ""quoted"" baby"'));
    expect(csv, contains('FAMILY'));
    expect(csv, contains('"said ""hi"""'));
  });
}
