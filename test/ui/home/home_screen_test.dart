import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/learn/learn_screen.dart';
import 'package:lilith/ui/learn/learn_view_model.dart';
import 'package:lilith/ui/period/period_form_screen.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  inviteCardTests();
  final today = DateTime(2026, 6, 10);
  late FakePodSessionService auth;
  late SessionRepository session;
  late FakePodService pod;
  late HealthRepository health;
  late ShellTabs tabs;
  late RecordingUrlOpener urls;
  late FakeSettingsStore settings;
  late ReceivedShareRepository received;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.encrypted);
    tabs = ShellTabs();
    urls = RecordingUrlOpener();
    settings = FakeSettingsStore();
    received = ReceivedShareRepository(
      health,
      FakeShareReader(),
      ownWebId: auth.webId,
      settings: settings,
    );
  });

  // The wait indicator animates forever, so a test that expects it cannot
  // settle.
  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
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
        received: received,
        tabs: tabs,
        openUrl: urls.call,
        child: HomeScreen(now: () => today),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('before the data has loaded it shows a wait indicator', (
    tester,
  ) async {
    await pump(tester, settle: false);
    expect(find.byKey(HomeKeys.loading), findsOneWidget);
    expect(find.byKey(HomeKeys.logPeriod), findsNothing);
  });

  group('once loaded', () {
    setUp(() => health.load());

    testWidgets('shows the fact of the day and opens Learn', (tester) async {
      await pump(tester);
      expect(find.byKey(HomeKeys.fact), findsOneWidget);
      expect(find.text(factOfTheDay(today).text), findsOneWidget);
      await tester.tap(find.byKey(HomeKeys.factSource));
      expect(urls.opened, [Uri.parse(factOfTheDay(today).source.url)]);
      await tester.tap(find.byKey(HomeKeys.learn));
      await tester.pumpAndSettle();
      expect(find.byKey(LearnKeys.question), findsOneWidget);
    });

    testWidgets('a forecast card appears once past cycles allow one', (
      tester,
    ) async {
      await health.apply((d) {
        var next = d
            .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 15)))
            .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
            .withPeriod(PeriodEvent(startDate: today));
        for (final start in [DateTime(2026, 4, 15), DateTime(2026, 5, 13)]) {
          for (var i = 0; i < 3; i++) {
            next = next.withDailyLog(
              DailyLog(
                date: start.add(Duration(days: i)),
                symptoms: const {Symptom.cramps, Symptom.fatigue},
                painLevel: 5,
              ),
            );
          }
        }
        return next;
      });
      await pump(tester);
      expect(find.byKey(HomeKeys.forecast), findsOneWidget);
      expect(find.text('Cramps 100%'), findsOneWidget);
      expect(find.text('Fatigue 100%'), findsOneWidget);
      await expectAccessible(tester);
    });

    testWidgets("summarises today's log and opens the log screen", (
      tester,
    ) async {
      await health.apply(
        (d) => d.withDailyLog(
          DailyLog(
            date: today,
            flow: FlowIntensity.medium,
            symptoms: const {Symptom.cramps, Symptom.fatigue},
            painLevel: 4,
          ),
        ),
      );
      await pump(tester);
      expect(
        find.text('Today: medium flow, cramps, fatigue, pain 4/10'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(HomeKeys.logDay));
      expect(tabs.current, ShellTab.log);
    });

    testWidgets('with nothing logged it offers three ways to begin', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(HomeKeys.startedToday), findsOneWidget);
      expect(find.byKey(HomeKeys.midPeriod), findsOneWidget);
      expect(find.byKey(HomeKeys.notBleeding), findsOneWidget);
      await tester.tap(find.byKey(HomeKeys.notBleeding));
      await tester.pumpAndSettle();
      expect(find.byKey(PeriodFormKeys.save), findsOneWidget);
      expect(find.byKey(PeriodFormKeys.lastDay), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeKeys.midPeriod));
      await tester.pumpAndSettle();
      expect(find.byKey(PeriodFormKeys.lastDay), findsNothing);
    });

    testWidgets('with nothing logged it invites the first period start', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(HomeKeys.loading), findsNothing);
      expect(find.byKey(HomeKeys.noData), findsOneWidget);
      expect(find.byKey(HomeKeys.prediction), findsNothing);
      expect(find.byKey(HomeKeys.logPeriod), findsOneWidget);
    });

    testWidgets('logging a period start shows the prediction', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(HomeKeys.logPeriod));
      await tester.pumpAndSettle();
      expect(health.data.periods.single.startDate, today);
      expect(find.byKey(HomeKeys.prediction), findsOneWidget);
      expect(find.byKey(HomeKeys.daysUntil), findsOneWidget);
      expect(find.byKey(HomeKeys.noData), findsNothing);
    });

    testWidgets('the temperature can be for an earlier day', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(HomeKeys.readingDay));
      await tester.pumpAndSettle();
      expect(find.text('Which day is the temperature for?'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text("Today's temperature (°C)"), findsOneWidget);
    });

    testWidgets('a temperature is logged from the field', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(HomeKeys.temperature), '36.5');
      await tester.tap(find.byKey(HomeKeys.logTemperature));
      await tester.pumpAndSettle();
      expect(health.data.readings.single.celsius, 36.5);
      expect(find.byKey(HomeKeys.todaysReading), findsOneWidget);
    });

    testWidgets('an implausible temperature is refused and shown as such', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byKey(HomeKeys.temperature), '63');
      await tester.tap(find.byKey(HomeKeys.logTemperature));
      await tester.pumpAndSettle();
      expect(health.data.readings, isEmpty);
      expect(find.byKey(HomeKeys.temperatureProblem), findsOneWidget);
    });

    testWidgets('a failed save shows an error that can be dismissed', (
      tester,
    ) async {
      pod.failWrites = const PodAccessException('403');
      await pump(tester);
      await tester.tap(find.byKey(HomeKeys.logPeriod));
      await tester.pumpAndSettle();
      expect(find.byKey(HomeKeys.error), findsOneWidget);
      await tester.tap(find.byKey(HomeKeys.dismissError));
      await tester.pumpAndSettle();
      expect(find.byKey(HomeKeys.error), findsNothing);
    });

    testWidgets('the last period start and the latest reading are shown', (
      tester,
    ) async {
      await health.apply(
        (d) => d.withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 27))),
      );
      await pump(tester);
      expect(find.byKey(HomeKeys.lastPeriod), findsOneWidget);
      expect(find.byKey(HomeKeys.prediction), findsOneWidget);
    });

    testWidgets('the cycle day and phase show under the last period start', (
      tester,
    ) async {
      await health.apply(
        (d) => d.withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 27))),
      );
      await pump(tester);
      expect(
        find.descendant(
          of: find.byKey(HomeKeys.prediction),
          matching: find.byKey(HomeKeys.cycleStatus),
        ),
        findsOneWidget,
      );
      await expectAccessible(tester);
    });

    testWidgets('the average period length shows once an end is known', (
      tester,
    ) async {
      await health.apply(
        (d) => d.withPeriod(
          PeriodEvent(
            startDate: DateTime(2026, 4, 1),
            endDate: DateTime(2026, 4, 5),
          ),
        ),
      );
      await pump(tester);
      expect(find.byKey(HomeKeys.avgPeriod), findsOneWidget);
      expect(find.text('5.0 days'), findsOneWidget);
      await expectAccessible(tester);
    });
  });

  testWidgets('meets the accessibility guidelines', (tester) async {
    await health.apply(
      (d) => d.withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 27))),
    );
    await health.load();
    await pump(tester);
    await expectAccessible(tester);
  });
}

