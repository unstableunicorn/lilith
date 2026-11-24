// What the security key screen decides: whether the typed keys can be used,
// and how the change ended.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/ui/setup/setup_view_model.dart';

enum NewKeyProblem { tooShort, mismatch, sameAsCurrent }

class SecurityKeyViewModel extends ChangeNotifier {
  SecurityKeyViewModel(this._setup);

  final SetupRepository _setup;

  String _current = '';
  String _new = '';
  String _confirm = '';
  bool _changing = false;
  KeyChangeOutcome? _outcome;

  String get newKey => _new;
  bool get isChanging => _changing;

  /// How the last change ended; null before one, and again once a field is
  /// edited.
  KeyChangeOutcome? get outcome => _outcome;

  /// Why the new key cannot be used yet, or null when it can.
  NewKeyProblem? get problem {
    const min = SetupViewModel.minKeyLength;
    if (_new.length < min) return NewKeyProblem.tooShort;
    if (_new != _confirm) return NewKeyProblem.mismatch;
    if (_new == _current) return NewKeyProblem.sameAsCurrent;
    return null;
  }

  bool get canChange =>
      !_changing &&
      _outcome != KeyChangeOutcome.changed &&
      _current.isNotEmpty &&
      problem == null;

  void setCurrentKey(String text) => _edit(() => _current = text);
  void setNewKey(String text) => _edit(() => _new = text);
  void setConfirmKey(String text) => _edit(() => _confirm = text);

  /// Changes the key. Does nothing while it cannot.
  Future<void> change() async {
    if (!canChange) return;
    _changing = true;
    _outcome = null;
    notifyListeners();
    _outcome = await _setup.changeKey(_current, _new);
    _changing = false;
    notifyListeners();
  }

  void _edit(void Function() update) {
    update();
    if (_outcome != KeyChangeOutcome.changed) _outcome = null;
    notifyListeners();
  }
}
