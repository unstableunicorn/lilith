// What the home screen decides: the prediction for today, what was logged,
// and the two quick actions, a period start and a temperature.

import 'package:flutter/foundation.dart';
import 'package:lilith/content/period_facts.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/cycle_phase.dart';
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
import 'package:lilith/ui/core/forecast_text.dart' as text;
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

  /// Whether Today also shows the person they follow.
  bool get followsSomeone => _repo.data.modeInForce.followsSomeone;

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
    PredictionMethod.paused || PredictionMethod.awaitingPeriod => 'stub',
  }.withSuppressionNote(p);

  /// Today's cycle day and phase.
  CycleStatus get cycleStatus => cycleStatusFor(
    prediction,
    _repo.data.periods,
    today: today,
    hormonalContraception: _repo.data.profile.usesHormonalContraception,
  );

  /// E.g. "Cycle day 12, follicular · since 3 Nov", "(estimated)" after a
  /// calendar phase, or why there is no phase; null with no period.
  String? get cycleLine {
    final s = cycleStatus;
    final start = prediction.lastPeriodStart;
    if (s.day == null || start == null) return null;
    final since = 'since ${formatShortDate(start, today: today)}';
    return switch (s) {
      CycleStatus(:final day, :final phase?, :final basis) =>
        'Cycle day $day, ${phase.name}'
            '${basis == PhaseBasis.calendar ? ' (estimated)' : ''} · $since',
      CycleStatus(:final day, hormonal: true) =>
        'Cycle day $day · $since. Hormonal contraception changes the usual '
            'phases, so none is shown.',
      CycleStatus(:final day) => 'Cycle day $day · $since',
    };
  }

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
  String get forecastSummary => text.forecastSummary(forecast);

  /// The forecast card's symptom badges.
  List<String> get forecastSymptoms => text.forecastSymptomBadges(forecast);

  /// The forecast card's mood badges.
  List<String> get forecastMoods => text.forecastMoodBadges(forecast);

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

  /// The latest period when it is still going today, else null.
  PeriodEvent? get periodInProgress {
    final latest = _repo.data.periods.lastOrNull;
    return latest != null && latest.inProgressOn(today) ? latest : null;
  }

  /// Day of the period in progress, the start being day 1.
  int? get periodDay => switch (periodInProgress) {
    final p? => daysBetween(p.startDate, today) + 1,
    null => null,
  };

  /// Today, then yesterday when the period had begun by then.
  List<DateTime> get quickEndDays {
    final start = periodInProgress?.startDate;
    final yesterday = addDays(today, -1);
    return [today, if (start != null && !start.isAfter(yesterday)) yesterday];
  }

  /// Marks the period in progress as over on [day]. False, changing
  /// nothing, when none is in progress or [day] is before it or after today.
  Future<bool> markPeriodEnded(DateTime day) async {
    final p = periodInProgress;
    final d = dateOnly(day);
    if (p == null || d.isBefore(p.startDate) || d.isAfter(today)) {
      return false;
    }
    await _repo.apply(
      (data) => data.withPeriod(p.copyWith(endDate: d, ended: true)),
    );
    return true;
  }

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
