// The signed-in landing screen. The cycle features arrive here slice by slice.

import 'package:material_ui/material_ui.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:provider/provider.dart';

abstract final class HomeKeys {
  static const Key webId = Key('home.webId');
  static const Key manage = Key('home.manage');
  static const Key logout = Key('home.logout');
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionRepository>();
    final current = session.session;
    final openUrl = context.read<UrlOpener>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lilith'),
        actions: [
          IconButton(
            key: HomeKeys.logout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: session.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Logged in as'),
          SelectableText(key: HomeKeys.webId, current?.webId ?? ''),
          const SizedBox(height: 16),
          if (current != null)
            TextButton(
              key: HomeKeys.manage,
              onPressed: () => openUrl(current.provider.manageUrl),
              child: Text('Manage your pod at ${current.provider.name}'),
            ),
        ],
      ),
    );
  }
}
