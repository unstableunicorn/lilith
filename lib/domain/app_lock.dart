// The app lock: a PIN, and the fingerprint or face where the phone offers
// it, asked on every fresh start and on return after five minutes away.
// Wrong tries wait, then sign out (owner, 2026-11-26, #65). Pure: the clock
// and the PIN come in, the next state goes out.
//
// The PIN is a salted PBKDF2 hash in the phone's own settings. It stops
// someone holding an unlocked phone; it is no defence against someone who
// can read the app's storage, who could try every PIN offline.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Away longer than this and the app locks on return.
const Duration lockAfterAway = Duration(minutes: 5);

/// Wrong tries before the first wait, and the wait it starts. Each further
/// wrong try doubles the wait.
const int triesBeforeWait = 5;
const Duration firstWait = Duration(seconds: 30);

/// Wrong tries that sign out and clear the lock.
const int triesBeforeSignOut = 10;

final RegExp _pin = RegExp(r'^[0-9]{4,8}$');

/// Whether [pin] can be a PIN: 4 to 8 digits.
bool isValidPin(String pin) => _pin.hasMatch(pin);

@immutable
class PinHash {
  const PinHash._(this._salt, this._hash);

  /// Hashes [pin] with a fresh salt; [random] is for tests.
  factory PinHash.create(String pin, {Random? random}) {
    final r = random ?? Random.secure();
    final salt = Uint8List.fromList([
      for (var i = 0; i < 16; i++) r.nextInt(256),
    ]);
    return PinHash._(salt, _derive(pin, salt));
  }

  static const int _iterations = 20000;

  final Uint8List _salt;
  final Uint8List _hash;

  /// PBKDF2 with HMAC-SHA-256, one 32-byte block.
  static Uint8List _derive(String pin, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  bool matches(String pin) {
    final h = _derive(pin, _salt);
    var diff = 0;
    for (var i = 0; i < h.length; i++) {
      diff |= h[i] ^ _hash[i];
    }
    return diff == 0 && h.length == _hash.length;
  }

  static PinHash? fromJson(Map<String, Object?> json) {
    final salt = json['salt'];
    final hash = json['hash'];
    if (salt is! String || hash is! String) return null;
    try {
      return PinHash._(base64.decode(salt), base64.decode(hash));
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'salt': base64.encode(_salt),
    'hash': base64.encode(_hash),
  };
}

/// What a PIN try gives: the next state, and whether to sign out.
typedef PinOutcome = ({AppLock lock, bool signOut});

@immutable
class AppLock {
  const AppLock({
    this.pin,
    this.biometrics = false,
    this.isLocked = false,
    this.failures = 0,
    this.waitUntil,
    this.awaySince,
  });

  /// The setting as kept on the phone. Whether it is locked is not kept:
  /// [started] locks it.
  factory AppLock.fromJson(Map<String, Object?> json) {
    final pin = json['pin'];
    final failures = json['failures'];
    final wait = json['waitUntil'];
    return AppLock(
      pin: pin is Map<String, Object?> ? PinHash.fromJson(pin) : null,
      biometrics: json['biometrics'] == true,
      failures: failures is int && failures > 0 ? failures : 0,
      waitUntil: wait is String ? DateTime.tryParse(wait) : null,
    );
  }

  /// The PIN; without one the lock is off.
  final PinHash? pin;

  /// Whether the fingerprint or face may unlock instead of the PIN.
  final bool biometrics;

  final bool isLocked;

  /// Wrong tries in a row.
  final int failures;

  /// No try is taken before this.
  final DateTime? waitUntil;

  /// When the app went to the background, if it is there.
  final DateTime? awaySince;

  bool get isEnabled => pin != null;

  /// On a fresh start.
  AppLock started() => _with(isLocked: isEnabled);

  /// The app went to the background at [now].
  AppLock paused(DateTime now) => _with(awaySince: now);

  /// The app came back at [now].
  AppLock resumed(DateTime now) {
    final since = awaySince;
    final long = since != null && now.difference(since) > lockAfterAway;
    return _with(isLocked: isLocked || (isEnabled && long), clearAway: true);
  }

  bool canTry(DateTime now) {
    final until = waitUntil;
    return until == null || !now.isBefore(until);
  }

  PinOutcome tryPin(String entered, DateTime now) {
    final p = pin;
    if (p == null || !isLocked) return (lock: this, signOut: false);
    if (!canTry(now)) return (lock: this, signOut: false);
    if (p.matches(entered)) {
      return (
        lock: _with(isLocked: false, failures: 0, clearWait: true),
        signOut: false,
      );
    }
    final n = failures + 1;
    if (n >= triesBeforeSignOut) return (lock: const AppLock(), signOut: true);
    final wait = n < triesBeforeWait
        ? null
        : now.add(firstWait * (1 << (n - triesBeforeWait)));
    return (
      lock: _with(failures: n, waitUntil: wait, clearWait: wait == null),
      signOut: false,
    );
  }

  /// The phone confirmed the fingerprint or face.
  AppLock unlockedByBiometrics() => biometrics && isEnabled
      ? _with(isLocked: false, failures: 0, clearWait: true)
      : this;

  /// Sets or clears the PIN; clearing turns the lock off.
  AppLock withPin(PinHash? pin) => AppLock(
    pin: pin,
    biometrics: pin != null && biometrics,
    awaySince: awaySince,
  );

  AppLock copyWith({bool? biometrics}) =>
      _with(biometrics: biometrics ?? this.biometrics);

  AppLock _with({
    bool? biometrics,
    bool? isLocked,
    int? failures,
    DateTime? waitUntil,
    DateTime? awaySince,
    bool clearWait = false,
    bool clearAway = false,
  }) => AppLock(
    pin: pin,
    biometrics: biometrics ?? this.biometrics,
    isLocked: isLocked ?? this.isLocked,
    failures: failures ?? this.failures,
    waitUntil: clearWait ? null : waitUntil ?? this.waitUntil,
    awaySince: clearAway ? null : awaySince ?? this.awaySince,
  );

  Map<String, Object?> toJson() => {
    if (pin case final p?) 'pin': p.toJson(),
    'biometrics': biometrics,
    'failures': failures,
    if (waitUntil case final w?) 'waitUntil': w.toIso8601String(),
  };
}
