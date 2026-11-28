// Wiring only: the real services, the providers, and which screen shows.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:lilith/data/app_lock_repository.dart';
import 'package:lilith/data/biometrics.dart';
import 'package:lilith/data/contraception_reminder_repository.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/export/share_file.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/local_biometrics.dart';
import 'package:lilith/data/mode_memory.dart';
import 'package:lilith/data/notifications/local_notification_service.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/period_reminder_repository.dart';
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
import 'package:lilith/data/wearable/wearable_repository.dart';
import 'package:lilith/data/wearable/wearable_source.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/core/browser_history.dart';
import 'package:lilith/ui/core/file_sharer.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/lock/lock_screen.dart';
import 'package:lilith/ui/login/login_screen.dart';
import 'package:lilith/ui/mode/mode_screen.dart';
import 'package:lilith/ui/setup/setup_screen.dart';
import 'package:lilith/ui/shell/app_router.dart';
import 'package:lilith/ui/shell/app_shell.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final settings = SharedPreferencesSettingsStore();
  if (ShareInvite.fromUri(Uri.base) case final invite?) {
    unawaited(settings.writeInvite(invite));
  }
  final notifications = kIsWeb
      ? const NoNotificationService()
      : LocalNotificationService();
  final session = SessionRepository(
    SolidPodSessionService(settings),
    settings,
    onLogout: () async {
      await cancelPeriodReminders(notifications);
      await cancelContraceptionReminders(notifications);
    },
  );
  unawaited(session.restore());
  runApp(
    LilithApp(
      session: session,
      setup: SetupRepository(const SolidPodSetupService()),
      podFor: (provider) => SolidPodService(provider: provider),
      shareService: const SolidShareService(),
      shareReader: const SolidShareReader(),
      settings: settings,
      notifications: notifications,
      // The Android source comes once the Galaxy Watch spike has chosen it.
      wearable: const NoWearableSource(),
      openUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      // An attachment loaded in this tab downloads and leaves the app shown.
      download: Downloader((url) => launchUrl(url, webOnlyWindowName: '_self')),
      shareFile: shareExportFile,
      pdfReport: const PdfReport(loadTheme: robotoTheme),
      browserHistory: platformBrowserHistory(),
      biometrics: kIsWeb ? const NoBiometrics() : LocalBiometrics(),
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
    required this.wearable,
    required this.openUrl,
    required this.download,
    required this.shareFile,
    required this.pdfReport,
    required this.browserHistory,
    this.biometrics = const NoBiometrics(),
    this.now = DateTime.now,
    super.key,
  });

  /// The fingerprint or face check for the app lock; none on the web.
  final Biometrics biometrics;

  /// The clock the app lock times the background by, injected for tests.
  final DateTime Function() now;

  final SessionRepository session;
  final SetupRepository setup;

  /// The pod behind the logged-in provider.
  final PodService Function(PodProvider provider) podFor;
  final ShareService shareService;
  final ShareReader shareReader;
  final SettingsStore settings;
  final NotificationService notifications;
  final WearableSource wearable;
  final UrlOpener openUrl;
  final Downloader download;
  final FileSharer shareFile;
  final PdfReport pdfReport;
  final BrowserHistory browserHistory;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: setup),
      Provider<UrlOpener>.value(value: openUrl),
      Provider<Downloader>.value(value: download),
      Provider<FileSharer>.value(value: shareFile),
      Provider<PdfReport>.value(value: pdfReport),
      Provider<PodService Function(PodProvider)>.value(value: podFor),
      Provider<ShareService>.value(value: shareService),
      Provider<ShareReader>.value(value: shareReader),
      Provider<SettingsStore>.value(value: settings),
      Provider<NotificationService>.value(value: notifications),
      Provider<WearableSource>.value(value: wearable),
      ChangeNotifierProvider(
        // Not lazy: read before login, so the right tabs show at once.
        lazy: false,
        create: (_) {
          final memory = ModeMemory(settings);
          unawaited(memory.load());
          return memory;
        },
      ),
      ChangeNotifierProvider(
        // Not lazy: the tabs read it as soon as they build.
        lazy: false,
        create: (_) {
          final pages = PageSettingsRepository(settings);
          unawaited(pages.load());
          return pages;
        },
      ),
      ChangeNotifierProvider(
        // Not lazy: a reminder lost to a reboot is set again at start.
        lazy: false,
        create: (_) => ReminderRepository(settings, notifications)..loadLater(),
      ),
      ChangeNotifierProvider(
        // Not lazy: it must know whether to lock before anything shows.
        lazy: false,
        create: (_) {
          final lock = AppLockRepository(
            settings,
            biometrics,
            signOut: session.logout,
            now: now,
          );
          unawaited(lock.load());
          return lock;
        },
      ),
    ],
    child: _RoutedApp(browserHistory: browserHistory),
  );
}

