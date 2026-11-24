// What a calendar month shows per day: the logged period, the predicted one,
// the estimated ovulation, the fertile window when shown, a positive
// ovulation test and whether anything was logged.

import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:meta/meta.dart';

/// When the prediction has no period length to go on.
const int defaultPredictedPeriodDays = 5;

@immutable
class CalendarDay {
  const CalendarDay({
    required this.date,
    this.inPeriod = false,
    this.predictedPeriod = false,
    this.ovulation = false,
    this.fertile = false,
    this.positiveTest = false,
    this.logged = false,
  });

  final DateTime date;
  final bool inPeriod;
  final bool predictedPeriod;
  final bool ovulation;
  final bool fertile;
  final bool positiveTest;
  final bool logged;
}

/// One entry per day of the month, oldest first. A day inside a logged
/// period is never also marked as predicted. [fertileWindow] is marked only
/// when given, so the caller decides whether it shows.
List<CalendarDay> calendarMonth(
  HealthData data,
  CyclePrediction? prediction, {
  required int year,
  required int month,
  FertileWindow? fertileWindow,
}) {
  final count = DateTime(year, month + 1, 0).day;
  final logged = {
    ...data.dailyLogs.map((l) => l.date),
    ...data.readings.map((r) => r.date),
    ...data.wearableNights.map((n) => n.date),
  };
  final positive = {
    for (final l in data.dailyLogs)
      if (l.ovulationTest == OvulationTest.positive) l.date,
  };
  final predicted = _predictedDays(prediction, data);
  final ovulation = prediction?.estimatedOvulation;
  return [
    for (var d = 1; d <= count; d++)
      () {
        final date = DateTime(year, month, d);
        final inPeriod = data.periods.any((p) => p.contains(date));
        return CalendarDay(
          date: date,
          inPeriod: inPeriod,
          predictedPeriod: !inPeriod && predicted.contains(date),
          ovulation: ovulation != null && dateOnly(ovulation) == date,
          fertile: fertileWindow?.contains(date) ?? false,
          positiveTest: positive.contains(date),
          logged: logged.contains(date),
        );
      }(),
  ];
}

Set<DateTime> _predictedDays(CyclePrediction? prediction, HealthData data) {
  final start = prediction?.predictedNextPeriod;
  if (start == null) return const {};
  final length =
      prediction!.averagePeriodLength?.round() ??
      data.profile.usualPeriodLength ??
      defaultPredictedPeriodDays;
  return {for (var i = 0; i < length; i++) addDays(dateOnly(start), i)};
}

/// Empty cells before the 1st in a grid whose week starts on Monday.
int leadingBlanks({required int year, required int month}) =>
    DateTime(year, month).weekday - DateTime.monday;
