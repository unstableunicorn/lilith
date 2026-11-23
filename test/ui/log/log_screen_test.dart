import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/log/log_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10);
  late FakePodService pod;
  late HealthRepository health;

  setUp(() async {
    pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.encrypted);
    await health.load();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        health: health,
        child: LogScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('meets the accessibility guidelines', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(LogKeys.flow(FlowIntensity.light)));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
  });

  testWidgets('shows today, every flow level and every symptom', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(LogKeys.date), findsOneWidget);
    expect(find.text('Wed 10 Jun 2026'), findsOneWidget);
    for (final f in FlowIntensity.values) {
      expect(find.byKey(LogKeys.flow(f)), findsOneWidget);
    }
    for (final s in Symptom.values) {
      expect(find.byKey(LogKeys.symptom(s)), findsOneWidget);
    }
    expect(find.byKey(LogKeys.pain), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(LogKeys.save)).enabled,
      isFalse,
      reason: 'nothing to save yet',
    );
  });

  testWidgets('tapping choices and saving writes the log', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(LogKeys.flow(FlowIntensity.light)));
    await tester.tap(find.byKey(LogKeys.symptom(Symptom.headache)));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(LogKeys.save)).enabled,
      isTrue,
    );
    await tester.tap(find.byKey(LogKeys.save));
    await tester.pumpAndSettle();
    expect(health.data.dailyLogs, [
      DailyLog(
        date: today,
        flow: FlowIntensity.light,
        symptoms: const {Symptom.headache},
      ),
    ]);
    expect(find.byKey(LogKeys.saved), findsOneWidget);
  });

  testWidgets('the pain slider rates and the clear link unrates', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Not rated'), findsOneWidget);
    final slider = find.byKey(LogKeys.pain);
    await tester.drag(slider, const Offset(300, 0));
    await tester.pump();
    expect(find.text('Not rated'), findsNothing);
    await tester.tap(find.byKey(LogKeys.clearPain));
    await tester.pump();
    expect(find.text('Not rated'), findsOneWidget);
  });

  testWidgets('the arrows move between days and show what was logged', (
    tester,
  ) async {
    await health.apply(
      (d) => d.withDailyLog(
        DailyLog(date: DateTime(2026, 6, 9), flow: FlowIntensity.heavy),
      ),
    );
    await pump(tester);
    expect(
      tester.widget<IconButton>(find.byKey(LogKeys.forward)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(LogKeys.back));
    await tester.pumpAndSettle();
    expect(find.text('Tue 9 Jun 2026'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(LogKeys.flow(FlowIntensity.heavy)))
          .selected,
      isTrue,
    );
  });

  testWidgets('a failed save shows the error', (tester) async {
    pod.failWrites = const PodUnavailableException('down');
    await pump(tester);
    await tester.tap(find.byKey(LogKeys.flow(FlowIntensity.spotting)));
    await tester.pump();
    await tester.tap(find.byKey(LogKeys.save));
    await tester.pumpAndSettle();
    expect(find.byKey(LogKeys.error), findsOneWidget);
  });
}
