// What the set-up screen decides: which protection, whether the typed key is
// acceptable, and when the buttons work.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/data_protection.dart';

enum KeyProblem { tooShort, mismatch }

class SetupViewModel extends ChangeNotifier {
  SetupViewModel(this._setup) {
    _setup.addListener(notifyListeners);
  }

  /// Fewest characters a new security key may have.
  static const int minKeyLength = 8;

  final SetupRepository _setup;

  DataProtection _choice = DataProtection.recommended;
  String _key = '';
  String _confirmKey = '';

  DataProtection get choice => _choice;
  String get key => _key;
  bool get isBusy => _setup.isBusy;
  SetupError? get error => _setup.error;
  SetupState get state => _setup.state;

  /// Why the new key cannot be used yet, or null when it can.
  KeyProblem? get keyProblem {
    if (_choice == DataProtection.plain) return null;
    if (_key.length < minKeyLength) return KeyProblem.tooShort;
    if (_key != _confirmKey) return KeyProblem.mismatch;
    return null;
  }

  bool get canConfirm =>
      !isBusy && (_choice == DataProtection.plain || keyProblem == null);

  bool get canUnlock => !isBusy && _key.isNotEmpty;

  void choose(DataProtection protection) {
    _choice = protection;
    notifyListeners();
  }

  void setKey(String text) {
    _key = text;
    notifyListeners();
  }

  void setConfirmKey(String text) {
    _confirmKey = text;
    notifyListeners();
  }

  /// Sets the pod up as chosen. Does nothing while it cannot.
  Future<void> confirm() async {
    if (!canConfirm) return;
    if (_choice == DataProtection.plain) {
      await _setup.choosePlain();
    } else {
      await _setup.chooseEncrypted(_key);
    }
  }

  Future<void> unlock() async {
    if (!canUnlock) return;
    await _setup.unlock(_key);
  }

  Future<void> retry() => _setup.inspect();

  @override
  void dispose() {
    _setup.removeListener(notifyListeners);
    super.dispose();
  }
}
