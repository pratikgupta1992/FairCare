/// Calendar tab — port of the Kotlin `CalendarScreen.kt`:
/// Month / Year / Lifetime fairness views for the selected baby.
///
/// * Month: a Sunday-start day grid tinted by each day's fairness
///   score; tapping a day shows its breakdown and can jump to that
///   day in the Today view.
/// * Year: twelve month tiles tinted by score; tapping one opens
///   it in Month view.
/// * Lifetime: all-time score card, parental split bar, and
///   hours-by-caregiver bars.
library;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'calendar_logic.dart' as cal;
import 'components.dart';
import 'fairness.dart';
import 'models.dart';
import 'repository.dart';
import 'ui_helpers.dart';

enum _CalMode { month, year, lifetime }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onJumpToDay});

  /// "Open in Today view" — implemented by the app shell.
  final void Function(int dayStartMillis) onJumpToDay;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _CalMode _mode = _CalMode.month;
  late int _monthCursor = cal.monthStart(DateTime.now().millisecondsSinceEpoch);
  late int _yearCursor = cal.yearStart(DateTime.now().millisecondsSinceEpoch);
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final baby = controller.selectedBaby;
    if (baby == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No baby yet. Create one — or join with a connect code — in the Babies tab.'),
        ),
      );
    }
    final repo = controller.repo;
    final entries = repo.entriesForBaby(baby.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        BabyPicker(controller: controller),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (mode, label) in [
              (_CalMode.month, 'Month'),
              (_CalMode.year, 'Year'),
              (_CalMode.lifetime, 'Lifetime'),
            ]) ...[
              FilterChip(
                selected: _mode == mode,
                onSelected: (_) => setState(() => _mode = mode),
                label: Text(label),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        switch (_mode) {
          _CalMode.month => _monthView(context, repo, entries),
          _CalMode.year => _yearView(context, repo, entries),
          _CalMode.lifetime => _lifetimeView(context, repo, entries),
        },
      ],
    );
  }

  // ----------------------------------------------------------------
  // Month
  // ----------------------------------------------------------------

  Widget _monthView(
      BuildContext context, FairCareRepository repo, List<LogEntry> all) {
    final monthEnd = cal.addMonths(_monthCursor, 1);
    final entries = all
        .where((e) => e.endMillis > _monthCursor && e.startMillis < monthEnd)
        .toList();
    final report = computeFairness(entries, repo.taskById, repo.caregiverById);
    final scheme = Theme.of(context).colorScheme;

    List<LogEntry> dayEntries(int dayStart) => entries
        .where((e) =>
            e.startMillis >= dayStart && e.startMillis < dayStart + cal.dayMillis)
        .toList();

    final cells = cal.monthCells(_monthCursor);
    final todayStart = startOfDay(DateTime.now().millisecondsSinceEpoch);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
              onPressed: () => setState(() {
                _monthCursor = cal.addMonths(_monthCursor, -1);
                _selectedDay = null;
              }),
            ),
            Text(
              cal.monthTitle(_monthCursor),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: () => setState(() {
                _monthCursor = cal.addMonths(_monthCursor, 1);
                _selectedDay = null;
              }),
            ),
          ],
        ),
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ScoreRing(score: report.score, size: 72),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.verdict,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        '${report.totalMinutes ~/ 60}h ${report.totalMinutes % 60}m logged this month',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < cells.length; r += 7)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: cells[r + c] == null
                      ? const AspectRatio(
                          aspectRatio: 1, child: SizedBox())
                      : _dayCell(
                          context,
                          cells[r + c]!,
                          dayEntries(cells[r + c]!),
                          repo,
                          isToday: cells[r + c] == todayStart,
                        ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        if (_selectedDay != null)
          _dayDetailCard(context, repo, dayEntries(_selectedDay!)),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    int dayStart,
    List<LogEntry> dayEntries,
    FairCareRepository repo, {
    required bool isToday,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final score = dayEntries.isEmpty
        ? null
        : computeFairness(dayEntries, repo.taskById, repo.caregiverById)
            .score;
    final selected = _selectedDay == dayStart;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.25)
        : score != null
            ? Color(cal.scoreTint(score))
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final dayNum = DateTime.fromMillisecondsSinceEpoch(dayStart).day;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _selectedDay = dayStart),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? scheme.primary : scheme.onSurface,
                  ),
                ),
                Text(
                  dayEntries.isNotEmpty && score != null
                      ? '${score.round()}'
                      : '·',
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayDetailCard(
      BuildContext context, FairCareRepository repo, List<LogEntry> dayEntries) {
    final ds = _selectedDay!;
    final scheme = Theme.of(context).colorScheme;
    final report =
        computeFairness(dayEntries, repo.taskById, repo.caregiverById);
    final minsByCg = <int, int>{};
    for (final e in dayEntries) {
      minsByCg[e.caregiverId] = (minsByCg[e.caregiverId] ?? 0) + e.durationMin;
    }
    final cgRows = minsByCg.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ScoreRing(score: report.score, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cal.fullDayLabel(ds),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        report.verdict,
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in cgRows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorFromInt(
                            repo.caregiverById[row.key]?.color ?? 0xFF9E9E9E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        repo.caregiverById[row.key]?.name ?? '?',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${row.value ~/ 60}h ${row.value % 60}m',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            if (dayEntries.isEmpty)
              Text(
                'Nothing logged this day.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onJumpToDay(ds),
                child: const Text('Open in Today view'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Year
  // ----------------------------------------------------------------

  Widget _yearView(
      BuildContext context, FairCareRepository repo, List<LogEntry> all) {
    final scheme = Theme.of(context).colorScheme;
    final yearEnd = cal.addYears(_yearCursor, 1);
    final yearEntries = all
        .where((e) => e.endMillis > _yearCursor && e.startMillis < yearEnd)
        .toList();
    final year = DateTime.fromMillisecondsSinceEpoch(_yearCursor).year;

    final months = <({int start, List<LogEntry> entries, FairnessReport report, int mins})>[];
    for (var m = 0; m < 12; m++) {
      final ms = cal.addMonths(_yearCursor, m);
      final me = cal.addMonths(_yearCursor, m + 1);
      final es = yearEntries
          .where((e) => e.startMillis >= ms && e.startMillis < me)
          .toList();
      months.add((
        start: ms,
        entries: es,
        report: computeFairness(es, repo.taskById, repo.caregiverById),
        mins: es.fold(0, (s, e) => s + e.durationMin),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous year',
              onPressed: () =>
                  setState(() => _yearCursor = cal.addYears(_yearCursor, -1)),
            ),
            Text(
              '$year',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next year',
              onPressed: () =>
                  setState(() => _yearCursor = cal.addYears(_yearCursor, 1)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < 12; r += 3)
          Row(
            children: [
              for (var c = 0; c < 3; c++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Material(
                      color: months[r + c].entries.isEmpty
                          ? scheme.surfaceContainerHighest
                              .withValues(alpha: 0.35)
                          : Color(cal.scoreTint(
                              months[r + c].report.score ?? 0)),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _monthCursor = months[r + c].start;
                          _selectedDay = null;
                          _mode = _CalMode.month;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cal.monthNames[r + c].substring(0, 3),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                months[r + c].entries.isEmpty
                                    ? 'no logs'
                                    : '${months[r + c].report.score?.round() ?? '–'} · ${months[r + c].mins ~/ 60}h',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          'Tap a month to see its days.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // Lifetime
  // ----------------------------------------------------------------

  Widget _lifetimeView(
      BuildContext context, FairCareRepository repo, List<LogEntry> entries) {
    final scheme = Theme.of(context).colorScheme;
    final report = computeFairness(entries, repo.taskById, repo.caregiverById);
    final daysLogged =
        entries.map((e) => startOfDay(e.startMillis)).toSet().length;
    final firstLog = entries.isEmpty
        ? null
        : entries.map((e) => e.startMillis).reduce((a, b) => a < b ? a : b);

    final minsByCg = <int, int>{};
    for (final e in entries) {
      minsByCg[e.caregiverId] = (minsByCg[e.caregiverId] ?? 0) + e.durationMin;
    }
    final cgRows = minsByCg.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxMins = cgRows.isEmpty ? 1 : cgRows.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lifetime',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ScoreRing(score: report.score, size: 88),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.verdict,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        '${report.totalMinutes ~/ 60}h ${report.totalMinutes % 60}m of care across $daysLogged days',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onPrimaryContainer),
                      ),
                      if (firstLog != null)
                        Text(
                          'Logging since ${cal.fullDateLabel(firstLog)}',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onPrimaryContainer),
                        ),
                      if (report.outsourcedShare > 0.01)
                        Text(
                          'Nanny/daycare: ${(report.outsourcedShare * 100).round()}% of all care',
                          style: TextStyle(
                              fontSize: 13, color: scheme.onPrimaryContainer),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (report.parentShare.isNotEmpty) ...[
          const Text('All-time parental share',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          SplitBar(
            segments: [
              for (final shareEntry in report.parentShare.entries)
                (
                  label: repo.caregiverById[shareEntry.key]?.name ?? '?',
                  color: colorFromInt(
                      repo.caregiverById[shareEntry.key]?.color ??
                          0xFF9E9E9E),
                  fraction: shareEntry.value,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (cgRows.isNotEmpty) ...[
          const Text('Hours by caregiver',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          for (final row in cgRows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(repo.caregiverById[row.key]?.name ?? '?',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 10,
                        color: scheme.surfaceContainerHighest,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (row.value /
                                  (maxMins == 0 ? 1 : maxMins))
                              .clamp(0.0, 1.0),
                          child: Container(
                            color: colorFromInt(
                                repo.caregiverById[row.key]?.color ??
                                    0xFF9E9E9E),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${row.value ~/ 60}h',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
