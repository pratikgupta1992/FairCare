/// Data models ported from the Android app
/// (`app/src/main/java/com/faircare/app/data/Entities.kt`).
///
/// Kotlin `Long` ids become Dart `int`s; colors stay ARGB ints, exactly
/// as stored by the Android app.
library;

enum CaregiverType {
  mother('Mom'),
  father('Dad'),
  otherParent('Parent'),
  nanny('Nanny'),
  daycare('Daycare'),
  family('Family');

  const CaregiverType(this.label);
  final String label;

  bool get isParent =>
      this == CaregiverType.mother ||
      this == CaregiverType.father ||
      this == CaregiverType.otherParent;

  bool get isPaidExternal =>
      this == CaregiverType.nanny || this == CaregiverType.daycare;

  static CaregiverType fromName(String name) =>
      CaregiverType.values.firstWhere((t) => t.name == name,
          orElse: () => CaregiverType.family);
}

enum Eligibility {
  anyone('Anyone'),
  motherOnly('Mom only');

  const Eligibility(this.label);
  final String label;

  static Eligibility fromName(String name) =>
      Eligibility.values.firstWhere((e) => e.name == name,
          orElse: () => Eligibility.anyone);
}

class Baby {
  const Baby({this.id = 0, required this.name, required this.color});

  final int id;
  final String name;
  final int color;

  Baby copyWith({int? id, String? name, int? color}) =>
      Baby(id: id ?? this.id, name: name ?? this.name, color: color ?? this.color);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory Baby.fromJson(Map<String, dynamic> j) => Baby(
        id: j['id'] as int,
        name: j['name'] as String,
        color: j['color'] as int,
      );
}

class Caregiver {
  const Caregiver({
    this.id = 0,
    required this.name,
    required this.type,
    required this.color,
  });

  final int id;
  final String name;
  final CaregiverType type;
  final int color;

  Caregiver copyWith({int? id, String? name, CaregiverType? type, int? color}) =>
      Caregiver(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        color: color ?? this.color,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'type': type.name, 'color': color};

  factory Caregiver.fromJson(Map<String, dynamic> j) => Caregiver(
        id: j['id'] as int,
        name: j['name'] as String,
        type: CaregiverType.fromName(j['type'] as String),
        color: j['color'] as int,
      );
}

class CareTask {
  const CareTask({
    this.id = 0,
    required this.name,
    required this.emoji,
    this.weight = 1.0,
    this.eligibility = Eligibility.anyone,
    this.countsTowardBalance = true,
    this.isCustom = false,
    this.sort = 0,
  });

  final int id;
  final String name;
  final String emoji;

  /// Effort weight: 1.0 = standard. Higher = harder / more draining.
  final double weight;
  final Eligibility eligibility;

  /// When false, entries for this task earn no fairness points.
  final bool countsTowardBalance;
  final bool isCustom;
  final int sort;

  CareTask copyWith({
    int? id,
    String? name,
    String? emoji,
    double? weight,
    Eligibility? eligibility,
    bool? countsTowardBalance,
    bool? isCustom,
    int? sort,
  }) =>
      CareTask(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        weight: weight ?? this.weight,
        eligibility: eligibility ?? this.eligibility,
        countsTowardBalance: countsTowardBalance ?? this.countsTowardBalance,
        isCustom: isCustom ?? this.isCustom,
        sort: sort ?? this.sort,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'weight': weight,
        'eligibility': eligibility.name,
        'counts': countsTowardBalance,
        'isCustom': isCustom,
        'sort': sort,
      };

  factory CareTask.fromJson(Map<String, dynamic> j) => CareTask(
        id: j['id'] as int,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        weight: (j['weight'] as num).toDouble(),
        eligibility: Eligibility.fromName(j['eligibility'] as String),
        countsTowardBalance: j['counts'] as bool,
        isCustom: j['isCustom'] as bool,
        sort: j['sort'] as int,
      );
}

class LogEntry {
  const LogEntry({
    this.id = 0,
    required this.babyId,
    required this.caregiverId,
    required this.taskId,
    required this.startMillis,
    required this.endMillis,
    this.note = '',
    this.createdBy = '',
  });

  final int id;
  final int babyId;
  final int caregiverId;
  final int taskId;
  final int startMillis;
  final int endMillis;
  final String note;

  /// Who logged this entry (user id/name). Added for the couples
  /// version — the Android app is single-user and has no equivalent;
  /// the spec requires entries to carry their creator for sync.
  final String createdBy;

