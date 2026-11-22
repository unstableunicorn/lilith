// What the read-only view of one sharer decides: the prediction and numbers
// from their data, the lists newest first, and what to say when it fails.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/history/history_view_model.dart';

class SharedPersonViewModel extends ChangeNotifier {
  SharedPersonViewModel(
    this._repo,
    this.share, {
    required this.now,
    this.predictor = const CyclePredictor(),
  }) {
    _repo.addListener(notifyListeners);
  }

  final ReceivedShareRepository _repo;
  final ReceivedShare share;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final CyclePredictor predictor;

  DateTime get today => dateOnly(now());
  SharedView get view => _repo.viewOf(share);

  /// Their data once fetched, else null.
  HealthData? get data => switch (view) {
    SharedViewReady(:final data) => data,
    _ => null,
  };

  bool get isLoading => view is SharedViewLoading;
  bool get hasData => data?.hasData ?? false;

  CyclePrediction? get prediction => switch (data) {
    final d? => predictor.predict(
      readings: d.readings,
      periods: d.periods,
      today: today,
    ),
    null => null,
  };

  /// "Period expected today", "… in 4 days, around 12 Jun", or null.
  String? get nextPeriodText {
    final p = prediction;
    final date = p?.predictedNextPeriod;
    final days = p?.daysUntilNextPeriod(today);
    if (p == null || date == null || days == null) return null;
    final when = formatShortDate(date, today: today);
    return switch (days) {
      0 => 'Period expected today',
      1 => 'Period expected tomorrow',
      < 0 => 'Period was expected ${-days} days ago, on $when',
      _ => 'Period expected in $days days, around $when',
    };
  }

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

  List<DailyLog> get days => data?.dailyLogs.reversed.toList() ?? const [];

  /// The newest readings, oldest first, as many as the chart shows.
  List<TemperatureReading> get chartReadings {
    final all = data?.readings ?? const [];
    return all.length > HistoryViewModel.chartWindow
        ? all.sublist(all.length - HistoryViewModel.chartWindow)
        : all;
  }

  Set<DateTime> get periodStarts =>
      data?.periods.map((p) => p.startDate).toSet() ?? const {};

  Future<void> refresh() => _repo.refresh(share);

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
