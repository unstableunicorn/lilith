// Pulls a wearable's nightly temperature into the health data.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/wearable/wearable_source.dart';
import 'package:lilith/domain/day.dart';
import 'package:material_ui/material_ui.dart';

/// Where the last sync got to.
sealed class WearableSync {
  const WearableSync();
}

class WearableIdle extends WearableSync {
  const WearableIdle();
}

class WearableSyncing extends WearableSync {
  const WearableSyncing();
}

class WearableSynced extends WearableSync {
  const WearableSynced(this.nights);

  /// How many nights the wearable had for the window.
  final int nights;
}

class WearableRefused extends WearableSync {
  const WearableRefused();
}

class WearableFailed extends WearableSync {
  const WearableFailed(this.error);

  final Object error;
}

class WearableRepository extends ChangeNotifier {
  WearableRepository(this._health, this._source, {required this.now});

  /// How far back a sync reaches.
  static const int windowDays = 90;

  final HealthRepository _health;
  final WearableSource _source;
  final DateTime Function() now;

  WearableSync _state = const WearableIdle();
  WearableSync get state => _state;

  bool get isAvailable => _source.isAvailable;
  bool get isSyncing => _state is WearableSyncing;

  /// Reads the last [windowDays] nights and adds or replaces each day.
  Future<void> sync() async {
    if (!isAvailable || isSyncing) return;
    _set(const WearableSyncing());
    try {
      if (!await _source.requestPermission()) {
        _set(const WearableRefused());
        return;
      }
      final today = dateOnly(now());
      final nights = await _source.readNights(
        from: addDays(today, -windowDays),
        to: today,
      );
      if (nights.isNotEmpty) {
        await _health.apply((d) => d.withNights(nights));
      }
      _set(WearableSynced(nights.length));
    } on Exception catch (e) {
      _set(WearableFailed(e));
    }
  }

  void _set(WearableSync state) {
    _state = state;
    notifyListeners();
  }
}
