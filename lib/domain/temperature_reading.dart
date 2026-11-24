// One skin-temperature reading for one calendar day.

import 'package:lilith/domain/day.dart';
import 'package:meta/meta.dart';

/// Where a reading came from.
enum ReadingSource {
  manual,
  ring,
  watch;

  /// The stored name's value, or [manual] when unknown or missing so old
  /// documents still load.
  static ReadingSource fromName(String? name) => ReadingSource.values
      .firstWhere((s) => s.name == name, orElse: () => ReadingSource.manual);
}

/// A resting skin temperature for [date], at most one per day.
@immutable
class TemperatureReading {
  TemperatureReading({
    required DateTime date,
    required this.celsius,
    this.source = ReadingSource.manual,
  }) : date = dateOnly(date);
  factory TemperatureReading.fromJson(Map<String, dynamic> json) =>
      TemperatureReading(
        date: DateTime.parse(json['date'] as String),
        celsius: (json['celsius'] as num).toDouble(),
        source: ReadingSource.fromName(json['source'] as String?),
      );

  /// Plausible skin temperatures, in °C; anything else is a typo.
  static const double minCelsius = 34;
  static const double maxCelsius = 42;

  static bool isPlausible(double celsius) =>
      celsius >= minCelsius && celsius <= maxCelsius;

  final DateTime date;
  final double celsius;
  final ReadingSource source;

  TemperatureReading copyWith({double? celsius, ReadingSource? source}) =>
      TemperatureReading(
        date: date,
        celsius: celsius ?? this.celsius,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'celsius': celsius,
    'source': source.name,
  };

  @override
  bool operator ==(Object other) =>
      other is TemperatureReading &&
      other.date == date &&
      other.celsius == celsius &&
      other.source == source;

  @override
  int get hashCode => Object.hash(date, celsius, source);
}
