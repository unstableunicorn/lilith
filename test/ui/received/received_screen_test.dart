import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/received/shared_person_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../harness.dart';

void main() {
  refreshTests();
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const codec = HealthDocumentCodec();
  final today = DateTime(2026, 6, 10);
  final key = ShareKey.generate(Random(5));
  final theirs = HealthData.empty
      .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
      .withReading(
        TemperatureReading(date: DateTime(2026, 6, 9), celsius: 36.7),
      )
      .withDailyLog(
        DailyLog(date: DateTime(2026, 6, 8), symptoms: const {Symptom.cramps}),
      );

  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeShareReader reader;
  late ReceivedShareRepository received;
  late Uri copyUrl;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    copyUrl = SharePlan.forRecipient(auth.webId).documentUrl(ownerRoot);
    reader.documents[copyUrl] = const ShareCipher().encrypt(
      codec.encode(theirs),
      key,
      Random(1),
    );
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
        child: ReceivedScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillIn(WidgetTester tester, {String code = ''}) async {
    await tester.enterText(find.byKey(ReceivedKeys.label), 'Elric');
    await tester.enterText(find.byKey(ReceivedKeys.webId), owner);
    await tester.enterText(find.byKey(ReceivedKeys.code), code);
    await tester.pumpAndSettle();
  }

  testWidgets('starts with nobody and the button off', (tester) async {
    await pump(tester);
    expect(find.byKey(ReceivedKeys.empty), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(ReceivedKeys.submit)).onPressed,
      isNull,
    );
    await expectAccessible(tester);
  });

  testWidgets('a missing code is explained; with it the share is added', (
    tester,
  ) async {
    await pump(tester);
    await fillIn(tester);
    await tester.tap(find.byKey(ReceivedKeys.submit));
    await tester.pumpAndSettle();
    expect(find.byKey(ReceivedKeys.error), findsOneWidget);
    expect(received.received, isEmpty);
    await expectAccessible(tester);
    await fillIn(tester, code: key.code);
    expect(find.byKey(ReceivedKeys.error), findsNothing);
    await tester.tap(find.byKey(ReceivedKeys.submit));
    await tester.pumpAndSettle();
    final share = received.received.single;
    expect(find.byKey(ReceivedKeys.card(share)), findsOneWidget);
    expect(find.byKey(ReceivedKeys.empty), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('opens the read-only view and removes a share', (tester) async {
    await pump(tester);
    await fillIn(tester, code: key.code);
    await tester.tap(find.byKey(ReceivedKeys.submit));
    await tester.pumpAndSettle();
    final share = received.received.single;
    await tester.tap(find.byKey(ReceivedKeys.open(share)));
    await tester.pumpAndSettle();
    expect(find.byKey(SharedPersonKeys.prediction), findsOneWidget);
    expect(find.byKey(SharedPersonKeys.stats), findsOneWidget);
    expect(
      find.byKey(SharedPersonKeys.cycle(DateTime(2026, 5, 13))),
      findsOneWidget,
    );
    expect(
      find.byKey(SharedPersonKeys.day(DateTime(2026, 6, 8))),
      findsOneWidget,
    );
    await expectAccessible(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ReceivedKeys.remove(share)));
    await tester.pumpAndSettle();
    expect(received.received, isEmpty);
    expect(find.byKey(ReceivedKeys.empty), findsOneWidget);
  });

  group('the read-only view on its own', () {
    Future<void> pumpPerson(WidgetTester tester, {bool settle = true}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await session.login(
        PodProvider.unstableUnicorn,
        tester.element(find.byType(SizedBox)),
      );
      await received.add(
        sharerWebId: owner,
        label: 'Elric',
        code: key.code,
        today: today,
      );
      await tester.pumpWidget(
        harness(
          session: session,
          health: health,
          received: received,
          child: SharedPersonScreen(
            share: received.received.single,
            now: () => today,
          ),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    testWidgets('fetches again on request and shows an ended share', (
      tester,
    ) async {
      await pumpPerson(tester);
      expect(find.byKey(SharedPersonKeys.prediction), findsOneWidget);
      reader.documents.clear();
      await tester.tap(find.byKey(SharedPersonKeys.refresh));
      await tester.pumpAndSettle();
      expect(find.byKey(SharedPersonKeys.failed), findsOneWidget);
      expect(find.text('This share has ended'), findsOneWidget);
      await expectAccessible(tester);
    });

    testWidgets('an unreachable pod shows the detail', (tester) async {
      await pumpPerson(tester);
      reader.failRead = const PodUnavailableException('timeout');
      await tester.tap(find.byKey(SharedPersonKeys.refresh));
      await tester.pumpAndSettle();
      expect(find.byKey(SharedPersonKeys.failed), findsOneWidget);
      expect(find.textContaining('timeout'), findsOneWidget);
    });

    testWidgets('a sharer with nothing logged shows an empty card', (
      tester,
    ) async {
      reader.documents[copyUrl] = const ShareCipher().encrypt(
        codec.encode(HealthData.empty),
        key,
        Random(2),
      );
      await pumpPerson(tester);
      expect(find.byKey(SharedPersonKeys.empty), findsOneWidget);
      await expectAccessible(tester);
    });
  });
}

void refreshTests() {
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const codec = HealthDocumentCodec();
  final today = DateTime(2026, 6, 10);
  final theirs = HealthData.empty.withPeriod(
    PeriodEvent(startDate: DateTime(2026, 5, 13)),
  );

  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeShareReader reader;
  late ReceivedShareRepository received;
  late Uri copyUrl;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    copyUrl = SharePlan.forRecipient(auth.webId).documentUrl(ownerRoot);
    reader.documents[copyUrl] = codec.encode(theirs);
    received = ReceivedShareRepository(health, reader, ownWebId: auth.webId);
    await received.add(
      sharerWebId: owner,
      label: 'Elric',
      code: null,
      today: today,
    );
  });

  Future<void> pumpList(WidgetTester tester) async {
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
        child: ReceivedScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pullDown(WidgetTester tester, Finder from) async {
    // From the text at the top, clear of the fields lower down, and far
    // enough: the indicator arms after a quarter of the (tall) test screen.
    await tester.drag(from, const Offset(0, 900), touchSlopY: 0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the list says each share is up to date, and pulling down re-checks',
    (tester) async {
      await pumpList(tester);
      final share = received.received.single;
      expect(find.byKey(ReceivedKeys.state(share)), findsOneWidget);
      expect(find.text('Up to date'), findsOneWidget);
      reader.documents.clear();
      final before = reader.reads;
      await pullDown(tester, find.textContaining('Someone who shares'));
      expect(reader.reads, greaterThan(before));
      expect(find.textContaining('Ended'), findsOneWidget);
      await expectAccessible(tester);
    },
  );

  testWidgets('a fresh list checks the shares it has not seen', (tester) async {
    received = ReceivedShareRepository(health, reader, ownWebId: auth.webId);
    reader.documents.clear();
    await pumpList(tester);
    expect(find.textContaining('Ended'), findsOneWidget);
  });

  testWidgets('pulling down on the read-only view fetches again', (
    tester,
  ) async {
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
        child: SharedPersonScreen(
          share: received.received.single,
          now: () => today,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(SharedPersonKeys.prediction), findsOneWidget);
    reader.documents.clear();
    await pullDown(tester, find.textContaining('Read-only, from their pod'));
    expect(find.byKey(SharedPersonKeys.failed), findsOneWidget);
    expect(find.text('This share has ended'), findsOneWidget);
  });
}
