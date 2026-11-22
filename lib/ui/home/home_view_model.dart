// What the home screen decides: the prediction for today, what was logged,
// and the two quick actions, a period start and a temperature.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(
    this._repo, {
    required this.now,
    this.predictor = const CyclePredictor(),
  }) {
    _repo.addListener(notifyListeners);
  }

  /// Plausible skin temperatures, in °C; anything else is a typo.
  static const double minCelsius = 34.0;
  static const double maxCelsius = 42.0;

  final HealthRepository _repo;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final CyclePredictor predictor;

  DateTime get today => dateOnly(now());
  bool get isLoading => _repo.isLoading;

  /// False until the first load has succeeded; nothing can be logged before.
  bool get isLoaded => _repo.isLoaded;
  RepositoryError? get error => _repo.error;
  bool get hasData => _repo.data.hasData;

  CyclePrediction get prediction => predictor.predict(
    readings: _repo.data.readings,
    periods: _repo.data.periods,
    today: today,
  );

  int? get daysUntilNextPeriod => prediction.daysUntilNextPeriod(today);

  TemperatureReading? get latestReading => _repo.data.readings.lastOrNull;

  TemperatureReading? get todaysReading {
    final day = today;
    for (final r in _repo.data.readings.reversed) {
      if (r.date == day) return r;
      if (r.date.isBefore(day)) break;
    }
    return null;
  }

  DailyLog? get todaysLog => _repo.data.logFor(today);

  DateTime? get lastPeriodStart => _repo.data.periods.lastOrNull?.startDate;

  /// Logs a period start on [day], today when omitted.
  Future<void> logPeriodStart([DateTime? day]) =>
      _repo.apply((d) => d.withPeriod(PeriodEvent(startDate: day ?? today)));

  Future<void> removePeriodStart(DateTime day) =>
      _repo.apply((d) => d.withoutPeriod(day));

  /// Logs today's temperature. Returns false, logging nothing, when the
  /// value is not a plausible body temperature.
  Future<bool> logTemperature(double celsius) async {
    if (celsius < minCelsius || celsius > maxCelsius) return false;
    await _repo.apply(
      (d) => d.withReading(TemperatureReading(date: today, celsius: celsius)),
    );
    return true;
  }

  void clearError() => _repo.clearError();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
