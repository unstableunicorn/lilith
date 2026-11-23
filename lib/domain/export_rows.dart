// What an export covers: the span the user picked and one row per day that
// has anything logged, merging the reading, period start and daily log.

import 'package:collection/collection.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:meta/meta.dart';

/// How far back an export reaches from today.
enum ExportRange {
  threeMonths(3, 'Last 3 months'),
  sixMonths(6, 'Last 6 months'),
  year(12, 'Last 12 months'),
  all(null, 'Everything');

  ExportRange(this.months, this.label);

  final int? months;
  final String label;

  /// The first day included, or null when every day is.
  DateTime? since(DateTime today) {
    final months = this.months;
    if (months == null) return null;
    final day = dateOnly(today);
    return DateTime(day.year, day.month - months, day.day);
  }
}

/// Everything logged for one day. At least one field is set.
@immutable
class ExportRow {
  ExportRow({
    required DateTime date,
    this.reading,
    this.periodStart = false,
    this.periodDay = false,
    this.periodEnd = false,
    this.log,
  }) : date = dateOnly(date);

  final DateTime date;
  final TemperatureReading? reading;

  /// The first day of a period.
  final bool periodStart;

  /// A known day of a period, first and last included.
  final bool periodDay;

  /// The known last day of a period.
  final bool periodEnd;
  final DailyLog? log;

  @override
  bool operator ==(Object other) =>
      other is ExportRow &&
      other.date == date &&
      other.reading == reading &&
      other.periodStart == periodStart &&
      other.periodDay == periodDay &&
      other.periodEnd == periodEnd &&
      other.log == log;

  @override
  int get hashCode =>
      Object.hash(date, reading, periodStart, periodDay, periodEnd, log);
}

/// One row per day with anything logged from [range]'s start, oldest first.
List<ExportRow> exportRows(
  HealthData data, {
  required ExportRange range,
  required DateTime today,
}) {
  final since = range.since(today);
  bool included(DateTime day) => since == null || !day.isBefore(since);
  final periodDays = <DateTime>{
    for (final p in data.periods)
      for (var d = p.startDate; !d.isAfter(p.lastKnownDay); d = addDays(d, 1))
        d,
  };
  final days = <DateTime>{
    ...data.readings.map((r) => r.date),
    ...periodDays,
    ...data.dailyLogs.map((l) => l.date),
  }.where(included).sorted();
  final readings = {for (final r in data.readings) r.date: r};
  final starts = data.periods.map((p) => p.startDate).toSet();
  final ends = {for (final p in data.periods) ?p.endDate};
  final logs = {for (final l in data.dailyLogs) l.date: l};
  return [
    for (final day in days)
      ExportRow(
        date: day,
        reading: readings[day],
        periodStart: starts.contains(day),
        periodDay: periodDays.contains(day),
        periodEnd: ends.contains(day),
        log: logs[day],
      ),
  ];
}
