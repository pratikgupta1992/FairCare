/// Settings tab: who you are, and your default role (caregiver)
/// per baby. The log-care form pre-selects this default; it can
/// still be changed on any individual entry.
library;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'ui_helpers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final repo = controller.repo;
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
              subtitle: Text(c.type.label),
            )),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add caregiver'),
          onPressed: () => _showAddCaregiverDialog(context),
        ),
        const SizedBox(height: 32),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Backend: local (on-device) for now. Firebase sync is stubbed behind the same repository interface — see BUILD_NOTES.md.'),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddCaregiverDialog(BuildContext context) async {
    final controller = AppScope.of(context);
    final nameController = TextEditingController();
    var type = CaregiverType.family;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add caregiver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButton<CaregiverType>(
                value: type,
                isExpanded: true,
                items: CaregiverType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (t) => setState(() => type = t ?? type),
              ),
            ],
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
        .addCaregiver(nameController.text.trim(), type, 0xFFAB47BC);
    controller.refresh();
  }
}
