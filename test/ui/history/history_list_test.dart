import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/history/history_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 30);
  DateTime may(int d) => DateTime(2026, 5, d);
  DateTime june(int d) => DateTime(2026, 6, d);
  late HealthRepository health;
  late PageSettingsRepository pageSettings;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    await health.apply(
      (data) => data
          .withPeriod(PeriodEvent(startDate: may(1), endDate: may(5)))
          .withPeriod(PeriodEvent(startDate: may(29), endDate: june(2)))
          .withDailyLog(
            DailyLog(
              date: may(2),
              flow: FlowIntensity.heavy,
              symptoms: const {Symptom.cramps},
              painLevel: 6,
            ),
          )
          .withDailyLog(
            DailyLog(
              date: may(15),
              symptoms: const {Symptom.headache},
              painLevel: 3,
            ),
          )
          .withDailyLog(
            DailyLog(date: june(10), symptoms: const {Symptom.bloating}),
          ),
    );
    pageSettings = PageSettingsRepository(FakeSettingsStore());
    await pageSettings.update(
      const PageSettings(showCalendar: false, showTemperatureChart: false),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        health: health,
        pageSettings: pageSettings,
        child: HistoryScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder day(DateTime d) => find.byKey(HistoryKeys.day(d));

  testWidgets('only the newest cycle starts open', (tester) async {
    await pump(tester);
    expect(day(june(10)), findsOneWidget);
    expect(day(may(2)), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('expand all opens every cycle; collapse all closes them', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.expandAll));
    await tester.pumpAndSettle();
    expect(day(may(2)), findsOneWidget);
    expect(day(june(10)), findsOneWidget);
    await tester.tap(find.byKey(HistoryKeys.expandAll));
    await tester.pumpAndSettle();
    expect(day(may(2)), findsNothing);
    expect(day(june(10)), findsNothing);
  });

  testWidgets('a search shows only matching days, opened, with a count', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byKey(HistoryKeys.search), 'headache');
    await tester.pumpAndSettle();
    expect(day(may(15)), findsOneWidget);
    expect(day(june(10)), findsNothing);
    expect(find.byKey(HistoryKeys.cycle(may(29))), findsNothing);
    expect(find.byKey(HistoryKeys.matchCount), findsOneWidget);
    expect(find.byKey(HistoryKeys.expandAll), findsNothing);
    await tester.tap(find.byKey(HistoryKeys.clearFilters));
    await tester.pumpAndSettle();
    expect(day(june(10)), findsOneWidget);
    expect(find.byKey(HistoryKeys.matchCount), findsNothing);
  });

  final chipCases = [
    (name: 'bleeding days', chip: HistoryKeys.filterBleeding, want: may(2)),
    (name: 'pain 5 and up', chip: HistoryKeys.filterPain(5), want: may(2)),
    (
      name: 'a symptom',
      chip: HistoryKeys.filterSymptom(Symptom.headache),
      want: may(15),
    ),
  ];
  for (final c in chipCases) {
    testWidgets('the ${c.name} filter finds its day', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(HistoryKeys.filters));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(c.chip));
      await tester.pumpAndSettle();
      expect(day(c.want), findsOneWidget);
      expect(day(june(10)), findsNothing);
      await expectAccessible(tester);
    });
  }

  testWidgets('a filter with no match says so', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(HistoryKeys.search), 'nausea');
    await tester.pumpAndSettle();
    expect(find.byKey(HistoryKeys.noMatches), findsOneWidget);
  });
}
