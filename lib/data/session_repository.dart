// Who is logged in, for the whole app. Screens listen to it.

import 'package:flutter/widgets.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';

class SessionRepository extends ChangeNotifier {
  SessionRepository(this._auth, this._settings, {this.onLogout});

  final PodSessionService _auth;
  final SettingsStore _settings;

  /// Runs when the user signs out, and at no other time.
  final Future<void> Function()? onLogout;

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

  /// Warms the login up for [provider]; failures are the login's to report.
  Future<void> prepare(PodProvider provider) async {
    try {
      await _auth.prepare(provider);
    } on Object {
      // The real login reports what is wrong; a failed warm-up is harmless.
    }
  }

  /// Logs in at [provider], remembering the choice first so it survives the
  /// page leaving for the provider on the web. Answers false in that case and
  /// stays logging in: the session arrives through [restore] on the next
  /// start. Rethrows the PodException on failure, with no session set.
  Future<bool> login(PodProvider provider, BuildContext context) async {
    _loggingIn = true;
    notifyListeners();
    try {
      await _settings.writeProvider(provider);
      if (!context.mounted) throw const PodLoginCancelledException();
      final session = await _auth.login(provider, context);
      if (session == null) return false;
      _session = session;
      _provider = provider;
    } on Object {
      _loggingIn = false;
      notifyListeners();
      rethrow;
    }
    _loggingIn = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await _auth.logout();
    await onLogout?.call();
    _session = null;
    notifyListeners();
  }
}
