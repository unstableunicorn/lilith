import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/app_lock.dart';

void main() {
  final t0 = DateTime(2026, 11, 26, 9);
  final pin = PinHash.create('2468', random: Random(1));
  final on = AppLock(pin: pin);

  DateTime after(Duration d) => t0.add(d);

  group('the PIN', () {
    test('is 4 to 8 digits', () {
      expect(['1234', '12345678'].every(isValidPin), isTrue);
      expect(
        ['123', '123456789', '12a4', '', ' 1234'].any(isValidPin),
        isFalse,
      );
    });

    test('is kept as a salted hash that matches only itself', () {
      expect(pin.matches('2468'), isTrue);
      expect(pin.matches('2469'), isFalse);
      expect(pin.toJson().values.join(), isNot(contains('2468')));
      final again = PinHash.create('2468', random: Random(2));
      expect(again.toJson()['hash'], isNot(pin.toJson()['hash']));
    });

    test('round-trips through JSON', () {
      expect(PinHash.fromJson(pin.toJson())?.matches('2468'), isTrue);
      expect(PinHash.fromJson(const {'salt': 'x'}), isNull);
    });
  });

  group('locking', () {
    test('off without a PIN: never locks', () {
      const off = AppLock();
      expect(off.isEnabled, isFalse);
      expect(off.started().isLocked, isFalse);
      expect(
        off.paused(t0).resumed(after(const Duration(hours: 1))).isLocked,
        isFalse,
      );
    });

    test('locks on every fresh start', () {
      expect(on.started().isLocked, isTrue);
    });

    test('locks on return after more than five minutes away', () {
      final away = on.paused(t0);
      expect(away.resumed(after(lockAfterAway)).isLocked, isFalse);
      expect(
        away
            .resumed(after(lockAfterAway + const Duration(seconds: 1)))
            .isLocked,
        isTrue,
      );
    });

    test('a resume without a pause does not lock', () {
      expect(on.resumed(after(const Duration(hours: 1))).isLocked, isFalse);
    });

    test('the right PIN unlocks and forgets the wrong tries', () {
      var lock = on.started();
      lock = lock.tryPin('0000', t0).lock;
      final right = lock.tryPin('2468', t0);
      expect(right.lock.isLocked, isFalse);
      expect(right.lock.failures, 0);
      expect(right.signOut, isFalse);
    });

    test('the fingerprint unlocks only when it is turned on', () {
      final locked = on.started();
      expect(locked.unlockedByBiometrics().isLocked, isTrue);
      final withBio = on.copyWith(biometrics: true).started();
      expect(withBio.unlockedByBiometrics().isLocked, isFalse);
    });
  });

  group('wrong tries', () {
    AppLock wrong(AppLock lock, int times, DateTime at) {
      var l = lock;
      for (var i = 0; i < times; i++) {
        l = l.tryPin('0000', l.waitUntil ?? at).lock;
      }
      return l;
    }

    test('four wrong tries: no wait', () {
      final l = wrong(on.started(), 4, t0);
      expect(l.failures, 4);
      expect(l.canTry(t0), isTrue);
    });

    test('the fifth starts a 30-second wait that doubles after each', () {
      final fifth = wrong(on.started(), 5, t0);
      expect(fifth.waitUntil, after(firstWait));
      expect(fifth.canTry(after(const Duration(seconds: 29))), isFalse);
      expect(fifth.canTry(after(firstWait)), isTrue);
      final sixth = fifth.tryPin('0000', after(firstWait)).lock;
      expect(sixth.waitUntil, after(firstWait * 3));
    });

    test('a try during the wait is refused and not counted', () {
      final fifth = wrong(on.started(), 5, t0);
      final early = fifth.tryPin('2468', after(const Duration(seconds: 1)));
      expect(early.lock.isLocked, isTrue);
      expect(early.lock.failures, 5);
    });

    test('the tenth signs out and clears the lock', () {
      final ninth = wrong(on.started(), 9, t0);
      final tenth = ninth.tryPin('0000', ninth.waitUntil!);
      expect(tenth.signOut, isTrue);
      expect(tenth.lock.isEnabled, isFalse);
      expect(tenth.lock.isLocked, isFalse);
    });

    test('tries and the wait survive a restart', () {
      final fifth = wrong(on.started(), 5, t0);
      final back = AppLock.fromJson(fifth.toJson()).started();
      expect(back.failures, 5);
      expect(back.waitUntil, fifth.waitUntil);
      expect(back.isLocked, isTrue);
    });
  });

  test('the setting round-trips through JSON and loads when absent', () {
    final s = on.copyWith(biometrics: true);
    final back = AppLock.fromJson(s.toJson());
    expect(back.biometrics, isTrue);
    expect(back.pin?.matches('2468'), isTrue);
    expect(AppLock.fromJson(const {}).isEnabled, isFalse);
  });
}