void inviteCardTests() {
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  const invite = ShareInvite(sharerWebId: owner, code: 'ABCD-EFGH-JKMN-PQRS');
  final today = DateTime(2026, 6, 10);

  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeSettingsStore settings;
  late ReceivedShareRepository received;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    settings = FakeSettingsStore()..invite = invite;
    received = ReceivedShareRepository(
      health,
      FakeShareReader(),
      ownWebId: auth.webId,
      settings: settings,
    );
    await received.loadInvite();
  });

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
        received: received,
        child: HomeScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an invite shows on Today and can be put off', (tester) async {
    await pump(tester);
    expect(find.byKey(HomeKeys.invite), findsOneWidget);
    expect(find.text(owner), findsOneWidget);
    await expectAccessible(tester);
    await tester.tap(find.byKey(HomeKeys.dismissInvite));
    await tester.pumpAndSettle();
    expect(find.byKey(HomeKeys.invite), findsNothing);
    expect(settings.invite, isNull);
  });

  testWidgets('accepting opens the add form filled in from the invite', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(HomeKeys.acceptInvite));
    await tester.pumpAndSettle();
    expect(find.byKey(ReceivedKeys.submit), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(ReceivedKeys.webId)).controller!.text,
      owner,
    );
    expect(
      tester.widget<TextField>(find.byKey(ReceivedKeys.code)).controller!.text,
      invite.code,
    );
  });
}
