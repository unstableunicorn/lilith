// Who is logged in, for the whole app. Screens listen to it.

import 'package:flutter/widgets.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';

class SessionRepository extends ChangeNotifier {
  SessionRepository(this._auth, this._settings);

  final PodSessionService _auth;
  final SettingsStore _settings;

  PodSession? _session;
  PodProvider _provider = PodProvider.builtIn.first;
  bool _restoring = false;
  bool _loggingIn = false;

  PodSession? get session => _session;

  /// The provider in use, or the one chosen last time.
  PodProvider get provider => _provider;
  bool get isRestoring => _restoring;
  bool get isLoggingIn => _loggingIn;

  /// Brings back a saved session, or at least the last chosen provider.
  Future<void> restore() async {
    _restoring = true;
    notifyListeners();
    try {
      _session = await _auth.restore();
      _provider =
          _session?.provider ?? await _settings.readProvider() ?? _provider;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Logs in at [provider] and remembers the choice. Rethrows the
  /// PodException on failure, with no session set.
  Future<void> login(PodProvider provider, BuildContext context) async {
    _loggingIn = true;
    notifyListeners();
    try {
      _session = await _auth.login(provider, context);
      _provider = provider;
      await _settings.writeProvider(provider);
    } finally {
      _loggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _session = null;
    notifyListeners();
  }
}
