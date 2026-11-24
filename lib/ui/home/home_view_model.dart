// What the home screen decides: the prediction for today, what was logged,
// and the two quick actions, a period start and a temperature.

import 'package:flutter/foundation.dart';
import 'package:lilith/content/period_facts.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/symptom_predictor.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/learn/learn_view_model.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(
    this._repo, {
    required this.now,
    this.predictor = const CyclePredictor(),
    this.symptomPredictor = const SymptomPredictor(),
  }) {
    _repo.addListener(notifyListeners);
  }

  /// Plausible skin temperatures, in °C, from the model.
  static const double minCelsius = TemperatureReading.minCelsius;
  static const double maxCelsius = TemperatureReading.maxCelsius;

  DateTime? _readingDay;

  /// The day the next logged temperature is for: today unless changed.
  DateTime get readingDay => _readingDay ?? today;
  bool get readingDayIsToday => readingDay == today;

  /// "Today's temperature (°C)" or "Temperature on 8 Jun (°C)".
  String get readingDayLabel => readingDayIsToday
      ? "Today's temperature (°C)"
      : 'Temperature on ${formatShortDate(readingDay, today: today)} (°C)';

  /// A day up to today; later days are ignored.
  void setReadingDay(DateTime day) {
    final d = dateOnly(day);
    if (d.isAfter(today)) return;
    _readingDay = d == today ? null : d;
    notifyListeners();
  }

  final HealthRepository _repo;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final CyclePredictor predictor;
  final SymptomPredictor symptomPredictor;

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
    nights: _repo.data.wearableNights,
    usualCycleLength: _repo.data.profile.usualCycleLength,
    suppressShift: _repo.data.profile.usesHormonalContraception,
    maxConfidence: confidenceCapFor(_repo.data.profile.regularity),
  );

  static String _riseText(CyclePrediction p) =>
      p.shiftSeries == TemperatureSeries.wearable
      ? 'A sustained rise in the night temperature from your wearable'
      : 'A sustained temperature rise';

  /// How the prediction was arrived at, for the person reading it.
  String howText(CyclePrediction p) => switch (p.method) {
    PredictionMethod.temperatureShift =>
      '${_riseText(p)} around '
          '${formatShortDate(p.estimatedOvulation!, today: today)} '
          'suggests ovulation; a ${p.lutealLength}-day luteal phase follows.',
    PredictionMethod.usualCycleLength =>
      'Based on the usual cycle length you entered. Your own cycles take '
          'over once two are logged.',
    PredictionMethod.cycleAverage when p.cycleCount == 0 =>
      'Only one period logged, so this assumes a typical '
          '${CyclePredictor.defaultCycleLength}-day cycle.',
    PredictionMethod.cycleAverage =>
      'Based on your average cycle of '
          '${p.averageCycleLength!.toStringAsFixed(1)} days over '
          '${p.cycleCount} recorded ${p.cycleCount == 1 ? 'cycle' : 'cycles'}.',
    PredictionMethod.insufficientData => 'Not enough data yet.',
  }.withSuppressionNote(p);

  /// This cycle's fertile window when [mode] shows it and something
  /// supports it; null otherwise.
  FertileWindow? fertileWindowShown(FertileWindowMode mode) =>
      mode == FertileWindowMode.hidden
      ? null
      : fertileWindowFor(
          prediction,
          _repo.data.dailyLogs,
          hormonalContraception: _repo.data.profile.usesHormonalContraception,
        );

  /// E.g. "Likely fertile 9 Jun to 14 Jun, dated from your positive
  /// ovulation test."
  String fertileWindowText(FertileWindow w) {
    final from = switch (w.basis) {
      FertileWindowBasis.shift => 'temperature rise',
      FertileWindowBasis.test => 'positive ovulation test',
    };
    return 'Likely fertile ${formatShortDate(w.start, today: today)} to '
        '${formatShortDate(w.end, today: today)}, dated from your $from.';
  }

  PeriodFact get fact => factOfTheDay(today);

  SymptomForecast get forecast => symptomPredictor.predict(
    logs: _repo.data.dailyLogs,
    periods: _repo.data.periods,
    today: today,
  );

  /// E.g. "From 6 logged days at this point of past cycles. Pain around 6/10
  /// has been typical."
  String get forecastSummary {
    final f = forecast;
    final pain = f.typicalPain;
    return 'From ${f.loggedDays} logged days at this point of past cycles.'
        '${pain == null ? '' : ' Pain around ${pain.round()}/10 '
                  'has been typical.'}';
  }

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
  /// Logs the temperature for [readingDay], then returns to today. Returns
  /// false, logging nothing, when the value is not a plausible body
  /// temperature.
  Future<bool> logTemperature(double celsius) async {
    if (!TemperatureReading.isPlausible(celsius)) return false;
    final day = readingDay;
    await _repo.apply(
      (d) => d.withReading(TemperatureReading(date: day, celsius: celsius)),
    );
    _readingDay = null;
    notifyListeners();
    return true;
  }

  void clearError() => _repo.clearError();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Irregular cycles cap how sure a prediction may claim to be.
PredictionConfidence? confidenceCapFor(CycleRegularity? regularity) =>
    switch (regularity) {
      CycleRegularity.irregular => PredictionConfidence.low,
      CycleRegularity.somewhatIrregular => PredictionConfidence.medium,
      CycleRegularity.regular || null => null,
    };

extension on String {
  String withSuppressionNote(CyclePrediction p) => p.shiftSuppressed
      ? '$this Temperature is not used while you are on hormonal '
            'contraception.'
      : this;
}
