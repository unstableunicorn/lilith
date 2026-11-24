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
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 17, 9);
  DateTime june(int d) => DateTime(2026, 6, d);
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
    await health.apply(
      (d) => d.withPeriod(PeriodEvent(startDate: june(1), endDate: june(5))),
    );
    pageSettings = PageSettingsRepository(FakeSettingsStore());
  });

  Future<void> positiveTest() => health.apply(
    (d) => d.withDailyLog(
      DailyLog(date: june(12), ovulationTest: OvulationTest.positive),
    ),
  );

  Future<void> pump(WidgetTester tester, PageSettings settings) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pageSettings.update(settings);
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

  final cases = [
    (
      name: 'both switches off: no window',
      settings: const PageSettings(),
      card: false,
      conceive: false,
      information: false,
    ),
    (
      name: 'show fertile window: with the contraception line',
      settings: const PageSettings(showFertileWindow: true),
      card: true,
      conceive: false,
      information: true,
    ),
    (
      name: 'trying to conceive: without the contraception line',
      settings: const PageSettings(tryingToConceive: true),
      card: true,
      conceive: true,
      information: false,
    ),
  ];
  for (final c in cases) {
    testWidgets('a positive test, ${c.name}', (tester) async {
      await positiveTest();
      await pump(tester, c.settings);
      Matcher shows(bool yes) => yes ? findsOneWidget : findsNothing;
      expect(find.byKey(HomeKeys.fertileWindow), shows(c.card));
      expect(find.byKey(HomeKeys.disclaimerConceive), shows(c.conceive));
      expect(find.byKey(HomeKeys.disclaimerInformation), shows(c.information));
      await expectAccessible(tester);
    });
  }

  testWidgets('with nothing to support it, no window shows even when on', (
    tester,
  ) async {
    await pump(tester, const PageSettings(showFertileWindow: true));
    expect(find.byKey(HomeKeys.fertileWindow), findsNothing);
  });

  testWidgets('an ovulation estimate says it is an estimate, switches off', (
    tester,
  ) async {
    await health.apply(
      (d) => d.withReadings([
        for (var i = 1; i <= 16; i++)
          TemperatureReading(date: june(i), celsius: i <= 8 ? 36.3 : 36.65),
      ]),
    );
    await pump(tester, const PageSettings());
    expect(find.byKey(HomeKeys.estimateNote), findsOneWidget);
    expect(find.byKey(HomeKeys.fertileWindow), findsNothing);
  });
}
