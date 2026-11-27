import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/mode/mode_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  const home = Key('test.home');

  late FakePodSessionService auth;
  late HealthRepository health;
  late FakeSettingsStore settings;
  late ReceivedShareRepository received;

  setUp(() {
    auth = FakePodSessionService();
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    settings = FakeSettingsStore();
    received = ReceivedShareRepository(
      health,
      FakeShareReader(),
      ownWebId: auth.webId,
      settings: settings,
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(auth, FakeSettingsStore()),
        health: health,
        received: received,
        child: const ModeGate(child: Scaffold(key: home)),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppMode chosen(WidgetTester tester) => tester
      .widget<RadioGroup<AppMode>>(find.byType(RadioGroup<AppMode>))
      .groupValue!;

  testWidgets('a new person is asked how they will use Lilith, accessibly', (
    tester,
  ) async {
    await health.load();
    await pump(tester);
    expect(find.byKey(ModeKeys.screen), findsOneWidget);
    expect(find.byKey(home), findsNothing);
    for (final mode in AppMode.values) {
      expect(find.byKey(ModeKeys.option(mode)), findsOneWidget);
    }
    expect(chosen(tester), AppMode.tracker);
    await expectAccessible(tester);
  });

  testWidgets('choosing and confirming saves it and opens the app', (
    tester,
  ) async {
    await health.load();
    await pump(tester);
    await tester.tap(find.byKey(ModeKeys.option(AppMode.partner)));
    await tester.pumpAndSettle();
    expect(chosen(tester), AppMode.partner);
    expect(health.data.mode, isNull);
    await tester.tap(find.byKey(ModeKeys.confirm));
    await tester.pumpAndSettle();
    expect(health.data.mode, AppMode.partner);
    expect(find.byKey(ModeKeys.screen), findsNothing);
    expect(find.byKey(home), findsOneWidget);
  });

  testWidgets('someone who arrived by an invite is offered following', (
    tester,
  ) async {
    settings.invite = const ShareInvite(
      sharerWebId: 'https://pod.example.org/ada/profile/card#me',
    );
    await received.loadInvite();
    await health.load();
    await pump(tester);
    expect(chosen(tester), AppMode.partner);
  });

  testWidgets('someone with cycle data is not asked', (tester) async {
    await health.load();
    await health.apply(
      (d) => d.withPeriod(PeriodEvent(startDate: DateTime(2026, 6))),
    );
    await pump(tester);
    expect(find.byKey(ModeKeys.screen), findsNothing);
    expect(find.byKey(home), findsOneWidget);
  });

  testWidgets('someone who has chosen is not asked again', (tester) async {
    await health.load();
    await health.apply((d) => d.withMode(AppMode.tracker));
    await pump(tester);
    expect(find.byKey(ModeKeys.screen), findsNothing);
    expect(find.byKey(home), findsOneWidget);
  });

  testWidgets('nothing is asked before the data is in', (tester) async {
    await pump(tester);
    expect(find.byKey(ModeKeys.screen), findsNothing);
    expect(find.byKey(home), findsOneWidget);
  });
}
