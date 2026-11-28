// Cycle and period length statistics over every finished cycle, and which
// of them fall outside the usual ranges.

import 'dart:math' as math;

import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:meta/meta.dart';

/// A figure outside the usual range, worth mentioning to a doctor.
enum StatisticFlag { longPeriod, shortCycle, longCycle }

/// Usual ranges, from ACOG's abnormal uterine bleeding FAQ.
const int usualShortestCycle = 21;
const int usualLongestCycle = 35;
const int usualLongestPeriod = 7;

@immutable
class CycleStatistics {
  const CycleStatistics({
    required this.cycleCount,
    required this.shortestCycle,
    required this.longestCycle,
    required this.averageCycle,
    required this.cycleSpread,
    this.shortestPeriod,
    this.longestPeriod,
  });

  final int cycleCount;
  final int shortestCycle;
  final int longestCycle;
  final double averageCycle;

  /// Sample standard deviation of the cycle lengths, in days.
  final double cycleSpread;

  /// Over periods whose end is known and that are not still going.
  final int? shortestPeriod;
  final int? longestPeriod;

  Set<StatisticFlag> get flags => {
    if ((longestPeriod ?? 0) > usualLongestPeriod) StatisticFlag.longPeriod,
    if (shortestCycle < usualShortestCycle) StatisticFlag.shortCycle,
    if (longestCycle > usualLongestCycle) StatisticFlag.longCycle,
  };
}

/// Statistics over the finished cycles in [periods]; null with fewer than
/// two. Every cycle counts, however unlikely its length, but one that
/// overlaps a life factor in [factors].
CycleStatistics? cycleStatisticsFor(
  List<PeriodEvent> periods, {
  required DateTime today,
  List<LifeFactor> factors = const [],
}) {
  final sorted = [...periods]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final cycles = [
    for (var i = 1; i < sorted.length; i++)
      if (!cycleOverlapsFactor(
        sorted[i - 1].startDate,
        sorted[i].startDate,
        factors,
      ))
        daysBetween(sorted[i - 1].startDate, sorted[i].startDate),
  ];
  if (cycles.length < 2) return null;
  final mean = cycles.reduce((a, b) => a + b) / cycles.length;
  final variance =
      cycles.map((c) => (c - mean) * (c - mean)).reduce((a, b) => a + b) /
      (cycles.length - 1);
  final periodLengths = [
    for (final p in sorted)
      if (p.lengthDays case final n? when !p.inProgressOn(today)) n,
  ];
  return CycleStatistics(
    cycleCount: cycles.length,
    shortestCycle: cycles.reduce(math.min),
    longestCycle: cycles.reduce(math.max),
    averageCycle: mean,
    cycleSpread: math.sqrt(variance),
    shortestPeriod: periodLengths.isEmpty
        ? null
        : periodLengths.reduce(math.min),
    longestPeriod: periodLengths.isEmpty
        ? null
        : periodLengths.reduce(math.max),
  );
}
