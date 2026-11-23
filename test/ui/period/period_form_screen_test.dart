import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/period/period_form_screen.dart';
import 'package:lilith/ui/period/period_form_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10);
  late HealthRepository health;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
  });

  Future<void> pump(
    WidgetTester tester,
    PeriodFormMode mode, {
    PeriodEvent? editing,
  }) async {
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
        child: PeriodFormScreen(mode: mode, editing: editing, now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the last period: pick days, flow, lengths, then save', (
    tester,
  ) async {
    await pump(tester, PeriodFormMode.pastPeriod);
    expect(find.byKey(PeriodFormKeys.lastDay), findsOneWidget);
    expect(find.byKey(PeriodFormKeys.cycleLength), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(PeriodFormKeys.save)).onPressed,
      isNull,
    );
    await expectAccessible(tester);
    await tester.tap(find.byKey(PeriodFormKeys.firstDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PeriodFormKeys.flow(FlowIntensity.medium)));
    await tester.enterText(find.byKey(PeriodFormKeys.cycleLength), '28');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PeriodFormKeys.save));
    await tester.pumpAndSettle();
    expect(health.data.periods.single.startDate, today);
    expect(health.data.periods.single.flow, FlowIntensity.medium);
    expect(health.data.profile.usualCycleLength, 28);
  });

  testWidgets('mid-period asks no last day', (tester) async {
    await pump(tester, PeriodFormMode.midPeriod);
    expect(find.byKey(PeriodFormKeys.lastDay), findsNothing);
    expect(find.byKey(PeriodFormKeys.contraception), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('a bad cycle length is pointed out', (tester) async {
    await pump(tester, PeriodFormMode.pastPeriod);
    await tester.enterText(find.byKey(PeriodFormKeys.cycleLength), '5');
    await tester.pumpAndSettle();
    expect(
      find.byKey(PeriodFormKeys.problem(PeriodFormProblem.cycleLength)),
      findsOneWidget,
    );
  });

  testWidgets('editing starts from the period and asks nothing about you', (
    tester,
  ) async {
    final period = PeriodEvent(
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 4),
    );
    await health.apply((d) => d.withPeriod(period));
    await pump(tester, PeriodFormMode.edit, editing: period);
    expect(find.byKey(PeriodFormKeys.cycleLength), findsNothing);
    expect(find.byKey(PeriodFormKeys.clearLastDay), findsOneWidget);
    await tester.tap(find.byKey(PeriodFormKeys.clearLastDay));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PeriodFormKeys.save));
    await tester.pumpAndSettle();
    expect(health.data.periods.single.isOpen, isTrue);
    await expectAccessible(tester);
  });
}
