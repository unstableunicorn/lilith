// What following someone decides: who shares with this person, whose share
// Today shows, and whether there is anyone to choose between.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/share.dart';

class FollowViewModel extends ChangeNotifier {
  FollowViewModel(this._health) {
    _health.addListener(notifyListeners);
  }

  final HealthRepository _health;

  bool get isLoaded => _health.isLoaded;

  /// Why the pod document could not be loaded or saved, if it could not.
  RepositoryError? get error => _health.error;

  /// True while the pod is still being read: not loaded, and not failed.
  bool get isWaiting => !isLoaded && error == null;

  void clearError() => _health.clearError();

  /// Everyone who shares with this person, in the order they were added.
  List<ReceivedShare> get people => _health.data.received;

  /// Whose share shows; null when nobody shares.
  ReceivedShare? get followed => _health.data.followedShare;

  /// A chooser is offered only when there is a choice.
  bool get showsChooser => people.length > 1;

  /// Shows [share] from now on, on every device.
  Future<void> follow(ReceivedShare share) =>
      _health.apply((d) => d.withFollowed(share.sharerWebId));

  @override
  void dispose() {
    _health.removeListener(notifyListeners);
    super.dispose();
  }
}
