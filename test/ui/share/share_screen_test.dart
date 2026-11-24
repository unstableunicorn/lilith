import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/share/share_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_service.dart';
import '../../harness.dart';

void main() {
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  final may1 = DateTime(2026, 5, 1, 10);

  late FakePodSessionService auth;
  late SessionRepository session;
  late HealthRepository health;
  late FakeShareService pod;
  late ShareRepository shares;

  Future<void> setUpWith(DataProtection protection) async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    health = HealthRepository(FakePodService(), protection: protection);
    await health.load();
    pod = FakeShareService();
    shares = ShareRepository(
      health,
      pod,
      protection: protection,
      random: Random(1),
    );
  }

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
        shares: shares,
        child: ShareScreen(now: () => may1),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillIn(WidgetTester tester, {String webId = wife}) async {
    await tester.enterText(find.byKey(ShareKeys.label), 'Alex');
    await tester.enterText(find.byKey(ShareKeys.webId), webId);
    await tester.pumpAndSettle();
  }

  group('encrypted data', () {
    setUp(() => setUpWith(DataProtection.encrypted));

    testWidgets('starts with nobody and the button off', (tester) async {
      await pump(tester);
      expect(find.byKey(ShareKeys.empty), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(ShareKeys.submit)).onPressed,
        isNull,
      );
      await expectAccessible(tester);
    });

    testWidgets('notes are off by default and go with the share when on', (
      tester,
    ) async {
      await pump(tester);
      await fillIn(tester);
      final notes = find.byKey(ShareKeys.includeNotes);
      await tester.ensureVisible(notes);
      expect(tester.widget<SwitchListTile>(notes).value, isFalse);
      await tester.tap(notes);
      await tester.pumpAndSettle();
      await expectAccessible(tester);
      await tester.ensureVisible(find.byKey(ShareKeys.submit));
      await tester.tap(find.byKey(ShareKeys.submit));
      await tester.pumpAndSettle();
      expect(shares.shares.single.includeNotes, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('points out a bad WebID and accepts a good one', (
      tester,
    ) async {
      await pump(tester);
      await fillIn(tester, webId: 'alex');
      expect(find.byKey(ShareKeys.webIdProblem), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(ShareKeys.submit)).onPressed,
        isNull,
      );
      await fillIn(tester);
      expect(find.byKey(ShareKeys.webIdProblem), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(ShareKeys.submit)).onPressed,
        isNotNull,
      );
    });

    testWidgets('shares, shows the code once, copies it, lists the share', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pump(tester);
      await fillIn(tester);
      await tester.tap(
        find.byKey(ShareKeys.duration(ShareDuration.ninetyDays)),
      );
      await tester.tap(find.byKey(ShareKeys.submit));
      await tester.pumpAndSettle();
      final share = shares.shares.single;
      expect(find.byKey(ShareKeys.created), findsOneWidget);
      expect(find.byKey(ShareKeys.createdCode), findsOneWidget);
      expect(find.byKey(ShareKeys.createdQr), findsOneWidget);
      expect(find.byKey(ShareKeys.card(share)), findsOneWidget);
      expect(find.byKey(ShareKeys.end(share)), findsOneWidget);
      expect(find.byKey(ShareKeys.empty), findsNothing);
      expect(share.expiresOn, DateTime(2026, 7, 30));
      await expectAccessible(tester);
      await tester.tap(find.byKey(ShareKeys.copyCode));
      await tester.pumpAndSettle();
      expect(copied, share.code);
      await tester.tap(find.byKey(ShareKeys.dismissCreated));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.created), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('shows a code again from the list and ends a share', (
      tester,
    ) async {
      await pump(tester);
      await fillIn(tester);
      await tester.tap(find.byKey(ShareKeys.submit));
      await tester.pumpAndSettle();
      final share = shares.shares.single;
      expect(find.byKey(ShareKeys.code(share)), findsNothing);
      expect(find.byKey(ShareKeys.qr(share)), findsNothing);
      await tester.tap(find.byKey(ShareKeys.showCode(share)));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.code(share)), findsOneWidget);
      expect(find.byKey(ShareKeys.qr(share)), findsOneWidget);
      await expectAccessible(tester);
      await tester.tap(find.byKey(ShareKeys.revoke(share)));
      await tester.pumpAndSettle();
      expect(shares.shares, isEmpty);
      expect(pod.folders, isEmpty);
      expect(find.byKey(ShareKeys.empty), findsOneWidget);
    });

    testWidgets('a refused share shows the error with its detail', (
      tester,
    ) async {
      pod.failOpen = const PodUnavailableException('socket closed');
      await pump(tester);
      await fillIn(tester);
      await tester.tap(find.byKey(ShareKeys.submit));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.error), findsOneWidget);
      expect(find.text('socket closed'), findsOneWidget);
      expect(find.byKey(ShareKeys.created), findsNothing);
      await expectAccessible(tester);
      await tester.tap(find.byKey(ShareKeys.dismissError));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.error), findsNothing);
    });
  });

  group('plain data', () {
    setUp(() => setUpWith(DataProtection.plain));

    testWidgets('has no code to show', (tester) async {
      await pump(tester);
      await fillIn(tester);
      await tester.tap(find.byKey(ShareKeys.submit));
      await tester.pumpAndSettle();
      final share = shares.shares.single;
      expect(find.byKey(ShareKeys.created), findsOneWidget);
      expect(find.byKey(ShareKeys.createdCode), findsNothing);
      expect(find.byKey(ShareKeys.createdQr), findsOneWidget);
      await tester.tap(find.byKey(ShareKeys.dismissCreated));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShareKeys.showCode(share)));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.code(share)), findsNothing);
      expect(find.byKey(ShareKeys.qr(share)), findsOneWidget);
      await expectAccessible(tester);
    });
  });

  group('a report share', () {
    setUp(() => setUpWith(DataProtection.encrypted));

    testWidgets('asks how far back, then shows the folder link to copy', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pump(tester);
      expect(find.byKey(ShareKeys.range(ExportRange.year)), findsNothing);
      await tester.tap(find.byKey(ShareKeys.content(ShareContent.report)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShareKeys.range(ExportRange.year)));
      await fillIn(tester);
      await tester.tap(find.byKey(ShareKeys.submit));
      await tester.pumpAndSettle();
      final share = shares.shares.single;
      expect(share.isReport, isTrue);
      expect(share.range, ExportRange.year);
      expect(find.byKey(ShareKeys.createdLink), findsOneWidget);
      expect(find.byKey(ShareKeys.createdCode), findsNothing);
      expect(find.byKey(ShareKeys.createdQr), findsNothing);
      expect(pod.files['shares/${share.id}']!.keys, {
        'report.pdf',
        'cycle_data.csv',
      });
      await expectAccessible(tester);
      await tester.tap(find.byKey(ShareKeys.copyLink));
      await tester.pumpAndSettle();
      expect(copied, endsWith('/shares/${share.id}/'));
      await tester.tap(find.byKey(ShareKeys.dismissCreated));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.showCode(share)), findsNothing);
      await tester.tap(find.byKey(ShareKeys.link(share)));
      await tester.pumpAndSettle();
      expect(copied, endsWith('/shares/${share.id}/'));
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('a custom end date', () {
    setUp(() => setUpWith(DataProtection.plain));

    testWidgets("must be picked before sharing, then is the share's end", (
      tester,
    ) async {
      await pump(tester);
      await fillIn(tester);
      await tester.tap(find.byKey(ShareKeys.duration(ShareDuration.custom)));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.customEndMissing), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(ShareKeys.submit)).onPressed,
        isNull,
      );
      await expectAccessible(tester);
      await tester.tap(find.byKey(ShareKeys.customEnd));
      await tester.pumpAndSettle();
      expect(find.text('Last day the share is readable'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(ShareKeys.customEndMissing), findsNothing);
      await tester.tap(find.byKey(ShareKeys.submit));
      await tester.pumpAndSettle();
      expect(shares.shares.single.expiresOn, DateTime(2026, 5, 2));
    });
  });
}
