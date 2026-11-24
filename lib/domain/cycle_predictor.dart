// Predict the next period from period starts and skin temperature.
//
// After ovulation, progesterone lifts resting temperature by about 0.2–0.5 °C
// for the luteal phase, which is fairly constant in length. A sustained rise
// therefore dates ovulation, and ovulation plus the luteal length dates the
// next period. Without a visible rise, the average cycle length is used.

import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

/// How a prediction was derived.
enum PredictionMethod {
  insufficientData,

  /// No real cycle yet; the next period is the user's usual cycle length
  /// after the last start.
  usualCycleLength,
  cycleAverage,
  temperatureShift,
}

enum PredictionConfidence { none, low, medium, high }

/// The outcome of [CyclePredictor.predict]. Dates are midnight.
class CyclePrediction {
  const CyclePrediction({
    required this.method,
    required this.confidence,
    this.predictedNextPeriod,
    this.lastPeriodStart,
    this.currentCycleDay,
    this.estimatedOvulation,
    this.averageCycleLength,
    this.cycleCount = 0,
    this.lutealLength,
    this.averagePeriodLength,
    this.periodCount = 0,
  });

  final PredictionMethod method;
  final PredictionConfidence confidence;
  final DateTime? predictedNextPeriod;
  final DateTime? lastPeriodStart;

  /// Day of the current cycle, where the last period start is day 1.
  final int? currentCycleDay;

  /// Ovulation dated from the temperature shift, when one was found.
  final DateTime? estimatedOvulation;

  /// Mean of the plausible recorded cycle lengths, when there is one.
  final double? averageCycleLength;

  /// How many plausible cycle lengths went into [averageCycleLength].
  final int cycleCount;

  /// The luteal length added to [estimatedOvulation], when a shift was used.
  final int? lutealLength;

  /// Mean length in days of the periods whose end is known, leaving out one
  /// that ended in the last few days and may still be going.
  final double? averagePeriodLength;

  /// How many periods went into [averagePeriodLength].
  final int periodCount;

  /// Calendar days from [today] to [predictedNextPeriod]; negative when
  /// overdue.
  int? daysUntilNextPeriod(DateTime today) {
    final next = predictedNextPeriod;
    return next == null ? null : daysBetween(today, next);
  }
}

/// Pure prediction over logged readings and period starts.
class CyclePredictor {
  const CyclePredictor();

  /// Luteal length used until the user's own history can measure it.
  static const int defaultLutealLength = 14;

  /// Cycle length used when only one period has been logged.
  static const int defaultCycleLength = 28;

  /// Rise above the follicular baseline that counts as a shift, in °C.
  static const double shiftThreshold = 0.2;

  /// Consecutive elevated readings needed to confirm a shift.
  static const int sustainedDays = 3;

  /// A period that ended this recently may still be going, so its length
  /// is left out of the average.
  static const int settlingDays = 3;