/// The app lock over everything once signed in, pages opened over the tabs
/// included. The app stays built beneath, offstage, so nothing typed is lost
/// and nothing of it is drawn or read out while locked.
class _LockGate extends StatefulWidget {
  const _LockGate({required this.child});

  final Widget child;

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () => context.read<AppLockRepository>().paused(),
      onResume: () => context.read<AppLockRepository>().resumed(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionRepository>().session != null;
    final lock = context.watch<AppLockRepository>();
    // Until the setting is read, show nothing rather than the data.
    final hidden = signedIn && (!lock.isLoaded || lock.isLocked);
    return Stack(
      children: [
        Offstage(offstage: hidden, child: widget.child),
        if (signedIn && lock.isLocked) const LockScreen(),
      ],
    );
  }
}

/// The app inside a Router, so each tab and page is a browser history entry
/// on the web.
class _RoutedApp extends StatefulWidget {
  const _RoutedApp({required this.browserHistory});

  final BrowserHistory browserHistory;

  @override
  State<_RoutedApp> createState() => _RoutedAppState();
}

class _RoutedAppState extends State<_RoutedApp> {
  final ShellTabs _tabs = ShellTabs();
  late final AppRouterDelegate _router = AppRouterDelegate(
    tabs: _tabs,
    history: widget.browserHistory,
    child: const _Root(),
  );
  StreamSubscription<ReminderAction>? _opened;

  @override
  void initState() {
    super.initState();
    _opened = context.read<NotificationService>().opened.listen((action) {
      if (action == ReminderAction.log) {
        _router.openLog(dateOnly(DateTime.now()));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_opened?.cancel());
    _router.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _tabs,
    child: MaterialApp.router(
      title: 'Lilith',
      theme: lilithTheme(Brightness.light),
      darkTheme: lilithTheme(Brightness.dark),
      routerDelegate: _router,
      routeInformationParser: const AppLocationParser(),
      backButtonDispatcher: RootBackButtonDispatcher(),
      builder: (context, app) => _LockGate(child: app!),
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
        context.read<ShellTabs>().reset();
        // The next person to sign in here may use the app another way.
        unawaited(context.read<ModeMemory>().forget());
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
          pageSettings: context.read<PageSettingsRepository>(),
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
        child: ChangeNotifierProvider(
          create: (context) => WearableRepository(
            context.read<HealthRepository>(),
            context.read<WearableSource>(),
            now: DateTime.now,
          ),
          child: Provider(
            // Not lazy: it follows the data from the first load.
            lazy: false,
            create: (context) => PeriodReminderRepository(
              context.read<HealthRepository>(),
              context.read<ReminderRepository>(),
              context.read<NotificationService>(),
              context.read<SettingsStore>(),
            ),
            dispose: (_, repo) => repo.dispose(),
            child: Provider(
              lazy: false,
              create: (context) => ContraceptionReminderRepository(
                context.read<HealthRepository>(),
                context.read<ReminderRepository>(),
                context.read<NotificationService>(),
                context.read<SettingsStore>(),
              ),
              dispose: (_, repo) => repo.dispose(),
              // A new person says how they use Lilith before the tabs.
              child: const ModeGate(child: AppShell()),
            ),
          ),
        ),
      ),
    ),
  );
}
