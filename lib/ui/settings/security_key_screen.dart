// Settings > Security key: change the key that encrypts this pod's data.

import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/settings/security_key_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class SecurityKeyKeys {
  static const Key current = Key('securityKey.current');
  static const Key newKey = Key('securityKey.new');
  static const Key confirmKey = Key('securityKey.confirm');
  static const Key problem = Key('securityKey.problem');
  static const Key change = Key('securityKey.change');
  static const Key busy = Key('securityKey.busy');
  static const Key changed = Key('securityKey.changed');
  static const Key wrongKey = Key('securityKey.wrongKey');
  static const Key unchanged = Key('securityKey.unchanged');
  static const Key broken = Key('securityKey.broken');
}

class SecurityKeyScreen extends StatelessWidget {
  const SecurityKeyScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => SecurityKeyViewModel(context.read<SetupRepository>()),
    child: const _SecurityKeyView(),
  );
}

class _SecurityKeyView extends StatelessWidget {
  const _SecurityKeyView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SecurityKeyViewModel>();
    return PageScaffold(
      title: 'Security key',
      children: [
        if (vm.outcome == KeyChangeOutcome.changed)
          const AppCard(
            icon: Icons.check_circle_rounded,
            title: 'Key changed',
            child: Text(
              key: SecurityKeyKeys.changed,
              'Use the new key from now on. Your other devices ask for it the '
              'next time Lilith starts there.',
            ),
          )
        else
          ..._form(vm),
      ],
    );
  }

  List<Widget> _form(SecurityKeyViewModel vm) => [
    const Text(
      'Your data stays as it is; only the key that opens it changes. There is '
      'no way to recover a lost key, so keep the new one somewhere safe.',
    ),
    const SizedBox(height: Space.sm),
    TextField(
      key: SecurityKeyKeys.current,
      obscureText: true,
      onChanged: vm.setCurrentKey,
      decoration: const InputDecoration(labelText: 'Current security key'),
    ),
    TextField(
      key: SecurityKeyKeys.newKey,
      obscureText: true,
      onChanged: vm.setNewKey,
      decoration: const InputDecoration(
        labelText: 'New security key',
        helperText: 'At least 8 characters.',
      ),
    ),
    TextField(
      key: SecurityKeyKeys.confirmKey,
      obscureText: true,
      onChanged: vm.setConfirmKey,
      decoration: const InputDecoration(labelText: 'New security key again'),
    ),
    if (vm.problem case final problem? when vm.newKey.isNotEmpty)
      ProblemText(key: SecurityKeyKeys.problem, switch (problem) {
        NewKeyProblem.tooShort => 'Make it at least 8 characters.',
        NewKeyProblem.mismatch => 'The two entries differ.',
        NewKeyProblem.sameAsCurrent => 'That is the key you have now.',
      }),
    if (vm.outcome case final outcome?) _outcome(outcome),
    const SizedBox(height: Space.lg),
    if (vm.isChanging)
      const BusyIndicator(key: SecurityKeyKeys.busy, label: 'Changing the key')
    else
      FilledButton(
        key: SecurityKeyKeys.change,
        onPressed: vm.canChange ? vm.change : null,
        child: const Text('Change key'),
      ),
  ];

  Widget _outcome(KeyChangeOutcome outcome) => switch (outcome) {
    KeyChangeOutcome.changed => const SizedBox.shrink(),
    KeyChangeOutcome.wrongKey => const ProblemText(
      key: SecurityKeyKeys.wrongKey,
      'That is not the current security key for this pod.',
    ),
    KeyChangeOutcome.unchanged => const ProblemText(
      key: SecurityKeyKeys.unchanged,
      'The key could not be changed. Your current key still works.',
    ),
    KeyChangeOutcome.broken => const ProblemText(
      key: SecurityKeyKeys.broken,
      'The change stopped part way and the old key files could not be put '
      'back. Keep both keys written down and do not set the pod up again; '
      'report this so the files can be repaired.',
    ),
  };
}
