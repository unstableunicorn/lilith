// What the first question decides: which way of using Lilith is offered
// first, and saving the one chosen.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/app_mode.dart';

class ModeViewModel extends ChangeNotifier {
  ModeViewModel(this._health, this._received) {
    _health.addListener(notifyListeners);
    _received.addListener(notifyListeners);
  }

  final HealthRepository _health;
  final ReceivedShareRepository _received;
  AppMode? _picked;
  bool _busy = false;

  /// The way picked, or the one offered until one is: following for someone
  /// who arrived by an invite, tracking for everyone else.
  AppMode get choice =>
      _picked ??
      (_received.pendingInvite == null ? AppMode.tracker : AppMode.partner);

  bool get isBusy => _busy;

  void choose(AppMode mode) {
    _picked = mode;
    notifyListeners();
  }

  /// Saves the choice to the pod.
  Future<void> confirm() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    final chosen = choice;
    try {
      await _health.apply((d) => d.withMode(chosen));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _health.removeListener(notifyListeners);
    _received.removeListener(notifyListeners);
    super.dispose();
  }
}
