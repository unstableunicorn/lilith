// First use on a pod: choose how the data is protected, or enter the key.

import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/setup/setup_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class SetupKeys {
  static Key option(DataProtection p) => Key('setup.option.${p.name}');
  static Key explanation(DataProtection p) => Key('setup.explain.${p.name}');
  static const Key key = Key('setup.key');
  static const Key confirmKey = Key('setup.confirmKey');
  static const Key keyProblem = Key('setup.keyProblem');
  static const Key confirm = Key('setup.confirm');
  static const Key unlock = Key('setup.unlock');
  static const Key retry = Key('setup.retry');
  static const Key error = Key('setup.error');
  static const Key errorDetail = Key('setup.errorDetail');
  static const Key busy = Key('setup.busy');
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => SetupViewModel(context.read<SetupRepository>()),
    child: const _SetupView(),
  );
}

class _SetupView extends StatelessWidget {
  const _SetupView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SetupViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Lilith')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...switch (vm.state) {
            SetupChoose() => _chooser(context, vm),
            SetupEnterKey() => _unlocker(vm),
            SetupUnknown() || SetupReady() => _waiting(vm),
          },
          if (vm.error case final error?)
            Padding(
              key: SetupKeys.error,
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _describe(error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (vm.errorDetail case final detail?)
            SelectableText(
              key: SetupKeys.errorDetail,
              detail,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (vm.isBusy)
            const Center(
              key: SetupKeys.busy,
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _chooser(BuildContext context, SetupViewModel vm) => [
    const Text('How should your data be stored on your pod?'),
    const SizedBox(height: 8),
    RadioGroup<DataProtection>(
      groupValue: vm.choice,
      onChanged: (value) => vm.choose(value!),
      child: Column(
        children: [
          for (final p in DataProtection.values)
            RadioListTile<DataProtection>(
              key: SetupKeys.option(p),
              value: p,
              title: Text(_title(p)),
              subtitle: Text(key: SetupKeys.explanation(p), _explain(p)),
              isThreeLine: true,
            ),
        ],
      ),
    ),
    if (vm.choice == DataProtection.encrypted) ...[
      const SizedBox(height: 8),
      TextField(
        key: SetupKeys.key,
        obscureText: true,
        onChanged: vm.setKey,
        decoration: const InputDecoration(
          labelText: 'Security key',
          helperText: 'At least 8 characters. There is no way to recover it.',
        ),
      ),
      TextField(
        key: SetupKeys.confirmKey,
        obscureText: true,
        onChanged: vm.setConfirmKey,
        decoration: const InputDecoration(labelText: 'Security key again'),
      ),
      if (vm.keyProblem case final problem? when vm.key.isNotEmpty)
        Padding(
          key: SetupKeys.keyProblem,
          padding: const EdgeInsets.only(top: 8),
          child: Text(switch (problem) {
            KeyProblem.tooShort => 'Make it at least 8 characters.',
            KeyProblem.mismatch => 'The two entries differ.',
          }, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ],
    const SizedBox(height: 16),
    FilledButton(
      key: SetupKeys.confirm,
      onPressed: vm.canConfirm ? vm.confirm : null,
      child: const Text('Continue'),
    ),
  ];

  List<Widget> _unlocker(SetupViewModel vm) => [
    const Text(
      'Your data on this pod is encrypted. Enter the security key you chose '
      'when you set it up.',
    ),
    const SizedBox(height: 8),
    TextField(
      key: SetupKeys.key,
      obscureText: true,
      onChanged: vm.setKey,
      decoration: const InputDecoration(labelText: 'Security key'),
    ),
    const SizedBox(height: 16),
    FilledButton(
      key: SetupKeys.unlock,
      onPressed: vm.canUnlock ? vm.unlock : null,
      child: const Text('Unlock'),
    ),
  ];

  List<Widget> _waiting(SetupViewModel vm) => [
    if (!vm.isBusy)
      FilledButton(
        key: SetupKeys.retry,
        onPressed: vm.retry,
        child: const Text('Try again'),
      ),
  ];

  String _title(DataProtection p) => switch (p) {
    DataProtection.encrypted => 'Encrypted (recommended)',
    DataProtection.plain => 'Plain',
  };

  String _explain(DataProtection p) => switch (p) {
    DataProtection.encrypted =>
      'Encrypted on your device with a security key only you know. Nobody '
          'who can reach your pod, including its provider, can read your data. '
          'You choose the key now and enter it once on each new device. '
          'There is no recovery: lose the key and the data is unreadable. '
          'Sharing works only with apps that use the same scheme.',
    DataProtection.plain =>
      'Stored readable, protected only by your pod\'s access control. One '
          'password, nothing to lose, readable in any Solid app and in your '
          'pod\'s own data browser. Anyone with access to the pod, including '
          'its provider, can read your health data.',
  };

  String _describe(SetupError error) => switch (error) {
    SetupError.unreachable => 'Your pod could not be reached.',
    SetupError.wrongKey => 'That is not the security key for this pod.',
    SetupError.failed => 'Setting up your pod did not work. Try again.',
  };
}
