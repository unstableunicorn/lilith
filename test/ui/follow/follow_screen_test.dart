import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/follow/follow_screen.dart';
import 'package:lilith/ui/received/invite_card.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/received/shared_person_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);
  final today = june(10);

  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeShareReader reader;
  late ReceivedShareRepository received;

  /// Someone who shares their phases, with their next period on [next].
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
    await health.apply((d) => d.withMode(AppMode.partner));
    reader = FakeShareReader();
    received = ReceivedShareRepository(health, reader, ownWebId: auth.webId);
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
        received: received,
        child: FollowScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with nobody sharing it says so and offers to add someone', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(FollowKeys.empty), findsOneWidget);
    expect(find.byKey(FollowKeys.chooser), findsNothing);
    expect(find.byKey(AppMenuKeys.button), findsOneWidget);
    await expectAccessible(tester);
    await tester.tap(find.byKey(FollowKeys.add));
    await tester.pumpAndSettle();
    expect(find.byType(ReceivedScreen), findsOneWidget);
  });

  testWidgets('one sharer: their next period and calendar, no chooser', (
    tester,
  ) async {
    final ada = sharer('ada', next: june(29));
    await health.apply((d) => d.withReceived(ada));
    await pump(tester);
    expect(find.byKey(FollowKeys.empty), findsNothing);
    expect(find.byKey(FollowKeys.chooser), findsNothing);
    expect(find.byKey(SharedPersonKeys.prediction), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.calendar), findsOneWidget);
    expect(reader.reads, 1);
    await expectAccessible(tester);
  });

  testWidgets('several sharers: a chooser switches person and is remembered', (
    tester,
  ) async {
    final ada = sharer('ada', next: june(29));
    final bea = sharer('bea', next: june(20));
    await health.apply((d) => d.withReceived(ada).withReceived(bea));
    await pump(tester);
    expect(find.byKey(FollowKeys.chooser), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(FollowKeys.person(ada.sharerWebId)))
          .selected,
      isTrue,
    );
    expect(find.textContaining('29 Jun'), findsOneWidget);
    await tester.tap(find.byKey(FollowKeys.person(bea.sharerWebId)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(FollowKeys.person(bea.sharerWebId)))
          .selected,
      isTrue,
    );
    expect(find.textContaining('20 Jun'), findsOneWidget);
    expect(find.textContaining('29 Jun'), findsNothing);
    expect(health.data.following, bea.sharerWebId);
    await expectAccessible(tester);
  });

  testWidgets('a pod that cannot be read says so instead of waiting', (
    tester,
  ) async {
    health = HealthRepository(
      FakePodService()..failReads = const PodUnavailableException('timeout'),
      protection: DataProtection.plain,
    );
    await health.load();
    received = ReceivedShareRepository(health, reader, ownWebId: auth.webId);
    await pump(tester);
    expect(find.byKey(FollowKeys.error), findsOneWidget);
    expect(find.byKey(FollowKeys.loading), findsNothing);
    expect(find.byKey(AppMenuKeys.button), findsOneWidget);
  });

  testWidgets('with no error there is no error banner', (tester) async {
    await pump(tester);
    expect(find.byKey(FollowKeys.error), findsNothing);
  });

  testWidgets('an invite the app was opened with is offered here too', (
    tester,
  ) async {
    final settings = FakeSettingsStore()
      ..invite = const ShareInvite(
        sharerWebId: 'https://pod.example.org/ada/profile/card#me',
      );
    received = ReceivedShareRepository(
      health,
      reader,
      ownWebId: auth.webId,
      settings: settings,
    );
    await received.loadInvite();
    await pump(tester);
    expect(find.byKey(InviteKeys.card), findsOneWidget);
    await tester.tap(find.byKey(InviteKeys.accept));
    await tester.pumpAndSettle();
    expect(find.byType(ReceivedScreen), findsOneWidget);
  });
}
