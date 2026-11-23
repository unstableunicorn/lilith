// Wiring only: the real services, the providers, and which screen shows.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/export/share_file.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/notifications/local_notification_service.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/pod/share_reader.dart';
import 'package:lilith/data/pod/share_service.dart';
import 'package:lilith/data/pod/solid_pod_service.dart';
import 'package:lilith/data/pod/solid_pod_session_service.dart';
import 'package:lilith/data/pod/solid_pod_setup_service.dart';
import 'package:lilith/data/pod/solid_share_reader.dart';
import 'package:lilith/data/pod/solid_share_service.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/core/file_sharer.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/login/login_screen.dart';
import 'package:lilith/ui/setup/setup_screen.dart';
import 'package:lilith/ui/shell/app_shell.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final settings = SharedPreferencesSettingsStore();
  if (ShareInvite.fromUri(Uri.base) case final invite?) {
    unawaited(settings.writeInvite(invite));
  }
  final session = SessionRepository(SolidPodSessionService(settings), settings);
  unawaited(session.restore());
  runApp(
    LilithApp(
      session: session,
      setup: SetupRepository(const SolidPodSetupService()),
      podFor: (provider) => SolidPodService(provider: provider),
      shareService: const SolidShareService(),
      shareReader: const SolidShareReader(),
      settings: settings,
      notifications: kIsWeb
          ? const NoNotificationService()
          : LocalNotificationService(),
      openUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      shareFile: shareExportFile,
      pdfReport: const PdfReport(loadTheme: robotoTheme),
    ),
  );
}

abstract final class AppKeys {
  static const Key restoring = Key('app.restoring');
}

class LilithApp extends StatelessWidget {
  const LilithApp({
    required this.session,
    required this.setup,
    required this.podFor,
    required this.shareService,
    required this.shareReader,
    required this.settings,
    required this.notifications,
    required this.openUrl,
    required this.shareFile,
    required this.pdfReport,
    super.key,
  });

  final SessionRepository session;
  final SetupRepository setup;

  /// The pod behind the logged-in provider.
  final PodService Function(PodProvider provider) podFor;
  final ShareService shareService;
  final ShareReader shareReader;
  final SettingsStore settings;
  final NotificationService notifications;
  final UrlOpener openUrl;
  final FileSharer shareFile;
  final PdfReport pdfReport;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: setup),
      Provider<UrlOpener>.value(value: openUrl),
      Provider<FileSharer>.value(value: shareFile),
      Provider<PdfReport>.value(value: pdfReport),
      Provider<PodService Function(PodProvider)>.value(value: podFor),
      Provider<ShareService>.value(value: shareService),
      Provider<ShareReader>.value(value: shareReader),
      Provider<SettingsStore>.value(value: settings),
      Provider<NotificationService>.value(value: notifications),
      ChangeNotifierProvider(
        // Not lazy: a reminder lost to a reboot is set again at start.
        lazy: false,
        create: (_) => ReminderRepository(settings, notifications)..loadLater(),
      ),
    ],
    child: MaterialApp(
      title: 'Lilith',
      theme: lilithTheme(Brightness.light),
      darkTheme: lilithTheme(Brightness.dark),
      home: const _Root(),
    ),
  );
}

/// Login, then set-up, then home. Set-up starts when a session appears and is
/// forgotten when it goes.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  PodSession? _seen;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionRepository>();
    final setup = context.watch<SetupRepository>();
    _follow(session.session, setup);

    if (session.isRestoring) {
      return const Scaffold(
        body: Center(
          key: AppKeys.restoring,
          child: CircularProgressIndicator(),
        ),
      );
    }
    final current = session.session;
    if (current == null) return const LoginScreen();
    return switch (setup.state) {
      SetupReady(:final protection) => _home(context, current, protection),
      _ => const SetupScreen(),
    };
  }

  // Reacts to the session changing: inspect the pod on login, reset on logout.
  void _follow(PodSession? current, SetupRepository setup) {
    if (current == _seen) return;
    _seen = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (current == null) {
        setup.reset();
      } else {
        unawaited(setup.inspect());
      }
    });
  }

  Widget _home(
    BuildContext context,
    PodSession current,
    DataProtection protection,
  ) => ChangeNotifierProvider(
    key: ValueKey((current, protection)),
    // Not lazy: the data starts loading as soon as home appears.
    lazy: false,
    create: (context) {
      final podFor = context.read<PodService Function(PodProvider)>();
      final repo = HealthRepository(
        podFor(current.provider),
        protection: protection,
      );
      unawaited(repo.load());
      return repo;
    },
    child: ChangeNotifierProvider(
      // Not lazy either: shares past their day end as soon as the data is in.
      lazy: false,
      create: (context) {
        final health = context.read<HealthRepository>();
        final shares = ShareRepository(
          health,
          context.read<ShareService>(),
          protection: protection,
          notifications: context.read<NotificationService>(),
        );
        unawaited(health.load().then((_) => shares.sweep(DateTime.now())));
        return shares;
      },
      child: ChangeNotifierProvider(
        // Not lazy: an invite the app was opened with shows on Today at once.
        lazy: false,
        create: (context) => ReceivedShareRepository(
          context.read<HealthRepository>(),
          context.read<ShareReader>(),
          ownWebId: current.webId,
          settings: context.read<SettingsStore>(),
        )..loadInviteLater(),
        child: const AppShell(),
      ),
    ),
  );
}
