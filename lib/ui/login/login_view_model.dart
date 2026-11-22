// What the login screen decides: which provider, whether login is possible,
// and what went wrong.

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
  }

  final SessionRepository _session;

  late PodProvider? _selected;
  bool _isCustom = false;
  String _customServer = '';
  bool _busy = false;
  LoginError? _error;

  List<PodProvider> get builtIn => PodProvider.builtIn;

  /// The provider login would use, or null while a typed server is invalid.
  PodProvider? get selected => _selected;
  bool get isCustom => _isCustom;
  String get customServer => _customServer;
  bool get isBusy => _busy;
  LoginError? get error => _error;
  bool get canLogin => _selected != null && !_busy;

  /// Where the selected provider lets the user manage their data.
  Uri? get manageUrl => _selected?.manageUrl;

  void choose(PodProvider provider) {
    _isCustom = false;
    _selected = provider;
    _error = null;
    notifyListeners();
  }

  void chooseCustom() {
    _isCustom = true;
    _selected = PodProvider.custom(_customServer);
    _error = null;
    notifyListeners();
  }

  void setCustomServer(String text) {
    _customServer = text;
    _selected = PodProvider.custom(text);
    _error = _selected == null && text.trim().isNotEmpty
        ? LoginError.invalidServer
        : null;
    notifyListeners();
  }

  Future<void> login(BuildContext context) async {
    final provider = _selected;
    if (provider == null || _busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _session.login(provider, context);
    } on PodLoginCancelledException {
      _error = LoginError.cancelled;
    } on PodUnavailableException {
      _error = LoginError.unreachable;
    } on PodException {
      _error = LoginError.failed;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
