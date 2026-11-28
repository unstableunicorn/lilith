// What the read-only view of one sharer decides: the prediction and numbers
// from their data, the lists newest first, and what to say when it fails.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/calendar.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';
import 'package:lilith/domain/symptom_predictor.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/components/trend_chart.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/core/forecast_text.dart' as text;
import 'package:lilith/ui/history/history_view_model.dart';
import 'package:lilith/ui/log/dose_summary.dart' as dose;
import 'package:lilith/ui/log/log_summary.dart';
import 'package:lilith/ui/received/received_view_model.dart';

class SharedPersonViewModel extends ChangeNotifier {
  SharedPersonViewModel(
    this._repo,
    this.share, {
    required this.now,
    this.predictor = const CyclePredictor(),
    this.symptomPredictor = const SymptomPredictor(),
  }) {
    _repo.addListener(notifyListeners);
  }

  final ReceivedShareRepository _repo;
  final ReceivedShare share;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final CyclePredictor predictor;
  final SymptomPredictor symptomPredictor;

  DateTime get today => dateOnly(now());
  SharedView get view => _repo.viewOf(share);

  /// Their data once fetched, else null.
  HealthData? get data => switch (view) {
    SharedViewReady(:final data) => data,
    _ => null,
  };

  /// Their phases, for a "phases only" share; else null.
  SharedPhases? get phases => switch (view) {
    SharedViewPhases(:final phases) => phases,
    _ => null,
  };

  bool get isLoading => view is SharedViewLoading;
  bool get hasData => data?.hasData ?? phases?.hasData ?? false;

  /// True when their copy could not be fetched or read.
  bool get hasProblem => view is SharedViewFailed;

  /// One line about them for a card: their next period, or why there is
  /// none to show.
  String get headline => switch (view) {
    SharedViewLoading() => 'Fetching from their pod',
    SharedViewFailed(error: ReceivedShareError.ended) => 'This share has ended',
    SharedViewFailed(:final error) => describeReceivedError(error),
    _ when !hasData => 'Nothing logged yet',
    _ => nextPeriodText ?? 'Not enough logged yet to predict.',
  };

  /// "Cycle day 12, since 3 Jun", from their phases; null without a period.
  String? get phasesCycleLine {
    final p = phases;
    final start = p?.periods.lastOrNull?.startDate;
    if (p == null || start == null) return null;
    return 'Cycle day ${p.cycleDayOn(today)}, since '
        '${formatShortDate(start, today: today)}';
  }

  /// "Updated today", "Updated 8 Jun": when their app last wrote the copy.
  String? get phasesUpdatedText => switch (phases) {
    final p? => 'Updated ${formatShortDate(p.updatedOn, today: today)}',
    null => null,
  };

  /// The sentence that goes with their ovulation or fertile window.
  String? get phasesDisclaimer => switch (phases) {
    SharedPhases(fertileWindow: _?, :final fertileMode) =>
      fertileWindowDisclaimer(fertileMode),
    SharedPhases(ovulation: _?) => estimateDisclaimer,
    _ => null,
  };

  DateTime? _month;

  /// The month the calendar shows: this month until moved.
  DateTime get month => _month ?? DateTime(today.year, today.month);

  void previousMonth() => _showMonth(DateTime(month.year, month.month - 1));

  void nextMonth() => _showMonth(DateTime(month.year, month.month + 1));

  void _showMonth(DateTime m) {
    _month = m;
    notifyListeners();
  }

  /// The shown month's days, from their phases.
  List<CalendarDay> get phasesDays =>
      phases?.month(year: month.year, month: month.month) ?? const [];

  int get calendarLeadingBlanks =>
      leadingBlanks(year: month.year, month: month.month);

  CyclePrediction? get prediction => switch (data) {
    final d? => predictor.predict(
      readings: d.readings,
      periods: d.periods,
      today: today,
      nights: d.wearableNights,
    ),
    null => null,
  };

  /// "Period expected today", "… in 4 days, around 12 Jun", or null.
  String? get nextPeriodText {
    final date = prediction?.predictedNextPeriod ?? phases?.nextPeriod;
    if (date == null) return null;
    final days = daysBetween(today, dateOnly(date));
    final when = formatShortDate(date, today: today);
    return switch (days) {
      0 => 'Period expected today',
      1 => 'Period expected tomorrow',
      < 0 => 'Period was expected ${-days} days ago, on $when',
      _ => 'Period expected in $days days, around $when',
    };
  }

  /// What their shared days say about the week ahead.
  SymptomForecast get forecast => switch (data) {
    final d? => symptomPredictor.predict(
      logs: d.dailyLogs,
      periods: d.periods,
      today: today,
    ),
    null => const SymptomForecast(likely: [], loggedDays: 0),
  };

  /// The forecast card's sentence; empty with nothing to forecast.
  String get forecastSummary => switch (forecast) {
    final f when f.hasData => text.forecastSummary(f, theirs: true),
    _ => '',
  };

  /// The forecast card's symptom badges.
  List<String> get forecastSymptoms => text.forecastSymptomBadges(forecast);

  /// The forecast card's mood badges; none unless they share their moods.
  List<String> get forecastMoods => text.forecastMoodBadges(forecast);

  TemperatureReading? get latestReading => data?.readings.lastOrNull;

  List<CycleEntry> get cycles {
    final starts = data?.periods.map((p) => p.startDate).toList() ?? const [];
    return [
      for (var i = starts.length - 1; i >= 0; i--)
        CycleEntry(
          start: starts[i],
          length: i + 1 < starts.length
              ? daysBetween(starts[i], starts[i + 1])
              : null,
        ),
    ];
  }

  /// Their days newest first, with each missed dose they share as a day.
  List<DailyLog> get days => switch (data) {
    final d? => dose.logsWithMissedDoses(d, now: now()).reversed.toList(),
    null => const [],
  };

  /// Their dose that day, when they share it; null otherwise.
  String? doseText(DateTime day) => switch (data) {
    final d? => dose.doseSummary(d, day, now: now()),
    null => null,
  };

  /// What a day's tile says above its dose line; null when the day holds
  /// nothing but its dose.
  String? summaryLine(DailyLog log) => switch (data) {
    final d? => dose.daySummaryLine(d, log, now: now()),
    null => logSummary(log),
  };

  /// The newest readings, oldest first, as many as the chart shows.
  List<TemperatureReading> get chartReadings {
    final all = data?.readings ?? const [];
    return all.length > HistoryViewModel.chartWindow
        ? all.sublist(all.length - HistoryViewModel.chartWindow)
        : all;
  }

  List<ChartSpan> get periodSpans => chartSpansFor(data?.periods ?? const []);

  ChartSpan? get lutealSpan => switch (prediction) {
    final p? => lutealSpanFor(p),
    null => null,
  };

  Set<DateTime> get periodStarts =>
      data?.periods.map((p) => p.startDate).toSet() ?? const {};

  Future<void> refresh() => _repo.refresh(share);

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
