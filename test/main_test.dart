import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/main.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/login/login_screen.dart';
import 'package:lilith/ui/setup/setup_screen.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_pod_service.dart';
import 'fakes/fake_share_reader.dart';
import 'fakes/fake_share_service.dart';
import 'fakes/fake_pod_session_service.dart';
import 'fakes/fake_pod_setup_service.dart';
import 'fakes/fake_settings_store.dart';

void main() {
  late FakePodSessionService auth;
  late FakePodSetupService podSetup;
  late SessionRepository session;
  late SetupRepository setup;
  late FakePodService pod;

  setUp(() {
    auth = FakePodSessionService();
    podSetup = FakePodSetupService();
    session = SessionRepository(auth, FakeSettingsStore());
    setup = SetupRepository(podSetup);
    pod = FakePodService();
  });

  LilithApp app() => LilithApp(
    session: session,
    setup: setup,
    podFor: (_) => pod,
    shareService: FakeShareService(),
    shareReader: FakeShareReader(),
    settings: FakeSettingsStore(),
    openUrl: (_) async {},
    shareFile: (_) async {},
    pdfReport: const PdfReport(),
  );

  testWidgets('shows the login screen when nobody is logged in', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a restored session on a fresh pod goes to set-up', (
    tester,
  ) async {
    auth.restored = PodSession(
      webId: auth.webId,
      provider: PodProvider.unstableUnicorn,
    );
    await tester.pumpWidget(app());
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(podSetup.inspections, 1);
  });

  testWidgets(
    'a pod that is ready goes to home with a repository for its mode',
    (tester) async {
      auth.restored = PodSession(
        webId: auth.webId,
        provider: PodProvider.unstableUnicorn,
      );
      podSetup.inspection = const PodInspection(
        plainDocumentExists: true,
        keysOnPod: false,
        keyOnDevice: false,
      );
      await tester.pumpWidget(app());
      await session.restore();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      final repo = tester
          .element(find.byType(HomeScreen))
          .read<HealthRepository>();
      expect(repo.protection, DataProtection.plain);
      expect(repo.isLoaded, isTrue, reason: 'home loads the data on arrival');
    },
  );

  testWidgets('logging out returns to login and forgets the set-up state', (
    tester,
  ) async {
    auth.restored = PodSession(
      webId: auth.webId,
      provider: PodProvider.unstableUnicorn,
    );
    podSetup.inspection = const PodInspection(
      plainDocumentExists: true,
      keysOnPod: false,
      keyOnDevice: false,
    );
    await tester.pumpWidget(app());
    await session.restore();
    await tester.pumpAndSettle();
    await session.logout();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(setup.state, const SetupState.unknown());
  });

  testWidgets('shows a wait indicator while restoring', (tester) async {
    auth.restoreGate = Completer<void>();
    await tester.pumpWidget(app());
    final restoring = session.restore();
    await tester.pump();
    expect(find.byKey(AppKeys.restoring), findsOneWidget);
    auth.restoreGate!.complete();
    await restoring;
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.restoring), findsNothing);
  });
}
