// Forecast likely symptoms and pain from the user's own logged history.
//
// Each logged day is placed on its cycle day (days since the period start
// before it). For the days ahead, the logs on the same cycle day, give or
// take one, say how often each symptom appeared and how bad the pain was.

import 'package:lillith/domain/daily_log.dart';
import 'package:lillith/domain/day.dart';
import 'package:lillith/domain/period_event.dart';

/// How often [symptom] appeared at this point of past cycles.
class SymptomLikelihood {
  const SymptomLikelihood({
    required this.symptom,
    required this.probability,
    required this.occurrences,
    required this.sampleDays,
  });

  final Symptom symptom;

  /// 0.0–1.0 share of the matching past days that carried the symptom.
  final double probability;

  /// Matching past days that carried the symptom.
  final int occurrences;

  /// Matching past days consulted.
  final int sampleDays;

  int get percent => (probability * 100).round();
}

/// The outcome of [SymptomPredictor.predict].
class SymptomForecast {
  const SymptomForecast({
    required this.likely,
    required this.loggedDays,
    this.typicalPain,
  });

  /// Symptoms likely in the window, most likely first.
  final List<SymptomLikelihood> likely;

  /// Mean 0–10 pain rating over the matching past days, when any was rated.
  final double? typicalPain;

  /// Days the user has logged in total.
  final int loggedDays;

  bool get hasData => likely.isNotEmpty || typicalPain != null;
}

/// Pure forecast over daily logs and period starts.
class SymptomPredictor {
  const SymptomPredictor({this.windowDays = 7, this.minProbability = 0.34});

  /// How many days ahead, starting today, to look at.
  final int windowDays;

  /// The least frequency a symptom needs to be reported.
  final double minProbability;

  /// Fewest logged days before any pattern is reported.
  static const int minLogs = 3;

  SymptomForecast predict({
    required List<DailyLog> logs,
    required List<PeriodEvent> periods,
    required DateTime today,
  }) {
    final empty = SymptomForecast(likely: const [], loggedDays: logs.length);
    final starts = periods.map((p) => p.startDate).toList()..sort();
    if (starts.isEmpty || logs.length < minLogs) return empty;

    final byCycleDay = <int, List<DailyLog>>{};
    for (final log in logs) {
      final day = _cycleDayOf(log.date, starts);
      if (day != null) byCycleDay.putIfAbsent(day, () => []).add(log);
    }
    if (byCycleDay.isEmpty) return empty;

    final currentCycleDay = daysBetween(starts.last, dateOnly(today)) + 1;
    final best = <Symptom, SymptomLikelihood>{};
    final consulted = <DailyLog>{};
    for (var offset = 0; offset < windowDays; offset++) {
      final day = currentCycleDay + offset;
      final bucket = [
        ...?byCycleDay[day - 1],
        ...?byCycleDay[day],
        ...?byCycleDay[day + 1],
      ];
      if (bucket.isEmpty) continue;
      consulted.addAll(bucket);
      for (final symptom in Symptom.values) {
        final occurrences = bucket
            .where((l) => l.symptoms.contains(symptom))
            .length;
        final probability = occurrences / bucket.length;
        if (probability > (best[symptom]?.probability ?? -1)) {
          best[symptom] = SymptomLikelihood(
            symptom: symptom,
            probability: probability,
            occurrences: occurrences,
            sampleDays: bucket.length,
          );
        }
      }
    }

    final likely =
        best.values
            .where((l) => l.probability >= minProbability && l.occurrences > 0)
            .toList()
          ..sort((a, b) => b.probability.compareTo(a.probability));
    final pains = [for (final l in consulted) ?l.painLevel];
    return SymptomForecast(
      likely: likely,
      loggedDays: logs.length,
      typicalPain: pains.isEmpty
          ? null
          : pains.reduce((a, b) => a + b) / pains.length,
    );
  }

  /// 1 + days since the latest start on or before [date]; null before all starts.
  int? _cycleDayOf(DateTime date, List<DateTime> sortedStarts) {
    DateTime? start;
    for (final s in sortedStarts) {
      if (s.isAfter(date)) break;
      start = s;
    }
    return start == null ? null : daysBetween(start, date) + 1;
  }
}
