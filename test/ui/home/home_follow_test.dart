import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';
import 'package:lilith/ui/follow/follow_screen.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/received/shared_person_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

/// Today for someone who tracks their own cycle and also follows someone.
void main() {
  DateTime june(int d) => DateTime(2026, 6, d);
  final today = june(10);

  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeShareReader reader;
  late ReceivedShareRepository received;

  ReceivedShare sharer(String name, {required DateTime next}) {
    final webId = 'https://pod.example.org/$name/profile/card#me';
    final root = Uri.parse('https://pod.example.org/$name/');
    reader.roots[webId] = root;
    reader.documents[SharePlan.forRecipient(auth.webId)
        .documentUrl(root)] = jsonEncode(
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1), endDate: june(4))],
        nextPeriod: next,
      ).toJson(),
    );
    return ReceivedShare(sharerWebId: webId, label: name, addedOn: today);
  }

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader();
    received = ReceivedShareRepository(health, reader, ownWebId: auth.webId);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
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
        received: received,
        child: HomeScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a tracker sees no followed person, even with a share', (
    tester,
  ) async {
    final ada = sharer('ada', next: june(29));
    await health.apply((d) => d.withReceived(ada));
    await pump(tester);
    expect(find.byKey(FollowKeys.card), findsNothing);
    expect(reader.reads, 0);
  });

  testWidgets('"both" shows the followed person above their own Today', (
    tester,
  ) async {
    final ada = sharer('ada', next: june(29));
    await health.apply((d) => d.withMode(AppMode.both).withReceived(ada));
    await pump(tester);
    expect(find.byKey(FollowKeys.card), findsOneWidget);
    expect(find.byKey(FollowKeys.chooser), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(FollowKeys.card),
        matching: find.textContaining('29 Jun'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(HomeKeys.logPeriod), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(FollowKeys.card)).dy,
      lessThan(tester.getTopLeft(find.byKey(HomeKeys.logPeriod)).dy),
    );
    await expectAccessible(tester);
  });

  testWidgets('the card opens everything they share', (tester) async {
    final ada = sharer('ada', next: june(29));
    await health.apply((d) => d.withMode(AppMode.both).withReceived(ada));
    await pump(tester);
    await tester.tap(find.byKey(FollowKeys.open));
    await tester.pumpAndSettle();
    expect(find.byType(SharedPersonScreen), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.calendar), findsOneWidget);
  });

  testWidgets('with several sharers the card has the chooser', (tester) async {
    final ada = sharer('ada', next: june(29));
    final bea = sharer('bea', next: june(20));
    await health.apply(
      (d) => d.withMode(AppMode.both).withReceived(ada).withReceived(bea),
    );
    await pump(tester);
    expect(find.byKey(FollowKeys.chooser), findsOneWidget);
    await tester.tap(find.byKey(FollowKeys.person(bea.sharerWebId)));
    await tester.pumpAndSettle();
    expect(health.data.following, bea.sharerWebId);
    expect(
      find.descendant(
        of: find.byKey(FollowKeys.card),
        matching: find.textContaining('20 Jun'),
      ),
      findsOneWidget,
    );
    await expectAccessible(tester);
  });

  testWidgets('with nobody sharing yet the card offers to add someone', (
    tester,
  ) async {
    await health.apply((d) => d.withMode(AppMode.both));
    await pump(tester);
    expect(find.byKey(FollowKeys.card), findsOneWidget);
    expect(find.byKey(FollowKeys.open), findsNothing);
    await tester.tap(find.byKey(FollowKeys.add));
    await tester.pumpAndSettle();
    expect(find.byType(ReceivedScreen), findsOneWidget);
  });

  testWidgets('a share that has ended says so on the card', (tester) async {
    final ada = sharer('ada', next: june(29));
    reader.documents.clear();
    await health.apply((d) => d.withMode(AppMode.both).withReceived(ada));
    await pump(tester);
    expect(find.byKey(FollowKeys.cardProblem), findsOneWidget);
    expect(find.byKey(FollowKeys.open), findsOneWidget);
  });
}
