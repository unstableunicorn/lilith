import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/log/log_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10);
  late FakePodSessionService auth;
  late SessionRepository session;
  late FakePodService pod;
  late HealthRepository health;
  late RecordingUrlOpener urls;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.encrypted);
    urls = RecordingUrlOpener();
  });

  // The wait indicator animates forever, so a test that expects it cannot settle.
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

    testWidgets('summarises today\'s log and opens the log screen', (
      tester,
    ) async {
      await health.apply(
        (d) => d.withDailyLog(
          DailyLog(
            date: today,
            flow: FlowIntensity.medium,
            symptoms: {Symptom.cramps, Symptom.fatigue},
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
      await tester.pumpAndSettle();
      expect(find.byKey(LogKeys.save), findsOneWidget);
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
  });

  testWidgets('manage-your-data and logout still work', (tester) async {
    await health.load();
    await pump(tester);
    await tester.tap(find.byKey(HomeKeys.manage));
    await tester.pump();
    expect(urls.opened, [PodProvider.unstableUnicorn.manageUrl]);
    await tester.tap(find.byKey(HomeKeys.logout));
    await tester.pumpAndSettle();
    expect(session.session, isNull);
  });
}
