// What a list of days says about the pill, patch or ring: each day's
// verdict and its line, and the missed days that have no log of their own.

import 'package:collection/collection.dart';
import 'package:lilith/data/export/csv_export.dart' show clockTime;
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/log/log_summary.dart';

/// A schedule or a dose marked done: the dose lines apply.
bool tracksDoses(HealthData data) =>
    data.profile.contraceptionSchedule != null ||
    data.dailyLogs.any((l) => l.contraceptionDoneAt != null);

/// How [day]'s dose went, as of [now]; null when there is no verdict.
DoseStatus? doseStatusIn(
  HealthData data,
  DateTime day, {
  required DateTime now,
}) => doseStatus(
  schedule: data.profile.contraceptionSchedule,
  day: day,
  doneAt: data.logFor(dateOnly(day))?.contraceptionDoneAt,
  now: now,
);

/// E.g. "Pill taken 09:12", "Pill taken late, 14:03", "Pill missed";
/// null when there is no verdict.
String? doseSummary(HealthData data, DateTime day, {required DateTime now}) {
  final status = doseStatusIn(data, day, now: now);
  if (status == null) return null;
  final (noun, verb) = switch (data.profile.contraceptionSchedule?.form) {
    DoseForm.pill => ('Pill', 'taken'),
    DoseForm.patch => ('Patch', 'done'),
    DoseForm.ring => ('Ring', 'done'),
    null when data.profile.contraception == Contraception.patchOrRing => (
      'Patch or ring',
      'done',
    ),
    null => ('Pill', 'taken'),
  };
  final at = data.logFor(dateOnly(day))?.contraceptionDoneAt;
  final time = at == null ? '' : clockTime(at);
  return switch (status) {
    DoseStatus.taken => '$noun $verb $time',
    DoseStatus.late => '$noun $verb late, $time',
    DoseStatus.missed => '$noun missed',
  };
}

/// What a day's tile says above its dose line; null when the day holds
/// nothing but its dose.
String? daySummaryLine(
  HealthData data,
  DailyLog log, {
  required DateTime now,
}) =>
    doseSummary(data, log.date, now: now) != null &&
        log.copyWith(clearContraceptionDone: true, clearNote: true).isEmpty
    ? null
    : logSummary(log);

/// The daily logs, oldest first, with an empty one for each missed day
/// nothing was logged on, so it can be listed.
List<DailyLog> logsWithMissedDoses(HealthData data, {required DateTime now}) {
  final logs = data.dailyLogs;
  final s = data.profile.contraceptionSchedule;
  if (s == null) return logs;
  final logged = logs.map((l) => l.date).toSet();
  final today = dateOnly(now);
  return [
    ...logs,
    for (var d = s.start; !d.isAfter(today); d = addDays(d, 1))
      if (!logged.contains(d) &&
          doseStatus(schedule: s, day: d, doneAt: null, now: now) ==
              DoseStatus.missed)
        DailyLog(date: d),
  ].sortedBy((l) => l.date);
}
