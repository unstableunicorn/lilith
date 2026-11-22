import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/main.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/login/login_screen.dart';

import 'fakes/fake_pod_session_service.dart';
import 'fakes/fake_settings_store.dart';

void main() {
  late FakePodSessionService auth;
  late SessionRepository session;

  setUp(() {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
  });

  testWidgets('shows the login screen when nobody is logged in', (
    tester,
  ) async {
    await tester.pumpWidget(LilithApp(session: session, openUrl: (_) async {}));
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows home when a session is restored', (tester) async {
    auth.restored = PodSession(
      webId: auth.webId,
      provider: PodProvider.unstableUnicorn,
    );
    await tester.pumpWidget(LilithApp(session: session, openUrl: (_) async {}));
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('shows a wait indicator while restoring', (tester) async {
    auth.restoreGate = Completer<void>();
    await tester.pumpWidget(LilithApp(session: session, openUrl: (_) async {}));
    final restoring = session.restore();
    await tester.pump();
    expect(find.byKey(AppKeys.restoring), findsOneWidget);
    auth.restoreGate!.complete();
    await restoring;
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.restoring), findsNothing);
  });
}
