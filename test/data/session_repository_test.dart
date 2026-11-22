import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/pod_provider.dart';

import '../fakes/fake_pod_session_service.dart';
import '../fakes/fake_settings_store.dart';

void main() {
  late FakePodSessionService auth;
  late FakeSettingsStore settings;
  late SessionRepository repo;
  late int notifications;

  setUp(() {
    auth = FakePodSessionService();
    settings = FakeSettingsStore();
    repo = SessionRepository(auth, settings);
    notifications = 0;
    repo.addListener(() => notifications++);
  });

  test('starts with no session and the first built-in provider', () {
    expect(repo.session, isNull);
    expect(repo.isRestoring, isFalse);
    expect(repo.provider, PodProvider.builtIn.first);
  });

  group('restore', () {
    test('brings back a saved session and its provider', () async {
      final saved = PodSession(
        webId: 'https://x/#me',
        provider: PodProvider.unstableUnicorn,
      );
      auth.restored = saved;
      await repo.restore();
      expect(repo.session, saved);
      expect(repo.provider, PodProvider.unstableUnicorn);
      expect(repo.isRestoring, isFalse);
    });

    test('with nothing saved, takes the last chosen provider', () async {
      settings.provider = PodProvider.unstableUnicorn;
      await repo.restore();
      expect(repo.session, isNull);
      expect(repo.provider, PodProvider.unstableUnicorn);
    });

    test('notifies while restoring and when done', () async {
      final seen = <bool>[];
      repo.addListener(() => seen.add(repo.isRestoring));
      await repo.restore();
      expect(seen, [true, false]);
    });
  });

  test('prepare warms the service up for the provider', () async {
    await repo.prepare(PodProvider.unstableUnicorn);
    expect(auth.prepared, [PodProvider.unstableUnicorn]);
  });

  group('login', () {
    testWidgets('sets the session and remembers the provider', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      await repo.login(PodProvider.unstableUnicorn, context);
      expect(repo.session?.provider, PodProvider.unstableUnicorn);
      expect(repo.session?.webId, auth.webId);
      expect(settings.provider, PodProvider.unstableUnicorn);
      expect(auth.logins, [PodProvider.unstableUnicorn]);
    });

    testWidgets('remembers the provider before the browser leaves', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      auth.redirects = true;
      final done = await repo.login(PodProvider.unstableUnicorn, context);
      expect(done, isFalse);
      expect(settings.provider, PodProvider.unstableUnicorn);
      expect(repo.session, isNull);
      expect(repo.isLoggingIn, isTrue, reason: 'the page is on its way out');
    });

    testWidgets('a completed login is done', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      expect(await repo.login(PodProvider.unstableUnicorn, context), isTrue);
      expect(repo.isLoggingIn, isFalse);
    });

    testWidgets('a failed login leaves no session and rethrows', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      auth.failLogin = const PodLoginFailedException('nope');
      await expectLater(
        repo.login(PodProvider.unstableUnicorn, context),
        throwsA(isA<PodLoginFailedException>()),
      );
      expect(repo.session, isNull);
      expect(repo.isLoggingIn, isFalse);
    });
  });

  testWidgets('logout clears the session and tells the service', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await repo.login(
      PodProvider.unstableUnicorn,
      tester.element(find.byType(SizedBox)),
    );
    notifications = 0;
    await repo.logout();
    expect(repo.session, isNull);
    expect(auth.logouts, 1);
    expect(notifications, 1);
    expect(
      repo.provider,
      PodProvider.unstableUnicorn,
      reason: 'the choice survives logout',
    );
  });
}
