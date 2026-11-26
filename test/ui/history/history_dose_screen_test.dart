import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/history/history_screen.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late HealthRepository health;

  DateTime d(int day) => DateTime(2026, 6, day);
  DateTime now() => DateTime(2026, 6, 6, 8);

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
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
        tabs: ShellTabs(),
        child: HistoryScreen(now: now),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A daily pill from 1 June at 09:00; 1 June taken, 2 June late, 3 to 5
  // June missed with nothing logged, 4 June with a headache logged.
  Future<void> withPill() => health.apply(
    (data) => data
        .withPeriod(PeriodEvent(startDate: d(1)))
        .withProfile(
          HealthProfile(
            contraception: Contraception.combinedPill,
            contraceptionSchedule: ContraceptionSchedule(
              form: DoseForm.pill,
              start: d(1),
              daysOn: 21,
              daysOff: 0,
              windowHours: 3,
            ),
          ),
        )
        .withDailyLog(
          DailyLog(date: d(1), contraceptionDoneAt: DateTime(2026, 6, 1, 9)),
        )
        .withDailyLog(
          DailyLog(date: d(2), contraceptionDoneAt: DateTime(2026, 6, 2, 18)),
        )
        .withDailyLog(DailyLog(date: d(4), symptoms: const {Symptom.headache})),
  );

  testWidgets('each due day shows its dose line, missed days too', (
    tester,
  ) async {
    await withPill();
    await pump(tester);
    for (final day in [1, 2, 3, 4, 5]) {
      expect(find.byKey(HistoryKeys.dayDose(d(day))), findsOneWidget);
    }
    expect(find.byKey(HistoryKeys.daySummary(d(3))), findsNothing);
    expect(find.byKey(HistoryKeys.daySummary(d(1))), findsNothing);
    expect(find.byKey(HistoryKeys.daySummary(d(4))), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('the late or missed filter keeps those days', (tester) async {
    await withPill();
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.filters));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(HistoryKeys.filterDose));
    await tester.tap(find.byKey(HistoryKeys.filterDose));
    await tester.pumpAndSettle();
    expect(find.byKey(HistoryKeys.day(d(1))), findsNothing);
    for (final day in [2, 3, 4, 5]) {
      expect(find.byKey(HistoryKeys.day(d(day))), findsOneWidget);
    }
  });

  testWidgets('without doses there is no dose filter or line', (tester) async {
    await health.apply(
      (data) => data
          .withPeriod(PeriodEvent(startDate: d(1)))
          .withDailyLog(DailyLog(date: d(2), flow: FlowIntensity.light)),
    );
    await pump(tester);
    await tester.tap(find.byKey(HistoryKeys.filters));
    await tester.pumpAndSettle();
    expect(find.byKey(HistoryKeys.filterDose), findsNothing);
    expect(find.byKey(HistoryKeys.dayDose(d(2))), findsNothing);
    expect(find.byKey(HistoryKeys.daySummary(d(2))), findsOneWidget);
  });
}
