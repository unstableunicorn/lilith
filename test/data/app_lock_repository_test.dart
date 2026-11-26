import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/app_lock_repository.dart';
import 'package:lilith/domain/app_lock.dart';

import '../fakes/fake_biometrics.dart';
import '../fakes/fake_settings_store.dart';

void main() {
  late FakeSettingsStore settings;
  late FakeBiometrics biometrics;
  late AppLockRepository repo;
  late DateTime now;
  late int signOuts;

  setUp(() {
    settings = FakeSettingsStore();
    biometrics = FakeBiometrics();
    now = DateTime(2026, 11, 26, 9);
    signOuts = 0;
    repo = AppLockRepository(
      settings,
      biometrics,
      signOut: () async => signOuts++,
      now: () => now,
    );
  });

  Future<void> withPin() async {
    settings.appLock = AppLock(pin: PinHash.create('2468'));
    await repo.load();
  }

  test('off until a PIN is set; loading reads it and locks', () async {
    await repo.load();
    expect(repo.isLoaded, isTrue);
    expect(repo.isLocked, isFalse);
    await withPin();
    expect(repo.isLocked, isTrue);
  });

  test('setting a PIN keeps it and leaves the app open', () async {
    await repo.load();
    expect(await repo.setPin('12'), isFalse);
    expect(await repo.setPin('1357'), isTrue);
    expect(settings.appLock.pin?.matches('1357'), isTrue);
    expect(repo.isLocked, isFalse);
  });

  test('the right PIN unlocks; a wrong one is counted and kept', () async {
    await withPin();
    expect(await repo.tryPin('0000'), isFalse);
    expect(settings.appLock.failures, 1);
    expect(await repo.tryPin('2468'), isTrue);
    expect(repo.isLocked, isFalse);
    expect(settings.appLock.failures, 0);
  });

  test('ten wrong tries sign out and clear the lock', () async {
    await withPin();
    for (var i = 0; i < triesBeforeSignOut; i++) {
      now = repo.lock.waitUntil ?? now;
      await repo.tryPin('0000');
    }
    expect(signOuts, 1);
    expect(settings.appLock.isEnabled, isFalse);
    expect(repo.isLocked, isFalse);
  });

  test('five minutes away locks it again', () async {
    await withPin();
    await repo.tryPin('2468');
    repo.paused();
    now = now.add(lockAfterAway + const Duration(seconds: 1));
    repo.resumed();
    expect(repo.isLocked, isTrue);
  });

  test('turning it off needs the PIN', () async {
    await withPin();
    await repo.tryPin('2468');
    expect(await repo.turnOff('0000'), isFalse);
    expect(settings.appLock.isEnabled, isTrue);
    expect(await repo.turnOff('2468'), isTrue);
    expect(settings.appLock.isEnabled, isFalse);
  });

  test('the fingerprint is offered where the phone has one', () async {
    biometrics.available = false;
    await withPin();
    expect(repo.biometricsAvailable, isFalse);
    biometrics.available = true;
    await repo.load();
    expect(repo.biometricsAvailable, isTrue);
  });

  test('turning the fingerprint on asks for it first', () async {
    await withPin();
    await repo.tryPin('2468');
    biometrics.answer = false;
    await repo.setBiometrics(true);
    expect(settings.appLock.biometrics, isFalse);
    biometrics.answer = true;
    await repo.setBiometrics(true);
    expect(settings.appLock.biometrics, isTrue);
  });

  test('once on, the fingerprint unlocks', () async {
    settings.appLock = AppLock(pin: PinHash.create('2468'), biometrics: true);
    await repo.load();
    biometrics.answer = false;
    await repo.unlockWithBiometrics();
    expect(repo.isLocked, isTrue);
    biometrics.answer = true;
    await repo.unlockWithBiometrics();
    expect(repo.isLocked, isFalse);
  });
}
