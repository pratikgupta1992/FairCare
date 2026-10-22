/// Today tab: the selected baby's entries for today, plus the
/// add-entry button.
library;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'fairness.dart';
import 'log_entry_form.dart';
import 'ui_helpers.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

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
    final dayStart = startOfDay(DateTime.now().millisecondsSinceEpoch);
    final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
    final todays = repo
        .entriesForBaby(baby.id)
        .where((e) => e.endMillis > dayStart && e.startMillis < dayEnd)
        .toList()
      ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
    final totalMin = todays.fold(0, (sum, e) => sum + e.durationMin);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _BabyPicker(controller: controller),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              todays.isEmpty
                  ? 'Nothing logged yet today.'
                  : '${todays.length} entries · ${fmtDuration(totalMin)} of care today',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: todays.isEmpty
                ? const Center(child: Text('Tap + to log the first entry.'))
                : ListView.builder(
                    itemCount: todays.length,
                    itemBuilder: (context, i) {
                      final e = todays[i];
                      final task = repo.taskById[e.taskId];
                      final cg = repo.caregiverById[e.caregiverId];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              colorFromInt(cg?.color ?? 0xFFBDBDBD),
                          child: Text(task?.emoji ?? '•'),
                        ),
                        title: Text(task?.name ?? 'Unknown task'),
                        subtitle: Text(
                            '${cg?.name ?? '?'} · ${fmtTime(e.start)} – ${fmtTime(e.end)}'
                            '${e.note.isEmpty ? '' : ' · ${e.note}'}'),
                        trailing: Text(fmtDuration(e.durationMin)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LogEntryForm(baby: baby, existing: e),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log care'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LogEntryForm(baby: baby)),
        ),
      ),
    );
  }
}

class _BabyPicker extends StatelessWidget {
  const _BabyPicker({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final babies = controller.joinedBabies;
    if (babies.length <= 1) {
      return Text(
        babies.isEmpty ? '' : babies.first.name,
        style: Theme.of(context).textTheme.headlineSmall,
      );
    }
    return DropdownButton<int>(
      value: controller.selectedBaby?.id,
      items: babies
          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
          .toList(),
      onChanged: (id) {
        if (id != null) controller.selectBaby(id);
      },
    );
  }
}
