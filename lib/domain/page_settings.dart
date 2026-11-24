// What the tabs show, chosen per device. Everything is on by default except
// the fertile window, which the person turns on.

import 'package:meta/meta.dart';

/// Whether the fertile window shows, and which disclaimer goes with it.
enum FertileWindowMode {
  /// No window.
  hidden,

  /// Trying to conceive: "estimates, does not confirm" only.
  conceiving,

  /// Shown as information: also "not a contraceptive method".
  information,
}

@immutable
class PageSettings {
  const PageSettings({
    this.showFact = true,
    this.showForecast = true,
    this.showCalendar = true,
    this.showTemperatureChart = true,
    this.tryingToConceive = false,
    this.showFertileWindow = false,
  });

  factory PageSettings.fromJson(Map<String, dynamic> json) => PageSettings(
    showFact: json['showFact'] as bool? ?? true,
    showForecast: json['showForecast'] as bool? ?? true,
    showCalendar: json['showCalendar'] as bool? ?? true,
    showTemperatureChart: json['showTemperatureChart'] as bool? ?? true,
    tryingToConceive: json['tryingToConceive'] as bool? ?? false,
    showFertileWindow: json['showFertileWindow'] as bool? ?? false,
  );

  /// Today: the fact of the day.
  final bool showFact;

  /// Today: the symptom forecast.
  final bool showForecast;

  /// History: the month calendar.
  final bool showCalendar;

  /// History: the temperature trend.
  final bool showTemperatureChart;

  /// Fertile window: the person is trying to conceive.
  final bool tryingToConceive;

  /// Fertile window: show it as information.
  final bool showFertileWindow;

  FertileWindowMode get fertileWindowMode => tryingToConceive
      ? FertileWindowMode.conceiving
      : showFertileWindow
      ? FertileWindowMode.information
      : FertileWindowMode.hidden;

  PageSettings copyWith({
    bool? showFact,
    bool? showForecast,
    bool? showCalendar,
    bool? showTemperatureChart,
    bool? tryingToConceive,
    bool? showFertileWindow,
  }) => PageSettings(
    showFact: showFact ?? this.showFact,
    showForecast: showForecast ?? this.showForecast,
    showCalendar: showCalendar ?? this.showCalendar,
    showTemperatureChart: showTemperatureChart ?? this.showTemperatureChart,
    tryingToConceive: tryingToConceive ?? this.tryingToConceive,
    showFertileWindow: showFertileWindow ?? this.showFertileWindow,
  );

  Map<String, dynamic> toJson() => {
    'showFact': showFact,
    'showForecast': showForecast,
    'showCalendar': showCalendar,
    'showTemperatureChart': showTemperatureChart,
    'tryingToConceive': tryingToConceive,
    'showFertileWindow': showFertileWindow,
  };

  @override
  bool operator ==(Object other) =>
      other is PageSettings &&
      other.showFact == showFact &&
      other.showForecast == showForecast &&
      other.showCalendar == showCalendar &&
      other.showTemperatureChart == showTemperatureChart &&
      other.tryingToConceive == tryingToConceive &&
      other.showFertileWindow == showFertileWindow;

  @override
  int get hashCode => Object.hash(
    showFact,
    showForecast,
    showCalendar,
    showTemperatureChart,
    tryingToConceive,
    showFertileWindow,
  );
}
