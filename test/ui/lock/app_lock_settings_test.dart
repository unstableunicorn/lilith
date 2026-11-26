import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/app_lock_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/app_lock.dart';
import 'package:lilith/ui/lock/pin_setup_screen.dart';
import 'package:lilith/ui/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_biometrics.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_pod_setup_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late FakeSettingsStore settings;
  late FakeBiometrics biometrics;
  late AppLockRepository repo;

  Future<void> pump(WidgetTester tester, {AppLock? lock}) async {
    settings = FakeSettingsStore()..appLock = lock ?? const AppLock();
    biometrics = FakeBiometrics();
    repo = AppLockRepository(settings, biometrics, signOut: () async {});
    final pages = PageSettingsRepository(settings);
    final setup = SetupRepository(FakePodSetupService());
    await tester.runAsync(() async {
      await repo.load();
      // Opened from inside the app, so it is unlocked.
      if (lock?.pin != null) await repo.tryPin('2468');
      await pages.load();
      await setup.inspect();
    });
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(FakePodSessionService(), settings),
        setup: setup,
        pageSettings: pages,
        appLock: repo,
        child: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, Key key, String text) async {
    await tester.enterText(find.byKey(key), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(PinSetupKeys.save));
    await tester.tap(find.byKey(PinSetupKeys.save));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('turning it on sets a PIN typed twice', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byKey(SettingsKeys.appLock));
    await tester.tap(find.byKey(SettingsKeys.appLock));
    await tester.pumpAndSettle();
    expect(find.byType(PinSetupScreen), findsOneWidget);
    expect(find.byKey(PinSetupKeys.current), findsNothing);
    await expectAccessible(tester);
    await type(tester, PinSetupKeys.pin, '1357');
    await type(tester, PinSetupKeys.again, '1358');
    await save(tester);
    expect(find.byKey(PinSetupKeys.error), findsOneWidget);
    expect(settings.appLock.isEnabled, isFalse);
    await type(tester, PinSetupKeys.again, '1357');
    await save(tester);
    expect(settings.appLock.pin?.matches('1357'), isTrue);
    expect(find.byType(PinSetupScreen), findsNothing);
  });

  testWidgets('a PIN under four digits is refused', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byKey(SettingsKeys.appLock));
    await tester.tap(find.byKey(SettingsKeys.appLock));
    await tester.pumpAndSettle();
    await type(tester, PinSetupKeys.pin, '135');
    await type(tester, PinSetupKeys.again, '135');
    await save(tester);
    expect(find.byKey(PinSetupKeys.error), findsOneWidget);
    expect(settings.appLock.isEnabled, isFalse);
  });

  testWidgets('turning it off asks for the PIN', (tester) async {
    await pump(tester, lock: AppLock(pin: PinHash.create('2468')));
    await tester.ensureVisible(find.byKey(SettingsKeys.appLock));
    await tester.tap(find.byKey(SettingsKeys.appLock));
    await tester.pumpAndSettle();
    expect(find.byKey(PinSetupKeys.pin), findsNothing);
    await type(tester, PinSetupKeys.current, '0000');
    await save(tester);
    expect(find.byKey(PinSetupKeys.error), findsOneWidget);
    await type(tester, PinSetupKeys.current, '2468');
    await save(tester);
    expect(settings.appLock.isEnabled, isFalse);
  });

  testWidgets('with a PIN, the fingerprint can be turned on', (tester) async {
    await pump(tester);
    expect(find.byKey(SettingsKeys.appLockBiometrics), findsNothing);
    await pump(tester, lock: AppLock(pin: PinHash.create('2468')));
    await tester.ensureVisible(find.byKey(SettingsKeys.appLockBiometrics));
    await tester.tap(find.byKey(SettingsKeys.appLockBiometrics));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(settings.appLock.biometrics, isTrue);
  });
}
