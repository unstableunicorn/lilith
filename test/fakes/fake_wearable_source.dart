import 'package:lilith/data/wearable/wearable_source.dart';
import 'package:lilith/domain/temperature_delta.dart';

/// Hands back what a test puts in, and records what was asked.
class FakeWearableSource implements WearableSource {
  bool available = true;
  bool permission = true;
  List<TemperatureDelta> deltas = [];
  Exception? failRead;
  final List<(DateTime, DateTime)> windows = [];

  @override
  bool get isAvailable => available;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<List<TemperatureDelta>> readDeltas({
    required DateTime from,
    required DateTime to,
  }) async {
    windows.add((from, to));
    if (failRead case final e?) throw e;
    return deltas;
  }
}
