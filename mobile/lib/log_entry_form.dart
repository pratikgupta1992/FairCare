/// Add / edit a care log entry.
///
/// The caregiver dropdown is pre-selected with the current user's
/// default caregiver for this baby (Settings → Default role), and
/// can still be changed for this entry — that's the whole point of
/// the default: zero extra taps in the common case, override when
/// logging on someone else's behalf.
library;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'ui_helpers.dart';

class LogEntryForm extends StatefulWidget {
  const LogEntryForm({
    super.key,
    required this.baby,
    this.existing,
    this.initialStartMillis,
    this.initialDurationMin,
  });

  final Baby baby;
  final LogEntry? existing;

  /// For a new entry: prefill the start time (epoch millis) — e.g.
  /// the hour tapped on the day timeline. Ignored when editing.
  final int? initialStartMillis;

  /// For a new entry: prefill the duration in minutes alongside
  /// [initialStartMillis].
  final int? initialDurationMin;

  @override
  State<LogEntryForm> createState() => _LogEntryFormState();
}

class _LogEntryFormState extends State<LogEntryForm> {
  CareTask? _task;
  Caregiver? _caregiver;
  late DateTime _start;
  late DateTime _end;
  final _noteController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = AppScope.of(context);
    final repo = controller.repo;
    final existing = widget.existing;
    if (existing != null) {
      _task = repo.taskById[existing.taskId];
      _caregiver = repo.caregiverById[existing.caregiverId];
      _start = existing.start;
      _end = existing.end;
      _noteController.text = existing.note;
    } else {
      _task = repo.tasks.firstOrNull;
      // Pre-select the user's default role for this baby.
      _caregiver = controller.defaultCaregiverFor(widget.baby.id) ??
          repo.caregivers.firstOrNull;
      if (widget.initialStartMillis != null) {
        _start = DateTime.fromMillisecondsSinceEpoch(
            widget.initialStartMillis!);
        _end = _start
            .add(Duration(minutes: widget.initialDurationMin ?? 60));
      } else {
        final now = DateTime.now();
        _start = DateTime(now.year, now.month, now.day, now.hour);
        _end = _start.add(const Duration(hours: 1));
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final delta = _end.difference(_start);
      _start = DateTime(
          picked.year, picked.month, picked.day, _start.hour, _start.minute);
      _end = _start.add(delta);
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    setState(() {
      final base = isStart ? _start : _end;
      final updated = DateTime(
          base.year, base.month, base.day, picked.hour, picked.minute);
      if (isStart) {
        _start = updated;
      } else {
        _end = updated;
      }
    });
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    if (_task == null || _caregiver == null) return;
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    final existing = widget.existing;
    if (existing == null) {
      await controller.repo.addEntry(LogEntry(
        babyId: widget.baby.id,
        caregiverId: _caregiver!.id,
        taskId: _task!.id,
        startMillis: _start.millisecondsSinceEpoch,
        endMillis: _end.millisecondsSinceEpoch,
        note: _noteController.text.trim(),
        createdBy: controller.userName,
      ));
    } else {
      await controller.repo.updateEntry(existing.copyWith(
        caregiverId: _caregiver!.id,
        taskId: _task!.id,
        startMillis: _start.millisecondsSinceEpoch,
        endMillis: _end.millisecondsSinceEpoch,
        note: _noteController.text.trim(),
      ));
    }
    controller.refresh();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final controller = AppScope.of(context);
    await controller.repo.deleteEntry(widget.existing!.id);
    controller.refresh();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final repo = controller.repo;
    final defaultCg = controller.defaultCaregiverFor(widget.baby.id);
    final isDefaultSelected =
        defaultCg != null && _caregiver?.id == defaultCg.id;
    final momOnlyWarning = _task != null &&
        _task!.eligibility == Eligibility.motherOnly &&
        _caregiver != null &&
        _caregiver!.type != CaregiverType.mother;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Log care' : 'Edit entry'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete entry',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Baby: ${widget.baby.name}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<CareTask>(
            initialValue: _task,
            decoration: const InputDecoration(
                labelText: 'Task', border: OutlineInputBorder()),
            items: repo.tasks
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                          '${t.emoji} ${t.name}${t.eligibility == Eligibility.motherOnly ? ' (Mom only)' : ''}'),
                    ))
                .toList(),
            onChanged: (t) => setState(() => _task = t),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Caregiver>(
            initialValue: _caregiver,
            decoration: InputDecoration(
              labelText: 'Caregiver',
              border: const OutlineInputBorder(),
              helperText: isDefaultSelected
                  ? 'Your default role — change it to log for someone else.'
                  : null,
            ),
            items: repo.caregivers
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          CircleAvatar(
                              radius: 8,
                              backgroundColor: colorFromInt(c.color)),
                          const SizedBox(width: 8),
                          Text('${c.name} (${c.type.label})'),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (c) => setState(() => _caregiver = c),
          ),
          if (momOnlyWarning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Heads up: this task is marked Mom-only.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(fmtDate(_start)),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(true),
                  child: Text('Start: ${fmtTime(_start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(false),
                  child: Text('End: ${fmtTime(_end)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'Duration: ${fmtDuration(_end.difference(_start).inMinutes)}'),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
                labelText: 'Note (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Save entry'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
