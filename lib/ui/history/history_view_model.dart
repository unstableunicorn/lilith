// What the history screen decides: the cycles, days and readings, newest
// first, and the slice of readings the chart draws.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/calendar.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';
import 'package:lilith/ui/components/trend_chart.dart';

/// One cycle: when it started and how long it ran, null while it is current.
class CycleEntry {
  const CycleEntry({
    required this.start,
    this.length,
    this.end,
    this.periodLength,
    this.flow,
    this.days = const [],
    this.readings = const [],
  });

  final DateTime start;

  /// Days to the next start; null while the cycle is current.
  final int? length;

  /// The period's last day and length, when known, and its flow when said.
  final DateTime? end;
  final int? periodLength;
  final FlowIntensity? flow;

  /// What was logged in this cycle, newest first.
  final List<DailyLog> days;
  final List<TemperatureReading> readings;
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

  /// The cycles newest first, each with the days and readings logged from
  /// its start up to the next start.
  List<CycleEntry> get cycles {
    final periods = _repo.data.periods;
    final data = _repo.data;
    bool within(DateTime d, int i) =>
        !d.isBefore(periods[i].startDate) &&
        (i + 1 >= periods.length || d.isBefore(periods[i + 1].startDate));
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
          days: data.dailyLogs
              .where((l) => within(l.date, i))
              .toList()
              .reversed
              .toList(),
          readings: data.readings
              .where((r) => within(r.date, i))
              .toList()
              .reversed
              .toList(),
        ),
    ];
  }

  /// Logged before the first period start, newest first, or everything
  /// when there is no period yet.
  List<DailyLog> get daysBeforeFirstPeriod =>
      _before(_repo.data.dailyLogs, (l) => l.date);

  List<TemperatureReading> get readingsBeforeFirstPeriod =>
      _before(_repo.data.readings, (r) => r.date);

  List<T> _before<T>(List<T> items, DateTime Function(T) dateOf) {
    final first = _repo.data.periods.firstOrNull?.startDate;
    return items
        .where((x) => first == null || dateOf(x).isBefore(first))
        .toList()
        .reversed
        .toList();
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

  /// The newest [chartWindow] wearable nights, oldest first.
  List<WearableNight> get chartNights {
    final all = _repo.data.wearableNights;
    return all.length > chartWindow
        ? all.sublist(all.length - chartWindow)
        : all;
  }

  /// [chartNights] relative to their own mean, so the chart sits around zero.
  List<WearableNight> get nightsFromAverage =>
      nightsRelativeToMean(chartNights);

  /// The known days of each period, for the chart's shading.
  List<ChartSpan> get periodSpans => chartSpansFor(_repo.data.periods);

  /// From the estimated ovulation to the predicted period, when the
  /// temperature shift gave one.
  ChartSpan? get lutealSpan => lutealSpanFor(prediction);

  CyclePrediction get prediction => predictor.predict(
    readings: _repo.data.readings,
    periods: _repo.data.periods,
    today: today,
    nights: _repo.data.wearableNights,
    usualCycleLength: _repo.data.profile.usualCycleLength,
    suppressShift: _repo.data.profile.usesHormonalContraception,
  );

  DateTime? _month;

  /// The month the calendar shows: this month until moved.
  DateTime get month => _month ?? DateTime(today.year, today.month);

  void previousMonth() => _showMonth(DateTime(month.year, month.month - 1));

  void nextMonth() => _showMonth(DateTime(month.year, month.month + 1));

  void _showMonth(DateTime m) {
    _month = m;
    notifyListeners();
  }

  /// The month's days, with the fertile window marked unless [mode] hides it.
  List<CalendarDay> calendarDaysFor(FertileWindowMode mode) => calendarMonth(
    _repo.data,
    _repo.data.hasData ? prediction : null,
    year: month.year,
    month: month.month,
    fertileWindow: mode == FertileWindowMode.hidden ? null : fertileWindow,
  );

  /// This cycle's fertile window, when a shift or a positive test dates it.
  FertileWindow? get fertileWindow => fertileWindowFor(
    prediction,
    _repo.data.dailyLogs,
    hormonalContraception: _repo.data.profile.usesHormonalContraception,
  );

  int get calendarLeadingBlanks =>
      leadingBlanks(year: month.year, month: month.month);

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

/// Each night less the mean of them all, rounded to the hundredth; empty in,
/// empty out.
List<WearableNight> nightsRelativeToMean(List<WearableNight> nights) {
  if (nights.isEmpty) return const [];
  final mean =
      nights.map((n) => n.celsius).reduce((a, b) => a + b) / nights.length;
  return [
    for (final n in nights)
      WearableNight(
        date: n.date,
        celsius: ((n.celsius - mean) * 100).round() / 100,
        source: n.source,
      ),
  ];
}
