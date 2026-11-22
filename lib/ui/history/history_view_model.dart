// What the history screen decides: the cycles, days and readings, newest
// first, and the slice of readings the chart draws.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/temperature_reading.dart';

/// One cycle: when it started and how long it ran, null while it is current.
class CycleEntry {
  const CycleEntry({required this.start, this.length});

  final DateTime start;
  final int? length;
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
    final starts = _repo.data.periods.map((p) => p.startDate).toList();
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
