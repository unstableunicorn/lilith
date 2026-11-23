import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/history/history_screen.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/log/log_screen.dart';
import 'package:lilith/ui/pod/pod_screen.dart';
import 'package:lilith/ui/relief/relief_screen.dart';
import 'package:lilith/ui/shell/app_shell.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_pod_setup_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../fakes/fake_share_service.dart';
import '../../harness.dart';

void main() {
  appMenuTests();
  final today = DateTime(2026, 6, 10);
  late SessionRepository session;
  late HealthRepository health;

  setUp(() async {
    session = SessionRepository(FakePodSessionService(), FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.encrypted,
    );
    await health.load();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await session.login(
      PodProvider.unstableUnicorn,
      tester.element(find.byType(SizedBox)),
    );
    await tester.pumpWidget(
      harness(
        session: session,
        health: health,
        setup: SetupRepository(FakePodSetupService()),
        shares: ShareRepository(
          health,
          FakeShareService(),
          protection: DataProtection.encrypted,
        ),
        received: ReceivedShareRepository(
          health,
          FakeShareReader(),
          ownWebId: 'https://pod.example.org/me/profile/card#me',
        ),
        child: AppShell(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selected(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('starts on Today and switches tabs from the bar', (tester) async {
    await pump(tester);
    expect(selected(tester), ShellTab.today.index);
    expect(find.byKey(HomeKeys.logPeriod), findsOneWidget);
    await tester.tap(find.byKey(ShellKeys.tab(ShellTab.log)));
    await tester.pumpAndSettle();
    expect(selected(tester), ShellTab.log.index);
    expect(find.byKey(LogKeys.save), findsOneWidget);
    await tester.tap(find.byKey(ShellKeys.tab(ShellTab.relief)));
    await tester.pumpAndSettle();
    expect(find.byKey(ReliefKeys.seeDoctor), findsOneWidget);
    await tester.tap(find.byKey(ShellKeys.tab(ShellTab.pod)));
    await tester.pumpAndSettle();
    expect(find.byKey(PodKeys.logout), findsOneWidget);
  });

  testWidgets('History has a tab, and a day opens in Log on its date', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(ShellKeys.tab(ShellTab.history)));
    await tester.pumpAndSettle();
    expect(find.byKey(HistoryKeys.empty), findsOneWidget);
    tester
        .element(find.byType(NavigationBar))
        .read<ShellTabs>()
        .openLog(DateTime(2026, 6, 3));
    await tester.pumpAndSettle();
    expect(selected(tester), ShellTab.log.index);
    expect(find.text('Wed 3 Jun 2026'), findsOneWidget);
  });

  testWidgets('a screen can switch the tab too', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(HomeKeys.logDay));
    await tester.pumpAndSettle();
    expect(selected(tester), ShellTab.log.index);
  });
}

void appMenuTests() {
  final today = DateTime(2026, 6, 10);
  late SessionRepository session;
  late HealthRepository health;

  setUp(() async {
    session = SessionRepository(FakePodSessionService(), FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.encrypted,
    );
    await health.load();
  });

  testWidgets('every tab has the menu, and Log out ends the session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await session.login(
      PodProvider.unstableUnicorn,
      tester.element(find.byType(SizedBox)),
    );
    await tester.pumpWidget(
      harness(
        session: session,
        health: health,
        setup: SetupRepository(FakePodSetupService()),
        shares: ShareRepository(
          health,
          FakeShareService(),
          protection: DataProtection.encrypted,
        ),
        received: ReceivedShareRepository(
          health,
          FakeShareReader(),
          ownWebId: 'https://pod.example.org/me/profile/card#me',
        ),
        child: AppShell(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ShellTab.values) {
      await tester.tap(find.byKey(ShellKeys.tab(tab)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(AppMenuKeys.button),
        findsOneWidget,
        reason: 'the ${tab.name} tab has no menu',
      );
    }
    await tester.tap(find.byKey(AppMenuKeys.button));
    await tester.pumpAndSettle();
    expect(find.byKey(AppMenuKeys.item(AppMenuAction.logout)), findsOneWidget);
    await expectAccessible(tester);
    await tester.tap(find.byKey(AppMenuKeys.item(AppMenuAction.logout)));
    await tester.pumpAndSettle();
    expect(session.session, isNull);
  });
}
