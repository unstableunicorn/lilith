// Choose a pod provider and log in.

import 'package:material_ui/material_ui.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/login/login_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:provider/provider.dart';

/// Keys the tests find the screen's parts by.
abstract final class LoginKeys {
  static Key provider(PodProvider p) => Key('login.provider.${p.serverUrl}');
  static const Key other = Key('login.other');
  static const Key server = Key('login.server');
  static const Key login = Key('login.login');
  static const Key busy = Key('login.busy');
  static const Key error = Key('login.error');
  static const Key manage = Key('login.manage');
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => LoginViewModel(context.read<SessionRepository>()),
    child: const _LoginView(),
  );
}

// The radio value standing for "another provider".
const Object _other = 'other';

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final openUrl = context.read<UrlOpener>();
    return PageScaffold(
      title: 'Lilith',
      children: [
        const SectionHeading('Where is your pod?'),
        RadioGroup<Object>(
          groupValue: vm.isCustom ? _other : vm.selected,
          onChanged: (value) => value == _other
              ? vm.chooseCustom()
              : vm.choose(value! as PodProvider),
          child: Column(
            children: [
              for (final p in vm.builtIn)
                RadioListTile<Object>(
                  key: LoginKeys.provider(p),
                  title: Text(p.name),
                  subtitle: Text(p.serverUrl.host),
                  value: p,
                ),
              const RadioListTile<Object>(
                key: LoginKeys.other,
                title: Text('Another provider'),
                value: _other,
              ),
            ],
          ),
        ),
        if (vm.isCustom)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: TextField(
              key: LoginKeys.server,
              controller: _controllerFor(vm),
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Pod server',
                hintText: 'pods.example.org',
              ),
              onChanged: vm.setCustomServer,
            ),
          ),
        const SizedBox(height: Space.lg),
        if (vm.error case final error?)
          ProblemText(key: LoginKeys.error, _describe(error)),
        if (vm.isBusy)
          const BusyIndicator(key: LoginKeys.busy, label: 'Logging in'),
        FilledButton(
          key: LoginKeys.login,
          onPressed: vm.canLogin ? () => vm.login(context) : null,
          child: const Text('Log in'),
        ),
        if (vm.manageUrl case final url?)
          TextButton(
            key: LoginKeys.manage,
            onPressed: () => openUrl(url),
            child: const Text('Manage your pod and data'),
          ),
      ],
    );
  }

  // The field is rebuilt with the model's text so a remembered server shows.
  TextEditingController _controllerFor(LoginViewModel vm) {
    final c = TextEditingController(text: vm.customServer);
    c.selection = TextSelection.collapsed(offset: c.text.length);
    return c;
  }

  String _describe(LoginError error) => switch (error) {
    LoginError.invalidServer => 'That does not look like a server address.',
    LoginError.cancelled => 'The login was not finished.',
    LoginError.failed => 'The provider did not log you in. Try again.',
    LoginError.unreachable => 'The provider could not be reached.',
  };
}
