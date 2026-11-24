// What the tabs show, chosen per device. Everything is on by default.

import 'package:meta/meta.dart';

@immutable
class PageSettings {
  const PageSettings({
    this.showFact = true,
    this.showForecast = true,
    this.showCalendar = true,
    this.showTemperatureChart = true,
  });

  factory PageSettings.fromJson(Map<String, dynamic> json) => PageSettings(
    showFact: json['showFact'] as bool? ?? true,
    showForecast: json['showForecast'] as bool? ?? true,
    showCalendar: json['showCalendar'] as bool? ?? true,
    showTemperatureChart: json['showTemperatureChart'] as bool? ?? true,
  );

  /// Today: the fact of the day.
  final bool showFact;

  /// Today: the symptom forecast.
  final bool showForecast;

  /// History: the month calendar.
  final bool showCalendar;

  /// History: the temperature trend.
  final bool showTemperatureChart;

  PageSettings copyWith({
    bool? showFact,
    bool? showForecast,
    bool? showCalendar,
    bool? showTemperatureChart,
  }) => PageSettings(
    showFact: showFact ?? this.showFact,
    showForecast: showForecast ?? this.showForecast,
    showCalendar: showCalendar ?? this.showCalendar,
    showTemperatureChart: showTemperatureChart ?? this.showTemperatureChart,
  );

  Map<String, dynamic> toJson() => {
    'showFact': showFact,
    'showForecast': showForecast,
    'showCalendar': showCalendar,
    'showTemperatureChart': showTemperatureChart,
  };

  @override
  bool operator ==(Object other) =>
      other is PageSettings &&
      other.showFact == showFact &&
      other.showForecast == showForecast &&
      other.showCalendar == showCalendar &&
      other.showTemperatureChart == showTemperatureChart;

  @override
  int get hashCode =>
      Object.hash(showFact, showForecast, showCalendar, showTemperatureChart);
}
