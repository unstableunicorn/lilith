import 'package:lilith/data/wearable/wearable_source.dart';
import 'package:lilith/domain/wearable_night.dart';

/// Hands back what a test puts in, and records what was asked.
class FakeWearableSource implements WearableSource {
  bool available = true;
  bool permission = true;
  List<WearableNight> nights = [];
  Exception? failRead;
  final List<(DateTime, DateTime)> windows = [];

  @override
  bool get isAvailable => available;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<List<WearableNight>> readNights({
    required DateTime from,
    required DateTime to,
  }) async {
    windows.add((from, to));
    if (failRead case final e?) throw e;
    return nights;
  }
}
