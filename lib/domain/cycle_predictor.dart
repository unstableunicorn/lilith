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
enum PredictionMethod { insufficientData, cycleAverage, temperatureShift }

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

  /// Calendar days from [today] to [predictedNextPeriod]; negative when overdue.
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

  /// Predict relative to [today]; readings after it are ignored.
  CyclePrediction predict({
    required List<TemperatureReading> readings,
    required List<PeriodEvent> periods,
    required DateTime today,
  }) {
    final now = dateOnly(today);
    final starts = periods.map((p) => p.startDate).toList()..sort();
    if (starts.isEmpty) {
      return const CyclePrediction(
        method: PredictionMethod.insufficientData,
        confidence: PredictionConfidence.none,
      );
    }

    final lastStart = starts.last;
    final currentCycleDay = daysBetween(lastStart, now) + 1;
    final cycleLengths = [
      for (var i = 1; i < starts.length; i++)
        daysBetween(starts[i - 1], starts[i]),
    ].where((d) => d > 10 && d < 90).toList();
    final average = cycleLengths.isEmpty
        ? null
        : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;

    final ovulation = _detectOvulation(readings, lastStart, now);
    if (ovulation != null) {
      final luteal =
          _historicalLutealLength(readings, starts) ?? defaultLutealLength;
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
    );
  }

  /// The day before the first [sustainedDays] consecutive readings at least
  /// [shiftThreshold] above the follicular baseline, or null without one.
  DateTime? _detectOvulation(
    List<TemperatureReading> readings,
    DateTime cycleStart,
    DateTime until,
  ) {
    final cycle =
        readings
            .where(
              (r) => !r.date.isBefore(cycleStart) && !r.date.isAfter(until),
            )
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
    List<DateTime> starts,
  ) {
    final lengths = <int>[];
    for (var i = 0; i < starts.length - 1; i++) {
      final next = starts[i + 1];
      final ovulation = _detectOvulation(
        readings,
        starts[i],
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