  /// Predict relative to [today]; readings after it are ignored.
  CyclePrediction predict({
    required List<TemperatureReading> readings,
    required List<PeriodEvent> periods,
    required DateTime today,
    int? usualCycleLength,
  }) {
    final now = dateOnly(today);
    final sorted = [...periods]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (sorted.isEmpty) {
      return const CyclePrediction(
        method: PredictionMethod.insufficientData,
        confidence: PredictionConfidence.none,
      );
    }
    final starts = sorted.map((p) => p.startDate).toList();

    final lastStart = starts.last;
    final currentCycleDay = daysBetween(lastStart, now) + 1;
    final cycleLengths = [
      for (var i = 1; i < starts.length; i++)
        daysBetween(starts[i - 1], starts[i]),
    ].where((d) => d > 10 && d < 90).toList();
    final average = cycleLengths.isEmpty
        ? null
        : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    final periodLengths = [
      for (final p in sorted)
        if (p.lengthDays case final n?)
          if (daysBetween(p.endDate!, now) > settlingDays) n,
    ];
    final averagePeriod = periodLengths.isEmpty
        ? null
        : periodLengths.reduce((a, b) => a + b) / periodLengths.length;

    final ovulation = _detectOvulation(readings, sorted.last, now);
    if (ovulation != null) {
      final luteal =
          _historicalLutealLength(readings, sorted) ?? defaultLutealLength;
      return CyclePrediction(
        method: PredictionMethod.temperatureShift,
        confidence: cycleLengths.length >= 2
            ? PredictionConfidence.high
            : PredictionConfidence.medium,
        predictedNextPeriod: addDays(ovulation, luteal),
        lastPeriodStart: lastStart,
        currentCycleDay: currentCycleDay,
        estimatedOvulation: ovulation,
        averageCycleLength: average,
        cycleCount: cycleLengths.length,
        lutealLength: luteal,
        averagePeriodLength: averagePeriod,
        periodCount: periodLengths.length,
      );
    }

    if (cycleLengths.isEmpty && usualCycleLength != null) {
      return CyclePrediction(
        method: PredictionMethod.usualCycleLength,
        confidence: PredictionConfidence.low,
        predictedNextPeriod: addDays(lastStart, usualCycleLength),
        lastPeriodStart: lastStart,
        currentCycleDay: currentCycleDay,
        averagePeriodLength: averagePeriod,
        periodCount: periodLengths.length,
      );
    }

    return CyclePrediction(
      method: PredictionMethod.cycleAverage,
      confidence: switch (cycleLengths.length) {
        >= 3 => PredictionConfidence.high,
        2 => PredictionConfidence.medium,
        _ => PredictionConfidence.low,
      },
      predictedNextPeriod: addDays(
        lastStart,
        (average ?? defaultCycleLength).round(),
      ),
      lastPeriodStart: lastStart,
      currentCycleDay: currentCycleDay,
      averageCycleLength: average,
      cycleCount: cycleLengths.length,
      averagePeriodLength: averagePeriod,
      periodCount: periodLengths.length,
    );
  }

  /// The day before the first [sustainedDays] consecutive readings at least
  /// [shiftThreshold] above the follicular baseline, or null without one.
  /// Readings on the period's known days are left out: they run warm.
  DateTime? _detectOvulation(
    List<TemperatureReading> readings,
    PeriodEvent period,
    DateTime until,
  ) {
    final from = period.endDate == null
        ? period.startDate
        : addDays(period.endDate!, 1);
    final cycle =
        readings
            .where((r) => !r.date.isBefore(from) && !r.date.isAfter(until))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (cycle.length < 4 + sustainedDays) return null;

    // Baseline: up to five early readings, never more than half the cycle.
    final baselineCount = cycle.length ~/ 2 < 5 ? cycle.length ~/ 2 : 5;
    if (baselineCount < 3) return null;
    final baseline =
        cycle
            .take(baselineCount)
            .map((r) => r.celsius)
            .reduce((a, b) => a + b) /
        baselineCount;

    for (var i = baselineCount; i <= cycle.length - sustainedDays; i++) {
      final window = cycle.sublist(i, i + sustainedDays);
      if (window.every((r) => r.celsius >= baseline + shiftThreshold)) {
        return addDays(cycle[i].date, -1);
      }
    }
    return null;
  }

  /// Mean ovulation-to-period gap over past cycles with a visible shift.
  int? _historicalLutealLength(
    List<TemperatureReading> readings,
    List<PeriodEvent> periods,
  ) {
    final lengths = <int>[];
    for (var i = 0; i < periods.length - 1; i++) {
      final next = periods[i + 1].startDate;
      final ovulation = _detectOvulation(
        readings,
        periods[i],
        addDays(next, -1),
      );
      if (ovulation == null) continue;
      final length = daysBetween(ovulation, next);
      if (length >= 9 && length <= 17) lengths.add(length);
    }
    if (lengths.isEmpty) return null;
    return (lengths.reduce((a, b) => a + b) / lengths.length).round();
  }
}
