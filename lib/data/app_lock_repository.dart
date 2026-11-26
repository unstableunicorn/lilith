// The app lock on this phone: keeps the setting, follows the app going to
// the background and back, and signs out after too many wrong tries.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/biometrics.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/app_lock.dart';

class AppLockRepository extends ChangeNotifier {
  AppLockRepository(
    this._settings,
    this._biometrics, {
    required this.signOut,
    this.now = DateTime.now,
  });

  final SettingsStore _settings;
  final Biometrics _biometrics;

  /// Signs out of the pod, after the last wrong try.
  final Future<void> Function() signOut;

  /// The clock, injected so tests move it.
  final DateTime Function() now;

  AppLock _lock = const AppLock();
  bool _loaded = false;
  bool _biometricsAvailable = false;

  AppLock get lock => _lock;
  bool get isLoaded => _loaded;
  bool get isLocked => _lock.isLocked;

  /// Whether the phone has a fingerprint or face to offer.
  bool get biometricsAvailable => _biometricsAvailable;

  /// Reads the setting and locks, as on a fresh start.
  Future<void> load() async {
    _lock = (await _settings.readAppLock()).started();
    _biometricsAvailable = await _biometrics.isAvailable();
    _loaded = true;
    notifyListeners();
  }

  void paused() => _lock = _lock.paused(now());

  void resumed() {
    final was = _lock.isLocked;
    _lock = _lock.resumed(now());
    if (_lock.isLocked != was) notifyListeners();
  }

  /// True when [pin] unlocked it.
  Future<bool> tryPin(String pin) async {
    final outcome = _lock.tryPin(pin, now());
    await _save(outcome.lock);
    if (outcome.signOut) await signOut();
    return !outcome.lock.isLocked && !outcome.signOut;
  }

  Future<void> unlockWithBiometrics() async {
    if (!_lock.biometrics) return;
    if (!await _biometrics.authenticate('Unlock Lilith')) return;
    await _save(_lock.unlockedByBiometrics());
  }

  /// Sets a new PIN, or refuses one that is not 4 to 8 digits.
  Future<bool> setPin(String pin) async {
    if (!isValidPin(pin)) return false;
    await _save(_lock.withPin(PinHash.create(pin)));
    return true;
  }

  /// Turns the lock off, given the PIN.
  Future<bool> turnOff(String pin) async {
    final p = _lock.pin;
    if (p == null || !p.matches(pin)) return false;
    await _save(_lock.withPin(null));
    return true;
  }

  /// Turning it on asks for the fingerprint or face first.
  Future<void> setBiometrics(bool on) async {
    if (on && !await _biometrics.authenticate('Use it to unlock Lilith')) {
      return;
    }
    await _save(_lock.copyWith(biometrics: on));
  }

  Future<void> _save(AppLock next) async {
    _lock = next;
    await _settings.writeAppLock(next);
    notifyListeners();
  }
}
