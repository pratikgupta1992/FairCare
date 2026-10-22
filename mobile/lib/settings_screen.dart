/// Settings tab: who you are, your default role (caregiver) per
/// baby, caregiver + task management, hourly logging reminders,
/// and the signed-in account. The log-care form pre-selects the
/// default role; it can still be changed on any individual entry.
library;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'components.dart';
import 'models.dart';
import 'reminder_service.dart';
import 'reminders.dart';
import 'ui_helpers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Set when the user tries to enable reminders but the OS
  /// notification permission is denied — shows the original app's
  /// "enable them in system settings" note.
  bool _notificationDenied = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final repo = controller.repo;
    final tasks = [...repo.tasks]..sort((a, b) => a.sort.compareTo(b.sort));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Your profile',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: controller.userName,
          decoration: const InputDecoration(
            labelText: 'Your name',
            border: OutlineInputBorder(),
            helperText: 'Recorded on entries you log (created-by).',
          ),
          onFieldSubmitted: controller.setUserName,
          onChanged: controller.setUserName,
        ),
        const SizedBox(height: 32),
        Text('Default role',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
            'Pick the caregiver you usually log as, per baby. New log entries start with this caregiver selected — you can still change it on any entry.'),
        const SizedBox(height: 12),
        if (controller.joinedBabies.isEmpty)
          const Text('Join or create a baby first (Babies tab).')
        else
          ...controller.joinedBabies.map((baby) {
            final currentId = controller.defaultCaregiverIdFor(baby.id);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                        backgroundColor: colorFromInt(baby.color),
                        child: const Icon(Icons.child_care)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(baby.name)),
                    DropdownButton<int?>(
                      value: currentId,
                      hint: const Text('Not set'),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('Not set')),
                        ...repo.caregivers.map((c) =>
                            DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text('${c.name} (${c.type.label})'),
                            )),
                      ],
                      onChanged: (id) =>
                          controller.setDefaultCaregiver(baby.id, id),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 32),
        Text('Caregivers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...repo.caregivers.map((c) => ListTile(
              dense: true,
              leading: CircleAvatar(
                  radius: 10, backgroundColor: colorFromInt(c.color)),
              title: Text(c.name),
              subtitle:
                  Text(c.type.isPaidExternal ? '${c.type.label} · paid help' : c.type.label),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete caregiver',
                onPressed: () async {
                  await repo.deleteCaregiver(c.id);
                  controller.refresh();
                },
              ),
            )),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add caregiver'),
          onPressed: () => _showAddCaregiverDialog(context),
        ),
        const SizedBox(height: 32),
        Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...tasks.map((task) => ListTile(
              dense: true,
              leading: Text(task.emoji,
                  style: const TextStyle(fontSize: 20)),
              title: Text(task.name),
              subtitle: Text(
                  '${task.eligibility.label} · ${task.weight}×'
                  '${task.countsTowardBalance ? '' : ' · excluded from score'}'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showTaskDialog(context, existing: task),
            )),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add task'),
          onPressed: () => _showTaskDialog(context),
        ),
        const SizedBox(height: 32),
        _remindersSection(context, controller),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend: ${controller.backendLabel}'),
                if (controller.accountLabel != null) ...[
                  const SizedBox(height: 4),
                  Text('Signed in as ${controller.accountLabel}'),
                ],
                if (controller.onSignOut != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    onPressed: () => controller.onSignOut!(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------
  // Reminders
  // --------------------------------------------------------------

  Widget _remindersSection(BuildContext context, AppController controller) {
    final settings = controller.reminderSettings;
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Logging reminders',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          "A gentle nudge each hour to log who's caring for the baby. Skips hours you've already logged.",
          style: TextStyle(fontSize: 13, color: variant),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hourly reminders'),
          value: settings.enabled,
          onChanged: (v) async {
            if (v) {
              final granted = await ReminderService.requestPermission();
              if (!granted) {
                setState(() => _notificationDenied = true);
                return;
              }
              setState(() => _notificationDenied = false);
            }
            await controller.setRemindersEnabled(v);
          },
        ),
        if (_notificationDenied)
          Text(
            'Notifications are turned off for FairCare. Turn them on in system settings, then try again.',
            style: TextStyle(
                fontSize: 13, color: Theme.of(context).colorScheme.error),
          ),
        if (settings.enabled)
          Row(
            children: [
              const Text('Quiet hours:'),
              TextButton(
                onPressed: () => _pickQuietTime(context, controller, true),
                child: Text(fmtMinutesOfDay(settings.quietStartMin)),
              ),
              const Text('–'),
              TextButton(
                onPressed: () => _pickQuietTime(context, controller, false),
                child: Text(fmtMinutesOfDay(settings.quietEndMin)),
              ),
            ],
          ),
        Text(
          'Defaults to 10:00 PM – 7:00 AM. Tap a time to change it.',
          style: TextStyle(fontSize: 12, color: variant),
        ),
      ],
    );
  }

  Future<void> _pickQuietTime(
      BuildContext context, AppController controller, bool isStart) async {
    final settings = controller.reminderSettings;
    final current = isStart ? settings.quietStartMin : settings.quietEndMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final mins = picked.hour * 60 + picked.minute;
    await controller.setQuietHours(
      isStart ? mins : settings.quietStartMin,
      isStart ? settings.quietEndMin : mins,
    );
  }

  // --------------------------------------------------------------
  // Caregivers
  // --------------------------------------------------------------

  Future<void> _showAddCaregiverDialog(BuildContext context) async {
    final controller = AppScope.of(context);
    final nameController = TextEditingController();
    var type = CaregiverType.family;
    // The original dialog's default new-caregiver color.
    var color = kPalette[4];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add caregiver'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in CaregiverType.values)
                      FilterChip(
                        label: Text(t.label),
                        selected: type == t,
                        onSelected: (_) => setState(() => type = t),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ColorPickerRow(
                  selected: color,
                  onPick: (c) => setState(() => color = c),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result != true || nameController.text.trim().isEmpty) return;
    await controller.repo
        .addCaregiver(nameController.text.trim(), type, color);
    controller.refresh();
  }

  // --------------------------------------------------------------
  // Tasks
  // --------------------------------------------------------------

  /// Add/edit task dialog — port of the Kotlin Manage screen's
  /// task dialog: emoji + name, effort weight slider (0.5–2.5 in
  /// 0.1 steps), Anyone / Mom only, "counts toward fairness
  /// score", and delete for existing tasks.
  Future<void> _showTaskDialog(BuildContext context,
      {CareTask? existing}) async {
    final controller = AppScope.of(context);
    final repo = controller.repo;
    final emojiController =
        TextEditingController(text: existing?.emoji ?? '🧸');
    final nameController = TextEditingController(text: existing?.name ?? '');
    var weight = existing?.weight ?? 1.0;
    var momOnly =
        (existing?.eligibility ?? Eligibility.anyone) == Eligibility.motherOnly;
    var counts = existing?.countsTowardBalance ?? true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add task' : 'Edit task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: emojiController,
                        decoration:
                            const InputDecoration(labelText: 'Emoji'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        autofocus: existing == null,
                        decoration:
                            const InputDecoration(labelText: 'Name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Effort weight: ${weight.toStringAsFixed(1)}×'),
                Slider(
                  value: weight,
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  onChanged: (v) =>
                      setLocal(() => weight = (v * 10).round() / 10),
                ),
                const Text('Who can do it?'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Anyone'),
                      selected: !momOnly,
                      onSelected: (_) => setLocal(() => momOnly = false),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Mom only'),
                      selected: momOnly,
                      onSelected: (_) => setLocal(() => momOnly = true),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Counts toward fairness score'),
                  value: counts,
                  onChanged: (v) => setLocal(() => counts = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text('Delete'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == 'delete' && existing != null) {
      await repo.deleteTask(existing.id);
      controller.refresh();
      return;
    }
    if (result != 'save') return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final emoji = emojiController.text.trim();
    final eligibility =
        momOnly ? Eligibility.motherOnly : Eligibility.anyone;
    if (existing == null) {
      final maxSort = repo.tasks.isEmpty
          ? -1
          : repo.tasks.map((t) => t.sort).reduce((a, b) => a > b ? a : b);
      await repo.addTask(CareTask(
        name: name,
        emoji: emoji.isEmpty ? '🧸' : emoji,
        weight: weight,
        eligibility: eligibility,
        countsTowardBalance: counts,
        isCustom: true,
        sort: maxSort + 1,
      ));
    } else {
      await repo.updateTask(existing.copyWith(
        name: name,
        emoji: emoji.isEmpty ? existing.emoji : emoji,
        weight: weight,
        eligibility: eligibility,
        countsTowardBalance: counts,
      ));
    }
    controller.refresh();
  }
}
