import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
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
  const codec = HealthDocumentCodec();
  final today = DateTime(2026, 6, 10);

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
    reader.documents[SharePlan.forRecipient(auth.webId)
        .documentUrl(ownerRoot)] = codec.encode(
      HealthData.empty.withPeriod(
        PeriodEvent(startDate: DateTime(2026, 5, 13)),
      ),
    );
    received = ReceivedShareRepository(health, reader, ownWebId: auth.webId);
    share = ReceivedShare(sharerWebId: owner, label: 'Elric', addedOn: today);
  });

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  // The fetch indicator animates forever, so this state cannot settle.
  testWidgets('while fetching it shows the wait indicator, accessibly', (
    tester,
  ) async {
    reader.readGate = Completer<void>();
    await pump(tester, settle: false);
    await tester.pump();
    expect(find.byKey(SharedPersonKeys.loading), findsOneWidget);
    await expectAccessible(tester, variants: false);
    reader.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(SharedPersonKeys.prediction), findsOneWidget);
  });

  testWidgets('once fetched it shows the prediction, accessibly', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(SharedPersonKeys.prediction), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('their shared doses show as lines, missed days too', (
    tester,
  ) async {
    DateTime june(int d, [int h = 0]) => DateTime(2026, 6, d, h);
    reader.documents[SharePlan.forRecipient(auth.webId)
        .documentUrl(ownerRoot)] = codec.encode(
      HealthData.empty
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
          .withProfile(
            HealthProfile(
              contraception: Contraception.combinedPill,
              contraceptionSchedule: ContraceptionSchedule(
                form: DoseForm.pill,
                start: june(8),
                daysOn: 21,
                daysOff: 7,
                windowHours: 3,
              ),
            ),
          )
          .withDailyLog(
            DailyLog(
              date: june(8),
              contraceptionDoneAt: june(8, 9),
              symptoms: const {Symptom.cramps},
            ),
          ),
    );
    await pump(tester);
    expect(find.byKey(SharedPersonKeys.dayDose(june(8))), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.daySummary(june(8))), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.dayDose(june(9))), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.daySummary(june(9))), findsNothing);
    await expectAccessible(tester);
  });
}
