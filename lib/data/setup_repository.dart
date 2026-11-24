// Where set-up stands for the logged-in pod, for the whole app.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_setup_service.dart';
import 'package:lilith/domain/data_protection.dart';

enum SetupError { unreachable, wrongKey, failed }

/// How a security key change ended. [unchanged]: it failed and the old key
/// still works. [broken]: it failed and the key files could not be put back.
enum KeyChangeOutcome { changed, wrongKey, unchanged, broken }

class SetupRepository extends ChangeNotifier {
  SetupRepository(this._pod);

  final PodSetupService _pod;

  SetupState _state = const SetupState.unknown();
  bool _busy = false;
  SetupError? _error;
  String? _errorDetail;

  SetupState get state => _state;
  bool get isBusy => _busy;
  SetupError? get error => _error;

  /// What the pod or the library said about [error], for the user to report.
  String? get errorDetail => _errorDetail;

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

  /// Whether this pod has a security key to change.
  bool get canChangeKey =>
      _state == const SetupState.ready(DataProtection.encrypted);

  /// Changes the security key. Set-up state, busy and error are untouched:
  /// the caller shows its own progress.
  Future<KeyChangeOutcome> changeKey(String currentKey, String newKey) async {
    try {
      await _pod.changeKey(currentKey, newKey);
      return KeyChangeOutcome.changed;
    } on PodWrongKeyException {
      return KeyChangeOutcome.wrongKey;
    } on PodKeyChangeException catch (e) {
      return e.restored ? KeyChangeOutcome.unchanged : KeyChangeOutcome.broken;
    } on PodException {
      return KeyChangeOutcome.unchanged;
    }
  }

  /// Back to unknown, for the next login.
  void reset() {
    _state = const SetupState.unknown();
    _error = null;
    _errorDetail = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _errorDetail = null;
    notifyListeners();
    try {
      await action();
    } on PodWrongKeyException {
      _error = SetupError.wrongKey;
    } on PodUnavailableException catch (e) {
      _error = SetupError.unreachable;
      _errorDetail = e.message;
    } on PodException catch (e) {
      _error = SetupError.failed;
      _errorDetail = e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
