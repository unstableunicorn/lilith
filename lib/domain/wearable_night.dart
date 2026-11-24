// A night's skin temperature as a wearable reports it. Wrist skin runs well
// below core temperature and each device has its own offset, so these are
// read only against each other, never against oral readings. One per night.

import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:meta/meta.dart';

@immutable
class WearableNight {
  WearableNight({
    required DateTime date,
    required this.celsius,
    this.source = ReadingSource.watch,
  }) : date = dateOnly(date);

  factory WearableNight.fromJson(Map<String, dynamic> json) => WearableNight(
    date: DateTime.parse(json['date'] as String),
    celsius: (json['celsius'] as num).toDouble(),
    source: ReadingSource.fromName(json['source'] as String?),
  );

  final DateTime date;

  /// The night's skin temperature as the device reports it, in °C.
  final double celsius;
  final ReadingSource source;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'celsius': celsius,
    'source': source.name,
  };

  @override
  bool operator ==(Object other) =>
      other is WearableNight &&
      other.date == date &&
      other.celsius == celsius &&
      other.source == source;

  @override
  int get hashCode => Object.hash(date, celsius, source);
}
