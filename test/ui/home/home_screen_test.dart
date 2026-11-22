import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/home/home_screen.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late FakePodSessionService auth;
  late SessionRepository session;
  late RecordingUrlOpener urls;

  setUp(() async {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    urls = RecordingUrlOpener();
  });

  Future<void> pumpLoggedIn(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await session.login(
      PodProvider.unstableUnicorn,
      tester.element(find.byType(SizedBox)),
    );
    await tester.pumpWidget(
      harness(session: session, openUrl: urls.call, child: const HomeScreen()),
    );
  }

  testWidgets('shows who is logged in', (tester) async {
    await pumpLoggedIn(tester);
    expect(find.byKey(HomeKeys.webId), findsOneWidget);
    expect(find.text(auth.webId), findsOneWidget);
  });

  testWidgets('manage-your-data opens the session\'s provider site', (
    tester,
  ) async {
    await pumpLoggedIn(tester);
    await tester.tap(find.byKey(HomeKeys.manage));
    await tester.pump();
    expect(urls.opened, [PodProvider.unstableUnicorn.manageUrl]);
  });

  testWidgets('logout ends the session', (tester) async {
    await pumpLoggedIn(tester);
    await tester.tap(find.byKey(HomeKeys.logout));
    await tester.pumpAndSettle();
    expect(session.session, isNull);
    expect(auth.logouts, 1);
  });
}
