// Where a wearable's nightly skin temperature comes from. The Android source
// is chosen by the Galaxy Watch spike (Health Connect or Samsung's SDK);
// until then, and on the web, there is none.

import 'package:lilith/domain/temperature_delta.dart';

abstract interface class WearableSource {
  /// Whether this device can read a wearable's temperature at all.
  bool get isAvailable;

  /// Asks the system once; true when the data may be read.
  Future<bool> requestPermission();

  /// Nightly changes from baseline with a day in [from]..[to], any order.
  Future<List<TemperatureDelta>> readDeltas({
    required DateTime from,
    required DateTime to,
  });
}

class NoWearableSource implements WearableSource {
  const NoWearableSource();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<List<TemperatureDelta>> readDeltas({
    required DateTime from,
    required DateTime to,
  }) async => const [];
}
