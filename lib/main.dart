// Wiring only: the real services, the providers, and which screen shows.

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:lilith/data/pod/solid_pod_session_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/login/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final settings = SharedPreferencesSettingsStore();
  final session = SessionRepository(SolidPodSessionService(settings), settings);
  unawaited(session.restore());
  runApp(
    LilithApp(
      session: session,
      openUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
    ),
  );
}

abstract final class AppKeys {
  static const Key restoring = Key('app.restoring');
}

class LilithApp extends StatelessWidget {
  const LilithApp({required this.session, required this.openUrl, super.key});

  final SessionRepository session;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      Provider<UrlOpener>.value(value: openUrl),
    ],
    child: MaterialApp(
      title: 'Lilith',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF7B4FB6)),
      home: const _Root(),
    ),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionRepository>();
    if (session.isRestoring) {
      return const Scaffold(
        body: Center(
          key: AppKeys.restoring,
          child: CircularProgressIndicator(),
        ),
      );
    }
    return session.session == null ? const LoginScreen() : const HomeScreen();
  }
}
