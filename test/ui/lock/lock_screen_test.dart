import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/app_lock_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/app_lock.dart';
import 'package:lilith/ui/lock/lock_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_biometrics.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late FakeSettingsStore settings;
  late FakeBiometrics biometrics;
  late AppLockRepository repo;
  late DateTime now;

  Future<void> pump(WidgetTester tester, {bool withBiometrics = false}) async {
    settings = FakeSettingsStore()
      ..appLock = AppLock(
        pin: PinHash.create('2468'),
        biometrics: withBiometrics,
      );
    biometrics = FakeBiometrics()..answer = false;
    now = DateTime(2026, 11, 26, 9);
    repo = AppLockRepository(
      settings,
      biometrics,
      signOut: () async {},
      now: () => now,
    );
    await tester.runAsync(repo.load);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(FakePodSessionService(), settings),
        appLock: repo,
        child: const LockScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(LockKeys.digit(int.parse(d))));
      await tester.pump();
    }
    await tester.tap(find.byKey(LockKeys.unlock));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('the right PIN unlocks, accessibly', (tester) async {
    await pump(tester);
    expect(find.byKey(LockKeys.screen), findsOneWidget);
    await expectAccessible(tester);
    await enter(tester, '2468');
    expect(repo.isLocked, isFalse);
  });

  testWidgets('a wrong PIN says so and clears what was typed', (tester) async {
    await pump(tester);
    await enter(tester, '1111');
    expect(repo.isLocked, isTrue);
    expect(find.byKey(LockKeys.error), findsOneWidget);
    await enter(tester, '2468');
    expect(repo.isLocked, isFalse, reason: 'the wrong digits were cleared');
  });

  testWidgets('the delete key takes back a digit', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(LockKeys.digit(9)));
    await tester.tap(find.byKey(LockKeys.delete));
    await enter(tester, '2468');
    expect(repo.isLocked, isFalse);
  });

  testWidgets('after five wrong tries it shows the wait', (tester) async {
    await pump(tester);
    for (var i = 0; i < triesBeforeWait; i++) {
      await enter(tester, '1111');
    }
    expect(find.byKey(LockKeys.wait), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(LockKeys.unlock)).onPressed,
      isNull,
    );
  });

  testWidgets('the fingerprint is offered only once turned on', (tester) async {
    await pump(tester);
    expect(find.byKey(LockKeys.biometrics), findsNothing);
    await pump(tester, withBiometrics: true);
    expect(find.byKey(LockKeys.biometrics), findsOneWidget);
    biometrics.answer = true;
    await tester.tap(find.byKey(LockKeys.biometrics));
    await tester.pumpAndSettle();
    expect(repo.isLocked, isFalse);
  });
}
