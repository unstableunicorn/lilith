// What the history screen decides: the cycles, days and readings, newest
// first, and the slice of readings the chart draws.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/temperature_reading.dart';

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
  HistoryViewModel(this._repo) {
    _repo.addListener(notifyListeners);
  }

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

  Set<DateTime> get periodStarts =>
      _repo.data.periods.map((p) => p.startDate).toSet();

  Future<void> removeReading(DateTime date) =>
      _repo.apply((d) => d.withoutReading(date));

  Future<void> removePeriod(DateTime date) =>
      _repo.apply((d) => d.withoutPeriod(date));

  void clearError() => _repo.clearError();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
