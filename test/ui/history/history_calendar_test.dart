import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/history/history_screen.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 20);
  late HealthRepository health;
  late ShellTabs tabs;
  late FakeSettingsStore store;
  late PageSettingsRepository pageSettings;

  DateTime d(int day) => DateTime(2026, 6, day);

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    await health.apply(
      (data) => data
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
          .withPeriod(PeriodEvent(startDate: d(10), endDate: d(13)))
          .withReading(TemperatureReading(date: d(15), celsius: 36.6))
          .withDailyLog(DailyLog(date: d(16), painLevel: 3)),
    );
    tabs = ShellTabs();
    store = FakeSettingsStore();
    pageSettings = PageSettingsRepository(store);
    await pageSettings.load();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(FakePodSessionService(), store),
        health: health,
        tabs: tabs,
        pageSettings: pageSettings,
        child: HistoryScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows this month with its marks, accessibly', (tester) async {
    await pump(tester);
    expect(find.byKey(HistoryKeys.calendar), findsOneWidget);
    expect(find.text('June 2026'), findsOneWidget);
    final period = tester.widget<CalendarDayCell>(
      find.byKey(HistoryKeys.calendarDay(d(11))),
    );
    expect(period.day.inPeriod, isTrue);
    final logged = tester.widget<CalendarDayCell>(
      find.byKey(HistoryKeys.calendarDay(d(16))),
    );
    expect(logged.day.logged, isTrue);
    expect(logged.day.inPeriod, isFalse);
    await expectAccessible(tester);
  });

  testWidgets('moves a month back and forward', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.calendarPrev));
    await tester.pumpAndSettle();
    expect(find.text('May 2026'), findsOneWidget);
    expect(
      tester
          .widget<CalendarDayCell>(
            find.byKey(HistoryKeys.calendarDay(DateTime(2026, 5, 13))),
          )
          .day
          .inPeriod,
      isTrue,
    );
    await tester.tap(find.byKey(HistoryKeys.calendarNext));
    await tester.pumpAndSettle();
    expect(find.text('June 2026'), findsOneWidget);
  });

  testWidgets('tapping a day opens it in Log', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.calendarDay(d(16))));
    await tester.pumpAndSettle();
    expect(tabs.current, ShellTab.log);
    expect(tabs.logDate, d(16));
  });

  testWidgets('page settings hide the calendar and the chart', (tester) async {
    await pageSettings.update(
      const PageSettings(showCalendar: false, showTemperatureChart: false),
    );
    await pump(tester);
    expect(find.byKey(HistoryKeys.calendar), findsNothing);
    expect(find.byType(TemperatureChart), findsNothing);
    expect(find.byKey(HistoryKeys.cycle(d(10))), findsOneWidget);
  });
}
