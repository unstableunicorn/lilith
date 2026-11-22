// What the login screen decides: which provider, whether login is possible,
// and what went wrong.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/pod_provider.dart';

enum LoginError { invalidServer, cancelled, failed, unreachable }

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._session) {
    final remembered = _session.provider;
    if (remembered.isBuiltIn) {
      _selected = remembered;
    } else {
      _isCustom = true;
      _customServer = remembered.serverUrl.toString();
      _selected = remembered;
    }
    _prepare();
  }

  final SessionRepository _session;

  late PodProvider? _selected;
  bool _isCustom = false;
  String _customServer = '';
  bool _busy = false;
  LoginError? _error;
  String? _errorDetail;

  List<PodProvider> get builtIn => PodProvider.builtIn;

  /// The provider login would use, or null while a typed server is invalid.
  PodProvider? get selected => _selected;
  bool get isCustom => _isCustom;
  String get customServer => _customServer;
  bool get isBusy => _busy;
  LoginError? get error => _error;

  /// What the library said when the login failed, for a bug report.
  String? get errorDetail => _errorDetail;
  bool get canLogin => _selected != null && !_busy;

  /// Where the selected provider lets the user manage their data.
  Uri? get manageUrl => _selected?.manageUrl;

  void choose(PodProvider provider) {
    _isCustom = false;
    _selected = provider;
    _error = null;
    _errorDetail = null;
    _prepare();
    notifyListeners();
  }

  void chooseCustom() {
    _isCustom = true;
    _selected = PodProvider.custom(_customServer);
    _error = null;
    _errorDetail = null;
    _prepare();
    notifyListeners();
  }

  void setCustomServer(String text) {
    _customServer = text;
    _selected = PodProvider.custom(text);
    _error = _selected == null && text.trim().isNotEmpty
        ? LoginError.invalidServer
        : null;
    _errorDetail = null;
    _prepare();
    notifyListeners();
  }

  void _prepare() {
    if (_selected case final provider?) unawaited(_session.prepare(provider));
  }

  /// Logs in. Stays busy when the page has left for the provider, since the
  /// result comes back with the next app start, not here.
  Future<void> login(BuildContext context) async {
    final provider = _selected;
    if (provider == null || _busy) return;
    _busy = true;
    _error = null;
    _errorDetail = null;
    notifyListeners();
    try {
      _busy = !await _session.login(provider, context);
    } on PodLoginCancelledException {
      _error = LoginError.cancelled;
      _busy = false;
    } on PodUnavailableException catch (e) {
      _error = LoginError.unreachable;
      _errorDetail = e.message;
      _busy = false;
    } on PodException catch (e) {
      _error = LoginError.failed;
      _errorDetail = e.message;
      _busy = false;
    }
    notifyListeners();
  }
}
