import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/design/design_screen.dart';
import 'package:lilith/ui/export/export_screen.dart';
import 'package:lilith/ui/pod/pod_screen.dart';
import 'package:lilith/ui/profile/profile_screen.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/share/share_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_pod_setup_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';
import '../../fakes/fake_share_service.dart';
import '../../harness.dart';

void main() {
  late FakePodSessionService auth;
  late SessionRepository session;
  late SetupRepository setup;
  late RecordingUrlOpener urls;
  late HealthRepository health;
  late ShareRepository shares;
  late ReceivedShareRepository received;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    setup = SetupRepository(
      FakePodSetupService()
        ..inspection = const PodInspection(
          plainDocumentExists: false,
          keysOnPod: true,
          keyOnDevice: true,
        ),
    );
    await setup.inspect();
    urls = RecordingUrlOpener();
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    shares = ShareRepository(
      health,
      FakeShareService(),
      protection: DataProtection.plain,
    );
    received = ReceivedShareRepository(
      health,
      FakeShareReader(),
      ownWebId: auth.webId,
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2800);
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
        setup: setup,
        health: health,
        shares: shares,
        received: received,
        openUrl: urls.call,
        child: const PodScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows who, where and how the data is protected', (tester) async {
    await pump(tester);
    expect(find.text(auth.webId), findsOneWidget);
    expect(find.text(PodProvider.unstableUnicorn.name), findsOneWidget);
    expect(find.text('solid.unstableunicorn.dev'), findsOneWidget);
    expect(find.byKey(PodKeys.protection), findsOneWidget);
    expect(find.textContaining('encrypted'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('copies the WebID', (tester) async {
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
    await tester.tap(find.byKey(PodKeys.copy));
    await tester.pumpAndSettle();
    expect(copied, auth.webId);
    expect(find.text('WebID copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('manage opens the provider and log out ends the session', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(PodKeys.manage));
    expect(urls.opened, [PodProvider.unstableUnicorn.manageUrl]);
    await tester.tap(find.byKey(PodKeys.logout));
    await tester.pumpAndSettle();
    expect(session.session, isNull);
  });

  testWidgets('summarises the health profile and opens it', (tester) async {
    await pump(tester);
    expect(find.text('Nothing recorded yet'), findsOneWidget);
    await tester.tap(find.byKey(PodKeys.profile));
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileKeys.save), findsOneWidget);
  });

  testWidgets('summarises sharing and opens the sharing page', (tester) async {
    await pump(tester);
    expect(find.text('Not shared with anyone'), findsOneWidget);
    await tester.tap(find.byKey(PodKeys.sharing));
    await tester.pumpAndSettle();
    expect(find.byKey(ShareKeys.submit), findsOneWidget);
  });

  testWidgets('summarises what is shared with you and opens it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Nobody is sharing with you'), findsOneWidget);
    await tester.tap(find.byKey(PodKeys.received));
    await tester.pumpAndSettle();
    expect(find.byKey(ReceivedKeys.submit), findsOneWidget);
  });

  testWidgets('opens the export page', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(PodKeys.export));
    await tester.pumpAndSettle();
    expect(find.byKey(ExportKeys.sharePdf), findsOneWidget);
  });

  testWidgets('a debug build links to the design gallery', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(PodKeys.design));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(DesignKeys.page), findsOneWidget);
  });
}
