/// Babies tab: list joined babies, create a baby (generates its
/// connect code), join a baby by code, and view/regenerate a
/// baby's connect code.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'components.dart';
import 'models.dart';
import 'ui_helpers.dart';

class BabiesScreen extends StatelessWidget {
  const BabiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final babies = controller.joinedBabies;
    return Scaffold(
      body: babies.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'No babies yet. Create one, or join one with a connect code.'),
              ),
            )
          : ListView.builder(
              itemCount: babies.length,
              itemBuilder: (context, i) {
                final baby = babies[i];
                final code = controller.repo.connectCodeFor(baby.id) ?? '—';
                return ListTile(
                  leading: CircleAvatar(
                      backgroundColor: colorFromInt(baby.color),
                      child: const Icon(Icons.child_care)),
                  title: Text(baby.name),
                  subtitle: Text('Connect code: $code'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => BabyDetailScreen(baby: baby)),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'joinBaby',
            icon: const Icon(Icons.key),
            label: const Text('Join by code'),
            onPressed: () => _showJoinDialog(context),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'createBaby',
            icon: const Icon(Icons.add),
            label: const Text('New baby'),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = AppScope.of(context);
    final nameController = TextEditingController();
    // Default matches the original app's create dialog.
    var color = kPalette[2];
    final result = await showDialog<({String name, int color})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New baby'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: "Baby's name"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              ColorPickerRow(
                selected: color,
                onPick: (c) => setState(() => color = c),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, (name: nameController.text, color: color)),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.name.trim().isEmpty || !context.mounted) {
      return;
    }
    final baby =
        await controller.createBaby(result.name.trim(), color: result.color);
    if (!context.mounted) return;
    final code = controller.repo.connectCodeFor(baby.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Created ${baby.name}. Connect code: $code — share it so the other parent can join.')),
    );
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final controller = AppScope.of(context);
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a baby'),
        content: TextField(
          controller: codeController,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Connect code', hintText: 'e.g. K7QX2M'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, codeController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    final baby = await controller.joinBabyByCode(code.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(baby == null
            ? 'No baby found for that code. Check it and try again.'
            : 'Joined ${baby.name}!'),
      ),
    );
  }
}

class BabyDetailScreen extends StatelessWidget {
  const BabyDetailScreen({super.key, required this.baby});
  final Baby baby;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final code = controller.repo.connectCodeFor(baby.id) ?? '—';
    return Scaffold(
      appBar: AppBar(title: Text(baby.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connect code',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        code,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(letterSpacing: 4),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Connect code copied.')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Anyone with this code can join this baby and log care. Share it only with caregivers you trust.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate code'),
                    onPressed: () async {
                      final newCode = await controller.repo
                          .regenerateConnectCode(baby.id);
                      controller.refresh();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'New connect code: $newCode. The old code no longer works.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
              'Entries logged: ${controller.repo.entriesForBaby(baby.id).length}',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete baby'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  /// Deletes this baby (and its entries) after an explicit
  /// confirmation — a deliberate safety addition over the original
  /// app, where delete had no confirm step: in the couples app the
  /// delete is shared, removing the baby for the other parent too.
  Future<void> _confirmDelete(BuildContext context) async {
    final controller = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${baby.name}?'),
        content: const Text(
            'This permanently deletes this baby and all its logged entries, for everyone sharing it. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.repo.deleteBaby(baby.id);
    controller.refresh();
    if (context.mounted) Navigator.of(context).pop();
  }
}
