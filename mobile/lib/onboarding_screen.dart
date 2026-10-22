/// First-run onboarding: one screen, warm and quick.
///
/// Shown when the (signed-in, in Firebase mode) user has no baby
/// yet. Three things, in order:
///   1. Your name (recorded as created-by on entries you log).
///   2. "Create our baby" — name the baby, get its connect code
///      shown big to share with your partner — OR "Join with a
///      code" if your partner already created the baby.
///   3. Pick your default role (Mom / Dad / Parent) for that baby,
///      so logging pre-selects you; changeable per entry, always.
///
/// Existing users who already have a baby never see this (the app
/// gate in main.dart skips straight to Today).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'models.dart';
import 'ui_helpers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  /// Called when the user taps "Start logging care" at the end.
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _babyNameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _nameSeeded = false;
  bool _busy = false;
  String? _joinError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _babyNameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final theme = Theme.of(context);
    if (!_nameSeeded) {
      _nameSeeded = true;
      if (controller.userName != 'Me') _nameCtrl.text = controller.userName;
    }
    final baby = controller.selectedBaby;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to FairCare')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Sharing the care, fairly. 💛',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'FairCare lets you and your partner log who cared for your baby — and see the split add up. Let\'s get you set up.'),
          const SizedBox(height: 24),

          // ---- 1. Your name ----
          Text('1 · What should we call you?',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await controller.setUserName(_nameCtrl.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Name saved.')),
                          );
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          if (baby == null) ...[
            // ---- 2a. Create a baby ----
            Text('2 · Create our baby', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _babyNameCtrl,
              decoration: const InputDecoration(
                labelText: "Baby's name",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.child_care),
              label: const Text('Create our baby'),
              onPressed: _busy ? null : () => _create(controller),
            ),
            const SizedBox(height: 24),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or'),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 24),
            // ---- 2b. Join with a code ----
            Text('2 · Join with a code', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
                'If your partner already created your baby, enter the connect code they shared with you.'),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                labelText: 'Connect code',
                hintText: 'e.g. K7QX2M',
                border: const OutlineInputBorder(),
                errorText: _joinError,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('Join this baby'),
              onPressed: _busy ? null : () => _join(controller),
            ),
          ] else ...[
            // ---- 2 done: show the code big ----
            Text('2 · Share this code with your partner',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('${baby.name}\'s connect code'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          controller.repo.connectCodeFor(baby.id) ?? '—',
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(letterSpacing: 6),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy code',
                          onPressed: () {
                            final code =
                                controller.repo.connectCodeFor(baby.id);
                            if (code == null) return;
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Connect code copied.')),
                            );
                          },
                        ),
                      ],
                    ),
                    const Text(
                        'Your partner enters this code in FairCare to join and log care for the same baby.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ---- 3. Default role ----
            Text('3 · You are usually…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'Pick your role for this baby. Logging will pre-select it every time — you can still change it on any entry.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final type in const [
                  CaregiverType.mother,
                  CaregiverType.father,
                  CaregiverType.otherParent,
                ])
                  _roleChip(context, controller, baby.id, type),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Start logging care'),
              onPressed: widget.onFinished,
            ),
          ],
          const SizedBox(height: 12),
          // Small helper so the colorFromInt import is used and the
          // selected baby is visible even before this point.
          if (baby != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                    radius: 8, backgroundColor: colorFromInt(baby.color)),
                const SizedBox(width: 6),
                Text(baby.name),
              ],
            ),
        ],
      ),
    );
  }

  Widget _roleChip(BuildContext context, AppController controller,
      int babyId, CaregiverType type) {
    Caregiver? cg;
    for (final c in controller.repo.caregivers) {
      if (c.type == type) {
        cg = c;
        break;
      }
    }
    if (cg == null) return const SizedBox.shrink();
    final selected = controller.defaultCaregiverIdFor(babyId) == cg.id;
    return ChoiceChip(
      label: Text(type.label),
      selected: selected,
      onSelected: (_) => controller.setDefaultCaregiver(babyId, cg!.id),
    );
  }

  Future<void> _create(AppController controller) async {
    final name = _babyNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_nameCtrl.text.trim().isNotEmpty) {
        await controller.setUserName(_nameCtrl.text);
      }
      await controller.createBaby(name);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join(AppController controller) async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _joinError = null;
    });
    try {
      if (_nameCtrl.text.trim().isNotEmpty) {
        await controller.setUserName(_nameCtrl.text);
      }
      final baby = await controller.joinBabyByCode(code);
      if (baby == null && mounted) {
        setState(
            () => _joinError = 'No baby found for that code — check it and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
