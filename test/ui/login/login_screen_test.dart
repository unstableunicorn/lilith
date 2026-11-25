import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/core/app_links.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/login/login_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late FakePodSessionService auth;
  late SessionRepository session;
  late RecordingUrlOpener urls;

  setUp(() {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    urls = RecordingUrlOpener();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    harness(session: session, openUrl: urls.call, child: const LoginScreen()),
  );

  testWidgets('meets the accessibility guidelines', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(LoginKeys.other));
    await tester.pump();
    await expectAccessible(tester);
  });

  testWidgets('offers every built-in provider and another one', (tester) async {
    await pump(tester);
    for (final p in PodProvider.builtIn) {
      expect(find.byKey(LoginKeys.provider(p)), findsOneWidget);
    }
    expect(find.byKey(LoginKeys.other), findsOneWidget);
    expect(find.byKey(LoginKeys.server), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(LoginKeys.login)).enabled,
      isTrue,
    );
  });

  testWidgets(
    'another provider shows the server field and disables login until it '
    'is valid',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(LoginKeys.other));
      await tester.pump();
      expect(find.byKey(LoginKeys.server), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(LoginKeys.login)).enabled,
        isFalse,
      );

      await tester.enterText(find.byKey(LoginKeys.server), 'not a url');
      await tester.pump();
      expect(find.byKey(LoginKeys.error), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(LoginKeys.login)).enabled,
        isFalse,
      );

      await tester.enterText(find.byKey(LoginKeys.server), 'pods.example.org');
      await tester.pump();
      expect(find.byKey(LoginKeys.error), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(LoginKeys.login)).enabled,
        isTrue,
      );
    },
  );

  testWidgets('logging in uses the chosen provider', (tester) async {
    await pump(tester);
    await tester.tap(
      find.byKey(LoginKeys.provider(PodProvider.unstableUnicorn)),
    );
    await tester.pump();
    await tester.tap(find.byKey(LoginKeys.login));
    await tester.pumpAndSettle();
    expect(auth.logins, [PodProvider.unstableUnicorn]);
    expect(session.session?.provider, PodProvider.unstableUnicorn);
  });

  testWidgets('a failed login shows the error and keeps the screen usable', (
    tester,
  ) async {
    auth.failLogin = const PodLoginFailedException('x');
    await pump(tester);
    await tester.tap(find.byKey(LoginKeys.login));
    await tester.pumpAndSettle();
    expect(find.byKey(LoginKeys.error), findsOneWidget);
    expect(find.byKey(LoginKeys.busy), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(LoginKeys.login)).enabled,
      isTrue,
    );
  });

  testWidgets('a failed login shows what the library said', (tester) async {
    auth.failLogin = const PodLoginFailedException('OidcException: bad jkt');
    await pump(tester);
    await tester.tap(find.byKey(LoginKeys.login));
    await tester.pumpAndSettle();
    expect(find.byKey(LoginKeys.errorDetail), findsOneWidget);
    expect(find.text('OidcException: bad jkt'), findsOneWidget);
    await tester.tap(find.byKey(LoginKeys.other));
    await tester.pump();
    expect(find.byKey(LoginKeys.errorDetail), findsNothing);
  });

  testWidgets("manage-your-data opens the chosen provider's site", (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find.byKey(LoginKeys.provider(PodProvider.unstableUnicorn)),
    );
    await tester.pump();
    await tester.tap(find.byKey(LoginKeys.manage));
    await tester.pump();
    expect(urls.opened, [PodProvider.unstableUnicorn.manageUrl]);

    await tester.tap(find.byKey(LoginKeys.other));
    await tester.pump();
    expect(find.byKey(LoginKeys.manage), findsNothing);
  });

  testWidgets('on the web it offers the Android app; in the app it does not', (
    tester,
  ) async {
    final downloads = RecordingUrlOpener();
    await tester.pumpWidget(
      harness(
        session: session,
        openUrl: urls.call,
        download: Downloader(downloads.call),
        child: const LoginScreen(offerAndroidApp: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LoginKeys.androidApp));
    expect(downloads.opened, [AppLinks.androidApk]);
    expect(urls.opened, isEmpty);
    expect(AppLinks.androidApk.host, 'github.com');
    await expectAccessible(tester);
    await tester.pumpWidget(
      harness(
        session: session,
        openUrl: urls.call,
        child: const LoginScreen(offerAndroidApp: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(LoginKeys.androidApp), findsNothing);
  });
}
