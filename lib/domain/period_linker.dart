// How a day's logged flow changes the periods: bleeding days join or start
// a period, a dry day on a period's edge shortens it. Pure, so a change can
// be undone by logging the day again.

import 'package:collection/collection.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_event.dart';

/// Bleeding days this close to a period belong to it; further apart they
/// start a new one.
const int maxGapDays = 2;

/// Spotting never starts or extends a period; light flow and up does.
bool bleeds(DailyLog? log) =>
    log != null && log.flow.level >= FlowIntensity.light.level;

/// The periods after the log for [day] changed; [logs] already holds it.
/// Idempotent: linking the same day twice changes nothing more.
List<PeriodEvent> linkPeriods(
  List<PeriodEvent> periods,
  List<DailyLog> logs,
  DateTime day,
) {
  final d = dateOnly(day);
  final byDay = {for (final l in logs) l.date: l};
  final sorted = periods.sortedBy((p) => p.startDate);
  return bleeds(byDay[d])
      ? _withBleeding(sorted, d)
      : _withoutBleeding(sorted, byDay, d);
}

List<PeriodEvent> _withBleeding(List<PeriodEvent> periods, DateTime d) {
  if (periods.any((p) => p.contains(d))) return periods;
  final before = periods.lastWhereOrNull(
    (p) =>
        p.lastKnownDay.isBefore(d) &&
        daysBetween(p.lastKnownDay, d) <= maxGapDays,
  );
  if (before != null) {
    return _replace(periods, before, before.copyWith(endDate: d));
  }
  final after = periods.firstWhereOrNull(
    (p) => p.startDate.isAfter(d) && daysBetween(d, p.startDate) <= maxGapDays,
  );
  if (after != null) {
    return _replace(periods, after, after.copyWith(startDate: d));
  }
  return [
    ...periods,
    PeriodEvent(startDate: d, endDate: d),
  ].sortedBy((p) => p.startDate);
}

List<PeriodEvent> _withoutBleeding(
  List<PeriodEvent> periods,
  Map<DateTime, DailyLog> byDay,
  DateTime d,
) {
  final p = periods.firstWhereOrNull((p) => p.contains(d));
  if (p == null) return periods;
  if (p.lastKnownDay == d) {
    // The end moves back to the last bleeding day; with none left the
    // period is gone if it was this one day, else it keeps its start.
    var end = addDays(d, -1);
    while (!end.isBefore(p.startDate) && !bleeds(byDay[end])) {
      end = addDays(end, -1);
    }
    if (end.isBefore(p.startDate)) {
      return p.startDate == d
          ? periods.where((q) => q != p).toList()
          : _replace(periods, p, p.copyWith(endDate: p.startDate));
    }
    return _replace(periods, p, p.copyWith(endDate: end));
  }
  if (p.startDate == d) {
    // The start moves on to the next bleeding day, else just past this one.
    final last = p.lastKnownDay;
    var start = addDays(d, 1);
    while (!start.isAfter(last) && !bleeds(byDay[start])) {
      start = addDays(start, 1);
    }
    if (start.isAfter(last)) start = addDays(d, 1);
    return _replace(periods, p, p.copyWith(startDate: start));
  }
  return periods;
}

List<PeriodEvent> _replace(
  List<PeriodEvent> periods,
  PeriodEvent old,
  PeriodEvent updated,
) => [
  for (final p in periods)
    if (p == old) updated else p,
];
