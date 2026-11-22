// The account tab: who is logged in, where the data lives and how it is
// protected, with the way out.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/design/design_screen.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class PodKeys {
  static const Key webId = Key('pod.webId');
  static const Key copy = Key('pod.copy');
  static const Key protection = Key('pod.protection');
  static const Key manage = Key('pod.manage');
  static const Key logout = Key('pod.logout');
  static const Key design = Key('pod.design');
}

class PodScreen extends StatelessWidget {
  const PodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionRepository>();
    final setup = context.watch<SetupRepository>();
    final openUrl = context.read<UrlOpener>();
    final current = session.session;
    if (current == null) {
      return const PageScaffold(title: 'Your pod', children: []);
    }
    return PageScaffold(
      title: 'Your pod',
      children: [
        AppCard(
          icon: Icons.person_rounded,
          title: 'Logged in as',
          child: Row(
            children: [
              Expanded(child: Text(key: PodKeys.webId, current.webId)),
              IconButton(
                key: PodKeys.copy,
                tooltip: 'Copy WebID',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () => _copy(context, current.webId),
              ),
            ],
          ),
        ),
        AppCard(
          icon: Icons.cloud_rounded,
          title: current.provider.name,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(current.provider.serverUrl.host),
              if (setup.state case SetupReady(:final protection))
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(key: PodKeys.protection, _protection(protection)),
                ),
              const SizedBox(height: Space.sm),
              TextButton.icon(
                key: PodKeys.manage,
                onPressed: () => openUrl(current.provider.manageUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Manage your pod and data'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton.tonalIcon(
          key: PodKeys.logout,
          onPressed: session.logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: Space.xl),
          TextButton(
            key: PodKeys.design,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DesignScreen()),
            ),
            child: const Text('Design gallery (debug builds only)'),
          ),
        ],
      ],
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('WebID copied')));
  }

  String _protection(DataProtection p) => switch (p) {
    DataProtection.encrypted =>
      'Your data is encrypted with your security key. Only you can read it.',
    DataProtection.plain =>
      'Your data is stored readable, protected by your pod\'s access rules.',
  };
}
