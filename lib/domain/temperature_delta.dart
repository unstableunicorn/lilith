// A night's skin temperature as a wearable reports it: the change from the
// wearer's own baseline, not a temperature. One per day.

import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:meta/meta.dart';

@immutable
class TemperatureDelta {
  TemperatureDelta({
    required DateTime date,
    required this.deltaCelsius,
    this.source = ReadingSource.watch,
  }) : date = dateOnly(date);

  factory TemperatureDelta.fromJson(Map<String, dynamic> json) =>
      TemperatureDelta(
        date: DateTime.parse(json['date'] as String),
        deltaCelsius: (json['delta'] as num).toDouble(),
        source: ReadingSource.fromName(json['source'] as String?),
      );

  final DateTime date;

  /// Degrees above (or below) the wearable's baseline for the wearer.
  final double deltaCelsius;
  final ReadingSource source;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'delta': deltaCelsius,
    'source': source.name,
  };

  @override
  bool operator ==(Object other) =>
      other is TemperatureDelta &&
      other.date == date &&
      other.deltaCelsius == deltaCelsius &&
      other.source == source;

  @override
  int get hashCode => Object.hash(date, deltaCelsius, source);
}
