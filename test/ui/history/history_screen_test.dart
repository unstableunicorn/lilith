import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/history/history_screen.dart';
import 'package:lilith/ui/period/period_form_screen.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late HealthRepository health;
  late ShellTabs tabs;

  DateTime d(int day) => DateTime(2026, 6, day);

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    tabs = ShellTabs();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        health: health,
        tabs: tabs,
        child: const HistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill() => health.apply(
    (data) => data
        .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
        .withPeriod(PeriodEvent(startDate: d(10)))
        .withReading(TemperatureReading(date: d(9), celsius: 36.3))
        .withReading(TemperatureReading(date: d(10), celsius: 36.6))
        .withDailyLog(
          DailyLog(date: d(10), flow: FlowIntensity.heavy, painLevel: 6),
        ),
  );

  testWidgets('with nothing logged it says so', (tester) async {
    await pump(tester);
    expect(find.byKey(HistoryKeys.empty), findsOneWidget);
    expect(find.byType(TemperatureChart), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('a reading can be added for a past day from a dialog', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.addReading));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(HistoryKeys.addReadingValue), '30');
    await tester.tap(find.byKey(HistoryKeys.addReadingSave));
    await tester.pumpAndSettle();
    expect(find.byKey(HistoryKeys.addReadingProblem), findsOneWidget);
    await tester.enterText(find.byKey(HistoryKeys.addReadingValue), '36,5');
    await tester.tap(find.byKey(HistoryKeys.addReadingSave));
    await tester.pumpAndSettle();
    expect(find.byKey(HistoryKeys.addReadingValue), findsNothing);
    expect(health.data.readings.single.celsius, 36.5);
  });

  testWidgets('a past period can be added, and a cycle opened for editing', (
    tester,
  ) async {
    await fill();
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.addPeriod));
    await tester.pumpAndSettle();
    expect(find.byKey(PeriodFormKeys.save), findsOneWidget);
    expect(find.byKey(PeriodFormKeys.cycleLength), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HistoryKeys.editCycle(d(10))));
    await tester.pumpAndSettle();
    expect(find.byKey(PeriodFormKeys.save), findsOneWidget);
    expect(find.byKey(PeriodFormKeys.cycleLength), findsNothing);
    expect(find.textContaining('10 Jun'), findsWidgets);
  });

  testWidgets('wearable nights get their own chart, accessibly', (
    tester,
  ) async {
    await fill();
    await health.apply(
      (data) => data.withNights([
        for (var i = 1; i <= 8; i++)
          WearableNight(date: d(i), celsius: i < 5 ? -0.1 : 0.3),
      ]),
    );
    await pump(tester);
    expect(find.byKey(HistoryKeys.nightChart), findsOneWidget);
    expect(find.textContaining('Your last 8 nights'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('without wearable nights there is no second chart', (
    tester,
  ) async {
    await fill();
    await pump(tester);
    expect(find.byKey(HistoryKeys.nightChart), findsNothing);
  });

  Future<void> openAll(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(HistoryKeys.expandAll));
    await tester.tap(find.byKey(HistoryKeys.expandAll));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the chart, cycles, days and readings', (tester) async {
    await fill();
    await pump(tester);
    await openAll(tester);
    expect(find.byType(TemperatureChart), findsOneWidget);
    expect(find.byKey(HistoryKeys.cycle(d(10))), findsOneWidget);
    expect(find.text('28 days'), findsOneWidget);
    expect(find.byKey(HistoryKeys.day(d(10))), findsOneWidget);
    expect(find.textContaining('heavy flow, pain 6/10'), findsOneWidget);
    expect(find.byKey(HistoryKeys.reading(d(9))), findsOneWidget);
    expect(find.text('36.3 °C'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('a day opens in the log tab on that date', (tester) async {
    await fill();
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.day(d(10))));
    expect(tabs.current, ShellTab.log);
    expect(tabs.logDate, d(10));
  });

  testWidgets('removing a reading asks first, then removes', (tester) async {
    await fill();
    await pump(tester);
    await openAll(tester);
    await tester.ensureVisible(find.byKey(HistoryKeys.removeReading(d(9))));
    await tester.tap(find.byKey(HistoryKeys.removeReading(d(9))));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await tester.tap(find.byKey(HistoryKeys.cancel));
    await tester.pumpAndSettle();
    expect(health.data.readings, hasLength(2));
    await tester.tap(find.byKey(HistoryKeys.removeReading(d(9))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HistoryKeys.confirm));
    await tester.pumpAndSettle();
    expect(health.data.readings.map((r) => r.date), [d(10)]);
  });

  testWidgets('removing a period start asks first, then removes', (
    tester,
  ) async {
    await fill();
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.removeCycle(d(10))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HistoryKeys.confirm));
    await tester.pumpAndSettle();
    expect(health.data.periods.map((p) => p.startDate), [
      DateTime(2026, 5, 13),
    ]);
  });
}
