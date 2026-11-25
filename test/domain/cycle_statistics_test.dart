import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/cycle_statistics.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_event.dart';

void main() {
  final first = DateTime(2026);
  final today = DateTime(2026, 12, 31);

  /// Periods starting [gaps] days apart, five days long unless [lengths]
  /// says; the last start is the current cycle.
  List<PeriodEvent> periods(List<int> gaps, {List<int>? lengths}) {
    final starts = [first];
    for (final g in gaps) {
      starts.add(addDays(starts.last, g));
    }
    return [
      for (var i = 0; i < starts.length; i++)
        PeriodEvent(
          startDate: starts[i],
          endDate: addDays(starts[i], (lengths?[i] ?? 5) - 1),
        ),
    ];
  }

  test('needs two finished cycles', () {
    expect(cycleStatisticsFor(const [], today: today), isNull);
    expect(cycleStatisticsFor(periods([28]), today: today), isNull);
    expect(cycleStatisticsFor(periods([28, 30]), today: today), isNotNull);
  });

  test('gives the shortest, longest, average and spread of cycles', () {
    final s = cycleStatisticsFor(periods([26, 28, 30]), today: today)!;
    expect(
      (
        count: s.cycleCount,
        shortest: s.shortestCycle,
        longest: s.longestCycle,
        average: s.averageCycle,
      ),
      (count: 3, shortest: 26, longest: 30, average: 28.0),
    );
    expect(s.cycleSpread, closeTo(2.0, 1e-9));
  });

  test('counts every cycle, however unlikely its length', () {
    final s = cycleStatisticsFor(periods([8, 95]), today: today)!;
    expect(
      (shortest: s.shortestCycle, longest: s.longestCycle),
      (shortest: 8, longest: 95),
    );
  });

  test('the period range uses periods with a known end', () {
    final s = cycleStatisticsFor(
      periods([28, 28], lengths: [4, 6, 7]),
      today: today,
    )!;
    expect(
      (shortest: s.shortestPeriod, longest: s.longestPeriod),
      (shortest: 4, longest: 7),
    );
  });

  test('a period still going is left out of the period range', () {
    final s = cycleStatisticsFor([
      ...periods([28, 28]),
      PeriodEvent(startDate: addDays(today, -9), endDate: today),
    ], today: today)!;
    expect(s.longestPeriod, 5);
  });

  test('with no period end known there is no period range', () {
    final s = cycleStatisticsFor([
      PeriodEvent(startDate: first),
      PeriodEvent(startDate: addDays(first, 28)),
      PeriodEvent(startDate: addDays(first, 56)),
    ], today: today)!;
    expect(
      (shortest: s.shortestPeriod, longest: s.longestPeriod),
      (shortest: null, longest: null),
    );
  });

  final flagCases = [
    (name: 'all usual', gaps: [26, 30], length: 5, want: <StatisticFlag>{}),
    (
      name: 'a period over 7 days',
      gaps: [28, 28],
      length: 8,
      want: {StatisticFlag.longPeriod},
    ),
    (
      name: 'a cycle under 21 days',
      gaps: [20, 28],
      length: 5,
      want: {StatisticFlag.shortCycle},
    ),
    (
      name: 'a cycle over 35 days',
      gaps: [28, 36],
      length: 5,
      want: {StatisticFlag.longCycle},
    ),
    (
      name: 'the edges are usual',
      gaps: [21, 35],
      length: 7,
      want: <StatisticFlag>{},
    ),
  ];
  for (final c in flagCases) {
    test('flags: ${c.name}', () {
      final s = cycleStatisticsFor(
        periods(
          c.gaps,
          lengths: [
            for (final _ in [0, ...c.gaps]) c.length,
          ],
        ),
        today: today,
      )!;
      expect(s.flags, c.want);
    });
  }
}
