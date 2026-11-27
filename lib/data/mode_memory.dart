// How the person last signed in on this device uses the app. The pod holds
// the answer; this copy lets the right tabs show while the pod is read.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/app_mode.dart';

class ModeMemory extends ChangeNotifier {
  ModeMemory(this._store);

  final SettingsStore _store;
  AppMode? _mode;

  /// The mode remembered; null until loaded, and when none is.
  AppMode? get mode => _mode;

  /// The mode to draw: the pod's once it has [loaded], else the one
  /// remembered, else a tracker.
  AppMode modeFor({required bool loaded, required AppMode fromPod}) =>
      loaded ? fromPod : _mode ?? AppMode.tracker;

  Future<void> load() async {
    _mode = await _store.readMode();
    notifyListeners();
  }

  /// Keeps [mode] for the next start.
  Future<void> remember(AppMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _store.writeMode(mode);
  }

  /// Signing out leaves nothing of that account behind.
  Future<void> forget() async {
    if (_mode == null) return;
    _mode = null;
    notifyListeners();
    await _store.clearMode();
  }
}