  int get durationMin =>
      ((endMillis - startMillis) ~/ 60000).clamp(0, 1 << 62);

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMillis);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endMillis);

  LogEntry copyWith({
    int? id,
    int? babyId,
    int? caregiverId,
    int? taskId,
    int? startMillis,
    int? endMillis,
    String? note,
    String? createdBy,
  }) =>
      LogEntry(
        id: id ?? this.id,
        babyId: babyId ?? this.babyId,
        caregiverId: caregiverId ?? this.caregiverId,
        taskId: taskId ?? this.taskId,
        startMillis: startMillis ?? this.startMillis,
        endMillis: endMillis ?? this.endMillis,
        note: note ?? this.note,
        createdBy: createdBy ?? this.createdBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'taskId': taskId,
        'startMillis': startMillis,
        'endMillis': endMillis,
        'note': note,
        'createdBy': createdBy,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: j['id'] as int,
        babyId: j['babyId'] as int,
        caregiverId: j['caregiverId'] as int,
        taskId: j['taskId'] as int,
        startMillis: j['startMillis'] as int,
        endMillis: j['endMillis'] as int,
        note: (j['note'] as String?) ?? '',
        createdBy: (j['createdBy'] as String?) ?? '',
      );
}

/// The quick-log task Pratik asked for (2026-10-22): a general
/// bucket so a parent can log time under their own name in one
/// tap. The original app never seeded it — it only appears in a
/// TodayScreen.kt example line ("Dad • ⭐ General Care •
/// 7:00–7:15 PM"), which is where the ⭐ comes from; weight 1.0,
/// anyone, counts toward the balance.
const String kGeneralCareTaskName = 'General Care';

/// Reserved id for the seeded [generalCareTask]. The per-baby
/// default tasks use ids 1–12 and custom tasks get epoch-millis
/// ids, so 0 is always free — and because it is FIXED, both
/// parents' phones write the same Firestore document for it,
/// which is what makes the repositories' "ensure" step
/// duplicate-proof across devices.
const int kGeneralCareTaskId = 0;

/// The canonical "General Care" task: sorts before everything
/// (sort −1) and is the log form's default selection.
CareTask generalCareTask() => const CareTask(
      id: kGeneralCareTaskId,
      name: kGeneralCareTaskName,
      emoji: '⭐',
      weight: 1.0,
      eligibility: Eligibility.anyone,
      countsTowardBalance: true,
      isCustom: false,
      sort: -1,
    );

/// True when [task] is a "General Care" task (name match,
/// case-insensitive — a user-renamed or hand-created one counts).
bool isGeneralCareTask(CareTask task) =>
    task.name.trim().toLowerCase() == kGeneralCareTaskName.toLowerCase();

/// True when [tasks] has no General Care task and one should be
/// ensured into existence.
bool needsGeneralCare(List<CareTask> tasks) =>
    !tasks.any(isGeneralCareTask);

/// Order for the log form's task dropdown: General Care first
/// (one-tap quick log), then the rest in their incoming order
/// (the repositories already sort by `sort`). Deliberately NOT
/// just "sort by stored sort": an existing baby's General Care
/// may carry any stored sort value, and it must still pin first.
List<CareTask> orderTasksForDropdown(List<CareTask> tasks) => [
      ...tasks.where(isGeneralCareTask),
      ...tasks.where((t) => !isGeneralCareTask(t)),
    ];

/// Default tasks with the fairness rules baked in — ported verbatim
/// from `defaultTasks()` in the Android app's `Db.kt`.
/// Weight = effort multiplier.
List<CareTask> defaultTasks() => const [
      CareTask(
          name: 'Breastfeeding',
          emoji: '🤱',
          weight: 1.5,
          eligibility: Eligibility.motherOnly,
          sort: 0),
      CareTask(
          name: 'Pumping',
          emoji: '💦',
          weight: 1.5,
          eligibility: Eligibility.motherOnly,
          sort: 1),
      CareTask(name: 'Bottle feed', emoji: '🍼', weight: 1.0, sort: 2),
      CareTask(name: 'Diaper change', emoji: '💩', weight: 1.0, sort: 3),
      CareTask(name: 'Bath', emoji: '🛁', weight: 1.2, sort: 4),
      CareTask(name: 'Bedtime routine', emoji: '🌙', weight: 1.2, sort: 5),
      CareTask(name: 'Night soothing', emoji: '😴', weight: 1.5, sort: 6),
      CareTask(name: 'Playtime', emoji: '🧸', weight: 0.8, sort: 7),
      CareTask(name: 'Doctor visit', emoji: '🏥', weight: 2.0, sort: 8),
      CareTask(name: 'Solids / meal prep', emoji: '🥣', weight: 1.0, sort: 9),
      CareTask(name: 'Baby laundry', emoji: '🧺', weight: 0.8, sort: 10),
      CareTask(
          name: 'On-duty supervising', emoji: '👀', weight: 0.7, sort: 11),
    ];
