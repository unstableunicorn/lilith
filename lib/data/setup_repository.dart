// Where set-up stands for the logged-in pod, for the whole app.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_setup_service.dart';
import 'package:lilith/domain/data_protection.dart';

enum SetupError { unreachable, wrongKey, failed }

class SetupRepository extends ChangeNotifier {
  SetupRepository(this._pod);

  final PodSetupService _pod;

  SetupState _state = const SetupState.unknown();
  bool _busy = false;
  SetupError? _error;

  SetupState get state => _state;
  bool get isBusy => _busy;
  SetupError? get error => _error;

  /// Finds out what the pod needs. On failure the state stays as it was.
  Future<void> inspect() => _run(() async {
    _state = setupStateFor(await _pod.inspect());
  });

  Future<void> chooseEncrypted(String securityKey) => _run(() async {
    await _pod.setUpEncryption(securityKey);
    _state = const SetupState.ready(DataProtection.encrypted);
  });

  Future<void> choosePlain() => _run(() async {
    await _pod.setUpPlain();
    _state = const SetupState.ready(DataProtection.plain);
  });

  Future<void> unlock(String securityKey) => _run(() async {
    await _pod.unlock(securityKey);
    _state = const SetupState.ready(DataProtection.encrypted);
  });

  /// Back to unknown, for the next login.
  void reset() {
    _state = const SetupState.unknown();
    _error = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on PodWrongKeyException {
      _error = SetupError.wrongKey;
    } on PodUnavailableException {
      _error = SetupError.unreachable;
    } on PodException {
      _error = SetupError.failed;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
