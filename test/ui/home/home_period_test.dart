import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9);
  DateTime june(int d) => DateTime(2026, 6, d);
  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late ShellTabs tabs;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    tabs = ShellTabs();
  });

  Future<void> started(int day) =>
      health.apply((d) => d.withPeriod(PeriodEvent(startDate: june(day))));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
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
        tabs: tabs,
        received: ReceivedShareRepository(
          health,
          FakeShareReader(),
          ownWebId: auth.webId,
        ),
        child: HomeScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('during a period it offers logging today and ending it, '
      'not a new start', (tester) async {
    await started(8);
    await pump(tester);
    expect(find.byKey(HomeKeys.periodInProgress), findsOneWidget);
    expect(find.byKey(HomeKeys.logToday), findsOneWidget);
    expect(find.byKey(HomeKeys.periodEnded), findsOneWidget);
    expect(find.byKey(HomeKeys.logPeriod), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('outside a period it offers a new start', (tester) async {
    await started(1);
    await pump(tester);
    expect(find.byKey(HomeKeys.logPeriod), findsOneWidget);
    expect(find.byKey(HomeKeys.periodInProgress), findsNothing);
    expect(find.byKey(HomeKeys.periodEnded), findsNothing);
  });

  testWidgets('Log today opens Log on today', (tester) async {
    await started(8);
    await pump(tester);
    await tester.tap(find.byKey(HomeKeys.logToday));
    await tester.pumpAndSettle();
    expect(tabs.current, ShellTab.log);
    expect(tabs.logDate, june(10));
  });

  final endCases = [
    (name: 'today', key: HomeKeys.endToday, want: june(10)),
    (name: 'yesterday', key: HomeKeys.endYesterday, want: june(9)),
  ];
  for (final c in endCases) {
    testWidgets('ending it ${c.name} records that day and offers a new '
        'start', (tester) async {
      await started(8);
      await pump(tester);
      await tester.tap(find.byKey(HomeKeys.periodEnded));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
      await tester.tap(find.byKey(c.key));
      await tester.pumpAndSettle();
      final p = health.data.periods.single;
      expect(p.endDate, c.want);
      expect(p.ended, isTrue);
      expect(find.byKey(HomeKeys.logPeriod), findsOneWidget);
    });
  }

  testWidgets('another day comes from a date picker', (tester) async {
    await started(8);
    await pump(tester);
    await tester.tap(find.byKey(HomeKeys.periodEnded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomeKeys.endOther));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('8'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(health.data.periods.single.endDate, june(8));
    expect(health.data.periods.single.ended, isTrue);
  });

  testWidgets('closing the choice changes nothing', (tester) async {
    await started(8);
    await pump(tester);
    await tester.tap(find.byKey(HomeKeys.periodEnded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomeKeys.endCancel));
    await tester.pumpAndSettle();
    expect(health.data.periods.single.ended, isFalse);
    expect(find.byKey(HomeKeys.periodInProgress), findsOneWidget);
  });
}
