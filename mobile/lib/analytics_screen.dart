/// Analytics tab: fairness summary for the selected baby, using
/// the ported Kotlin fairness logic (weighted points, night bonus,
/// task weights, outsourced share).
library;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'fairness.dart';
import 'ui_helpers.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final baby = controller.selectedBaby;
    if (baby == null) {
      return const Center(child: Text('No baby selected.'));
    }
    final repo = controller.repo;
    final entries = repo.entriesForBaby(baby.id);
    final report =
        computeFairness(entries, repo.taskById, repo.caregiverById);

    // Points for every caregiver (not just parents) for the bars.
    final pointsByCaregiver = <int, double>{};
    for (final e in entries) {
      final task = repo.taskById[e.taskId];
      if (task == null) continue;
      pointsByCaregiver[e.caregiverId] =
          (pointsByCaregiver[e.caregiverId] ?? 0) + weightedPoints(e, task);
    }
    final maxPoints = pointsByCaregiver.values.isEmpty
        ? 0.0
        : pointsByCaregiver.values.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Fairness for ${baby.name}',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  report.score == null
                      ? '—'
                      : '${report.score!.round()} / 100',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 4),
                Text(report.verdict,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                    'Total logged: ${fmtDuration(report.totalMinutes)} · '
                    'Outsourced (nanny/daycare): ${(report.outsourcedShare * 100).round()}%'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Weighted points by caregiver',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (pointsByCaregiver.isEmpty)
          const Text('No entries yet — log some care to see the split.')
        else
          ...repo.caregivers
              .where((c) => pointsByCaregiver.containsKey(c.id))
              .map((c) {
            final pts = pointsByCaregiver[c.id]!;
            final share = report.parentShare[c.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                          radius: 8,
                          backgroundColor: colorFromInt(c.color)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '${c.name} (${c.type.label})${share == null ? '' : ' · ${(share * 100).round()}% of parent points'}')),
                      Text(pts.toStringAsFixed(0)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: maxPoints > 0 ? pts / maxPoints : 0,
                    backgroundColor:
                        colorFromInt(c.color).withValues(alpha: 0.2),
                    valueColor:
                        AlwaysStoppedAnimation(colorFromInt(c.color)),
                    minHeight: 8,
                  ),
                ],
              ),
            );
          }),
        if (report.perTask.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('By task (weighted points)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...report.perTask.map((split) {
            final task = repo.taskById[split.taskId];
            return ListTile(
              dense: true,
              leading: Text(task?.emoji ?? '•',
                  style: const TextStyle(fontSize: 20)),
              title: Text(task?.name ?? 'Unknown task'),
              trailing: Text(split.total.toStringAsFixed(0)),
            );
          }),
        ],
      ],
    );
  }
}
