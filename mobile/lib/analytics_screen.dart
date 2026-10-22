/// Analytics tab — port of the Kotlin `AnalyticsScreen.kt`:
/// range chips (Today / 7 days / 30 days), fairness score card,
/// parental split bar, per-task "who does what" bars, hour-by-hour
/// heatmap of the last two weeks, the "how the score works"
/// explainer, and CSV export of the selected range.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_controller.dart';
import 'calendar_logic.dart' as cal;
import 'components.dart';
import 'csv_export.dart';
import 'fairness.dart';
import 'models.dart';
import 'ui_helpers.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// Matches the Kotlin `analyticsDays` default (7).
  int _days = 7;

  Future<void> _exportCsv(BuildContext context, AppController controller,
      List<LogEntry> entries) async {
    final repo = controller.repo;
    final csv = buildCsv(
      entries,
      {for (final b in repo.babies) b.id: b},
      repo.caregiverById,
      repo.taskById,
    );
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/faircare-log.csv');
      await file.writeAsString(csv);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        title: 'Share FairCare log',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export the log: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final repo = controller.repo;
    final baby = controller.selectedBaby;
    if (baby == null) {
      return const Center(child: Text('No baby selected.'));
    }
    final scheme = Theme.of(context).colorScheme;
    final all = repo.entriesForBaby(baby.id);

    // Range: [tomorrow 00:00 - days, tomorrow 00:00), overlap —
    // the Kotlin `analyticsEntries` semantics.
    final rangeEnd =
        startOfDay(DateTime.now().millisecondsSinceEpoch) + cal.dayMillis;
    final rangeStart = rangeEnd - _days * cal.dayMillis;
    final entries = all
        .where((e) => e.endMillis > rangeStart && e.startMillis < rangeEnd)
        .toList();
    final report = computeFairness(entries, repo.taskById, repo.caregiverById);

    // Heatmap: one row per day with entries, oldest first, first
    // 14 of the ascending day list (the Kotlin quirk), dominant
    // caregiver per (day, hour) cell by weighted points.
    final heatDays =
        (<int>{for (final e in all) startOfDay(e.startMillis)}.toList()
              ..sort())
            .take(14)
            .toList();
    final heatCells =
        hourlyDominant(all, repo.taskById, repo.caregiverById, heatDays);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        BabyPicker(controller: controller),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (days, label) in [
              (1, 'Today'),
              (7, '7 days'),
              (30, '30 days'),
            ]) ...[
              FilterChip(
                selected: _days == days,
                onSelected: (_) => setState(() => _days = days),
                label: Text(label),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ScoreRing(score: report.score, size: 100),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.verdict,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${report.totalMinutes ~/ 60}h ${report.totalMinutes % 60}m of parental care logged',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onPrimaryContainer),
                      ),
                      if (report.outsourcedShare > 0.01)
                        Text(
                          'Nanny/daycare covered ${(report.outsourcedShare * 100).round()}% of all care in this period.',
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
        const SizedBox(height: 16),
        if (report.parentShare.isNotEmpty) ...[
          const Text('Parental share',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          SplitBar(
            segments: [
              for (final entry in report.parentShare.entries)
                (
                  label: repo.caregiverById[entry.key]?.name ?? '?',
                  color: colorFromInt(
                      repo.caregiverById[entry.key]?.color ?? 0xFF9E9E9E),
                  fraction: entry.value,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (report.perTask.isNotEmpty) ...[
          const Text('Who does what',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          for (final ts in report.perTask.take(12))
            TaskSplitRow(
              emoji: repo.taskById[ts.taskId]?.emoji ?? '🧸',
              name: repo.taskById[ts.taskId]?.name ?? 'Task',
              shares: [
                for (final share in ts.byCaregiver.entries)
                  if (share.value > 0)
                    (
                      label: repo.caregiverById[share.key]?.name ?? '?',
                      color: colorFromInt(
                          repo.caregiverById[share.key]?.color ?? 0xFF9E9E9E),
                      fraction: ts.total > 0 ? share.value / ts.total : 0.0,
                    ),
              ],
            ),
          const SizedBox(height: 16),
        ],
        if (heatDays.isNotEmpty) ...[
          const Text('Hour by hour — who covered each hour (last 2 weeks)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            'Each cell is one hour (12a → 11p). Color = who did most of the care that hour.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Heatmap(
            days: heatDays,
            cells: heatCells,
            colorForCaregiver: (cgId) => colorFromInt(
                repo.caregiverById[cgId]?.color ?? 0xFF9E9E9E),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How the fairness score works',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                  'Each parent earns points = minutes × task weight × night bonus (1.5× between 10pm–6am). '
                  'Breastfeeding and pumping are mom-only tasks that count fully for mom. A parent who is '
                  'just supervising while the other does the task earns 0.7× and doesn\'t cancel the other '
                  'parent\'s points. Score 100 = perfectly even weighted split; 0 = one parent does '
                  'everything. Nanny/daycare time is tracked separately and never counts against a parent.',
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _exportCsv(context, controller, entries),
          icon: const Icon(Icons.ios_share),
          label: const Text('Export log as CSV (settle it with data 📊)'),
        ),
      ],
    );
  }
}
