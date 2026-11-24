import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9);
  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late PageSettingsRepository pageSettings;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
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
    pageSettings = PageSettingsRepository(FakeSettingsStore());
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
        received: ReceivedShareRepository(
          health,
          FakeShareReader(),
          ownWebId: auth.webId,
        ),
        pageSettings: pageSettings,
        child: HomeScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('by default the fact and the forecast show', (tester) async {
    await pump(tester);
    expect(find.byKey(HomeKeys.fact), findsOneWidget);
    expect(find.byKey(HomeKeys.forecast), findsOneWidget);
  });

  testWidgets('page settings hide the fact and the forecast', (tester) async {
    await pageSettings.update(
      const PageSettings(showFact: false, showForecast: false),
    );
    await pump(tester);
    expect(find.byKey(HomeKeys.fact), findsNothing);
    expect(find.byKey(HomeKeys.forecast), findsNothing);
    expect(find.byKey(HomeKeys.prediction), findsOneWidget);
  });
}
