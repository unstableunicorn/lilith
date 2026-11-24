import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/wearable/wearable_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/temperature_delta.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../fakes/fake_wearable_source.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9);
  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeWearableSource source;
  late WearableRepository wearable;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    source = FakeWearableSource();
    wearable = WearableRepository(health, source, now: () => today);
  });

  Future<void> pump(WidgetTester tester, {WearableRepository? with_}) async {
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
        wearable: with_,
        child: HomeScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no card without a wearable source', (tester) async {
    source.available = false;
    await pump(tester, with_: wearable);
    expect(find.byKey(HomeKeys.syncWearable), findsNothing);
    await pump(tester);
    expect(find.byKey(HomeKeys.syncWearable), findsNothing);
  });

  testWidgets('syncing adds the nights and says how many, accessibly', (
    tester,
  ) async {
    source.deltas = [
      TemperatureDelta(date: DateTime(2026, 6, 8), deltaCelsius: 0.2),
      TemperatureDelta(date: DateTime(2026, 6, 9), deltaCelsius: 0.3),
    ];
    await pump(tester, with_: wearable);
    expect(find.byKey(HomeKeys.wearableState), findsNothing);
    await tester.tap(find.byKey(HomeKeys.syncWearable));
    await tester.pumpAndSettle();
    expect(find.text('Added 2 nights from your watch.'), findsOneWidget);
    expect(health.data.temperatureDeltas, hasLength(2));
    await expectAccessible(tester);
  });

  testWidgets('a refusal is explained', (tester) async {
    source.permission = false;
    await pump(tester, with_: wearable);
    await tester.tap(find.byKey(HomeKeys.syncWearable));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('not allowed to read your watch'),
      findsOneWidget,
    );
  });
}
