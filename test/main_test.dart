import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/data/wearable/wearable_source.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_reminders.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/main.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/login/login_screen.dart';
import 'package:lilith/ui/setup/setup_screen.dart';
import 'package:lilith/ui/shell/app_shell.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_browser_history.dart';
import 'fakes/fake_notification_service.dart';
import 'fakes/fake_pod_service.dart';
import 'fakes/fake_pod_session_service.dart';
import 'fakes/fake_pod_setup_service.dart';
import 'fakes/fake_settings_store.dart';
import 'fakes/fake_share_reader.dart';
import 'fakes/fake_share_service.dart';

void main() {
  late FakePodSessionService auth;
  late FakePodSetupService podSetup;
  late SessionRepository session;
  late SetupRepository setup;
  late FakePodService pod;
  late FakeNotificationService notifications;

  setUp(() {
    notifications = FakeNotificationService();
    auth = FakePodSessionService();
    podSetup = FakePodSetupService();
    session = SessionRepository(auth, FakeSettingsStore());
    setup = SetupRepository(podSetup);
    pod = FakePodService();
  });

  LilithApp app() => LilithApp(
    session: session,
    setup: setup,
    podFor: (_) => pod,
    shareService: FakeShareService(),
    shareReader: FakeShareReader(),
    settings: FakeSettingsStore(),
    notifications: notifications,
    wearable: const NoWearableSource(),
    openUrl: (_) async {},
    download: Downloader((_) async {}),
    shareFile: (_) async {},
    pdfReport: const PdfReport(),
    browserHistory: FakeBrowserHistory(),
  );

  /// The browser history entries the app adds, by address.
  List<String> recordEntries(WidgetTester tester) {
    final entries = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        final args = call.arguments;
        if (call.method == 'routeInformationUpdated' &&
            args is Map &&
            args['replace'] == false) {
          entries.add(args['uri'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
    return entries;
  }

  Future<void> openHome(WidgetTester tester) async {
    auth.restored = PodSession(
      webId: auth.webId,
      provider: PodProvider.unstableUnicorn,
    );
    podSetup.inspection = const PodInspection(
      plainDocumentExists: true,
      keysOnPod: false,
      keyOnDevice: false,
    );
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await session.restore();
    await tester.pumpAndSettle();
  }

  testWidgets('a tab switch at home is a browser history entry', (
    tester,
  ) async {
    final entries = recordEntries(tester);
    await openHome(tester);
    entries.clear();
    await tester.tap(find.byKey(ShellKeys.tab(ShellTab.history)));
    await tester.pumpAndSettle();
    expect(entries, ['/history']);
  });

  testWidgets('"Log it" on a notification opens Log', (tester) async {
    await openHome(tester);
    notifications.open(ReminderAction.log);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      ShellTab.log.index,
    );
  });

  testWidgets('period reminders are set again once the data loads', (
    tester,
  ) async {
    await openHome(tester);
    expect(notifications.cancelled, containsAll(periodReminderIds));
  });

  testWidgets('logging in again starts on Today', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(ShellKeys.tab(ShellTab.history)));
    await tester.pumpAndSettle();
    await session.logout();
    await tester.pumpAndSettle();
    await session.login(
      PodProvider.unstableUnicorn,
      tester.element(find.byType(LoginScreen)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      ShellTab.today.index,
    );
  });

  testWidgets('shows the login screen when nobody is logged in', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a restored session on a fresh pod goes to set-up', (
    tester,
  ) async {
    auth.restored = PodSession(
      webId: auth.webId,
      provider: PodProvider.unstableUnicorn,
    );
    await tester.pumpWidget(app());
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(podSetup.inspections, 1);
  });

  testWidgets(
    'a pod that is ready goes to home with a repository for its mode',
    (tester) async {
      auth.restored = PodSession(
        webId: auth.webId,
        provider: PodProvider.unstableUnicorn,
      );
      podSetup.inspection = const PodInspection(
        plainDocumentExists: true,
        keysOnPod: false,
        keyOnDevice: false,
      );
      await tester.pumpWidget(app());
      await session.restore();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      final repo = tester
          .element(find.byType(HomeScreen))
          .read<HealthRepository>();
      expect(repo.protection, DataProtection.plain);
      expect(repo.isLoaded, isTrue, reason: 'home loads the data on arrival');
    },
  );

  testWidgets('logging out returns to login and forgets the set-up state', (
    tester,
  ) async {
    auth.restored = PodSession(
      webId: auth.webId,
      provider: PodProvider.unstableUnicorn,
    );
    podSetup.inspection = const PodInspection(
      plainDocumentExists: true,
      keysOnPod: false,
      keyOnDevice: false,
    );
    await tester.pumpWidget(app());
    await session.restore();
    await tester.pumpAndSettle();
    await session.logout();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(setup.state, const SetupState.unknown());
  });

  testWidgets('shows a wait indicator while restoring', (tester) async {
    auth.restoreGate = Completer<void>();
    await tester.pumpWidget(app());
    final restoring = session.restore();
    await tester.pump();
    expect(find.byKey(AppKeys.restoring), findsOneWidget);
    auth.restoreGate!.complete();
    await restoring;
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.restoring), findsNothing);
  });
}
