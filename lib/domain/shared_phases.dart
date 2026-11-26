// What a "phases only" share holds: the period days, and the dates the
// sharer's app worked out from everything else. No temperature, test, flow,
// symptom or note leaves the sharer's pod in it.

import 'package:lilith/domain/calendar.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:meta/meta.dart';

@immutable
class SharedPhases {
  SharedPhases({
    required this.updatedOn,
    Iterable<PeriodEvent> periods = const [],
    this.nextPeriod,
    this.predictedDays = defaultPredictedPeriodDays,
    this.ovulation,
    this.fertileWindow,
    this.fertileMode = FertileWindowMode.hidden,
  }) : periods = List.unmodifiable(periods);

  factory SharedPhases.fromJson(Map<String, dynamic> json) =>
      SharedPhases(updatedOn: DateTime(2000));

  /// Marks the copy as this kind, not a health document.
  static const String kind = 'phases';

  final DateTime updatedOn;
  final List<PeriodEvent> periods;
  final DateTime? nextPeriod;
  final int predictedDays;
  final DateTime? ovulation;
  final FertileWindow? fertileWindow;
  final FertileWindowMode fertileMode;

  /// Something to show: at least one period.
  bool get hasData => periods.isNotEmpty;

  /// The day of the cycle on [today], counting the last period's start as 1.
  int? cycleDayOn(DateTime today) => null;

  /// One entry per day of the month, oldest first.
  List<CalendarDay> month({required int year, required int month}) => [];

  Map<String, dynamic> toJson() => {};
}

/// True when [json] is a phases copy.
bool isPhasesJson(Map<String, dynamic> json) => false;

/// The phases [data] shows on [today], with the fertile window only when
/// [fertileWindowMode] shows it.
SharedPhases sharedPhases(
  HealthData data, {
  required DateTime today,
  required FertileWindowMode fertileWindowMode,
  CyclePredictor predictor = const CyclePredictor(),
}) => SharedPhases(updatedOn: today);
