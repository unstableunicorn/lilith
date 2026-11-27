import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';
import 'package:lilith/ui/received/shared_person_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  DateTime june(int d) => DateTime(2026, 6, d);
  final today = june(10);

  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeShareReader reader;
  late ReceivedShareRepository received;
  late ReceivedShare share;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    received = ReceivedShareRepository(health, reader, ownWebId: auth.webId);
    share = ReceivedShare(sharerWebId: owner, label: 'Elric', addedOn: today);
  });

  Future<void> pump(WidgetTester tester, SharedPhases phases) async {
    reader.documents[SharePlan.forRecipient(auth.webId)
        .documentUrl(ownerRoot)] = jsonEncode(
      phases.toJson(),
    );
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
        child: SharedPersonScreen(share: share, now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the next period and the calendar only, accessibly', (
    tester,
  ) async {
    await pump(
      tester,
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1), endDate: june(4))],
        nextPeriod: june(29),
        ovulation: june(14),
        fertileWindow: FertileWindow(
          start: june(10),
          end: june(15),
          basis: FertileWindowBasis.shift,
        ),
        fertileMode: FertileWindowMode.information,
      ),
    );
    expect(find.byKey(SharedPersonKeys.prediction), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.calendar), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.calendarDay(june(14))), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.updated), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.disclaimer), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.stats), findsNothing);
    expect(find.byKey(SharedPersonKeys.day(june(1))), findsNothing);
    expect(find.byKey(SharedPersonKeys.cycle(june(1))), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('the calendar moves between months', (tester) async {
    await pump(
      tester,
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1), endDate: june(4))],
      ),
    );
    expect(find.byKey(SharedPersonKeys.disclaimer), findsNothing);
    expect(find.byKey(SharedPersonKeys.calendarNext), findsOneWidget);
    await tester.tap(find.byKey(SharedPersonKeys.calendarNext));
    await tester.pumpAndSettle();
    expect(
      find.byKey(SharedPersonKeys.calendarDay(DateTime(2026, 7, 31))),
      findsOneWidget,
    );
    await tester.tap(find.byKey(SharedPersonKeys.calendarPrev));
    await tester.tap(find.byKey(SharedPersonKeys.calendarPrev));
    await tester.pumpAndSettle();
    expect(
      find.byKey(SharedPersonKeys.calendarDay(DateTime(2026, 5, 31))),
      findsOneWidget,
    );
  });

  testWidgets('with no period shared yet it says so', (tester) async {
    await pump(tester, SharedPhases(updatedOn: june(8)));
    expect(find.byKey(SharedPersonKeys.empty), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.calendar), findsNothing);
  });
}
