// What the history screen decides: the cycles, days and readings, newest
// first, and the slice of readings the chart draws.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/components/trend_chart.dart';

/// One cycle: when it started and how long it ran, null while it is current.
class CycleEntry {
  const CycleEntry({
    required this.start,
    this.length,
    this.end,
    this.periodLength,
    this.flow,
  });

  final DateTime start;

  /// Days to the next start; null while the cycle is current.
  final int? length;

  /// The period's last day and length, when known, and its flow when said.
  final DateTime? end;
  final int? periodLength;
  final FlowIntensity? flow;
}

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(
    this._repo, {
    this.now = DateTime.now,
    this.predictor = const CyclePredictor(),
  }) {
    _repo.addListener(notifyListeners);
  }

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final CyclePredictor predictor;

  DateTime get today => dateOnly(now());

  /// How many readings the chart shows at most.
  static const int chartWindow = 60;

  final HealthRepository _repo;

  bool get isLoaded => _repo.isLoaded;
  RepositoryError? get error => _repo.error;
  bool get hasHistory => _repo.data.hasData;

  List<CycleEntry> get cycles {
    final periods = _repo.data.periods;
    return [
      for (var i = periods.length - 1; i >= 0; i--)
        CycleEntry(
          start: periods[i].startDate,
          length: i + 1 < periods.length
              ? daysBetween(periods[i].startDate, periods[i + 1].startDate)
              : null,
          end: periods[i].endDate,
          periodLength: periods[i].lengthDays,
          flow: periods[i].flow,
        ),
    ];
  }

  /// "Current cycle" or "28 days", then the period's span and flow when known:
  /// "28 days · period 5 days, medium".
  static String cycleText(CycleEntry c) {
    final cycle = c.length == null ? 'Current cycle' : '${c.length} days';
    final parts = [
      if (c.periodLength case final n?) 'period $n ${n == 1 ? 'day' : 'days'}',
      if (c.flow case final f?) f.name,
    ];
    return parts.isEmpty ? cycle : '$cycle · ${parts.join(', ')}';
  }

  /// The period starting on [start], for editing.
  PeriodEvent? periodStarting(DateTime start) =>
      _repo.data.periods.firstWhereOrNull((p) => p.startDate == start);

  List<TemperatureReading> get readings =>
      _repo.data.readings.reversed.toList();

  List<DailyLog> get days => _repo.data.dailyLogs.reversed.toList();

  /// The newest [chartWindow] readings, oldest first.
  List<TemperatureReading> get chartReadings {
    final all = _repo.data.readings;
    return all.length > chartWindow
        ? all.sublist(all.length - chartWindow)
        : all;
  }

  /// The known days of each period, for the chart's shading.
  List<ChartSpan> get periodSpans => chartSpansFor(_repo.data.periods);

  /// From the estimated ovulation to the predicted period, when the
  /// temperature shift gave one.
  ChartSpan? get lutealSpan => lutealSpanFor(
    predictor.predict(
      readings: _repo.data.readings,
      periods: _repo.data.periods,
      today: today,
      usualCycleLength: _repo.data.profile.usualCycleLength,
      suppressShift: _repo.data.profile.usesHormonalContraception,
    ),
  );

  Set<DateTime> get periodStarts =>
      _repo.data.periods.map((p) => p.startDate).toSet();

  Future<void> removeReading(DateTime date) =>
      _repo.apply((d) => d.withoutReading(date));

  /// Records a reading for a past day. False, recording nothing, when the
  /// value is not a plausible body temperature or the day is ahead.
  Future<bool> addReading(DateTime day, double celsius) async {
    final d = dateOnly(day);
    if (!TemperatureReading.isPlausible(celsius) || d.isAfter(today)) {
      return false;
    }
    await _repo.apply(
      (data) => data.withReading(TemperatureReading(date: d, celsius: celsius)),
    );
    return true;
  }

  Future<void> removePeriod(DateTime date) =>
      _repo.apply((d) => d.withoutPeriod(date));

  void clearError() => _repo.clearError();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Every period as a span of its known days.
List<ChartSpan> chartSpansFor(Iterable<PeriodEvent> periods) => [
  for (final p in periods) ChartSpan(start: p.startDate, end: p.lastKnownDay),
];

/// The days after ovulation up to the predicted period, when both are known.
ChartSpan? lutealSpanFor(CyclePrediction p) {
  final ovulation = p.estimatedOvulation;
  final next = p.predictedNextPeriod;
  if (ovulation == null || next == null) return null;
  return ChartSpan(start: addDays(ovulation, 1), end: addDays(next, -1));
}
