// What a "phases only" share holds: the period days, and the dates the
// sharer's app worked out from everything else. No temperature, test, flow,
// symptom or note leaves the sharer's pod in it.

import 'package:lilith/domain/calendar.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:meta/meta.dart';

@immutable
class SharedPhases {
  SharedPhases({
    required DateTime updatedOn,
    Iterable<PeriodEvent> periods = const [],
    DateTime? nextPeriod,
    this.predictedDays = defaultPredictedPeriodDays,
    DateTime? ovulation,
    this.fertileWindow,
    this.fertileMode = FertileWindowMode.hidden,
    this.paused = false,
  }) : updatedOn = dateOnly(updatedOn),
       periods = List.unmodifiable(periods),
       nextPeriod = nextPeriod == null ? null : dateOnly(nextPeriod),
       ovulation = ovulation == null ? null : dateOnly(ovulation);

  factory SharedPhases.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.parse(v) : null;
    final window = json['fertileWindow'];
    return SharedPhases(
      updatedOn: DateTime.parse(json['updatedOn'] as String),
      periods: [
        for (final p in json['periods'] as List<dynamic>? ?? const [])
          PeriodEvent.fromJson(p as Map<String, dynamic>),
      ],
      nextPeriod: date(json['nextPeriod']),
      predictedDays:
          (json['predictedDays'] as num?)?.toInt() ??
          defaultPredictedPeriodDays,
      ovulation: date(json['ovulation']),
      fertileWindow: window is Map<String, dynamic>
          ? FertileWindow(
              start: DateTime.parse(window['start'] as String),
              end: DateTime.parse(window['end'] as String),
              basis: FertileWindowBasis.values.firstWhere(
                (b) => b.name == window['basis'],
                orElse: () => FertileWindowBasis.shift,
              ),
            )
          : null,
      fertileMode: FertileWindowMode.values.firstWhere(
        (m) => m.name == json['fertileMode'],
        orElse: () => FertileWindowMode.hidden,
      ),
      paused: json['paused'] == true,
    );
  }

  /// Marks the copy as this kind, not a health document.
  static const String kind = 'phases';

  /// The day the sharer's app last wrote it.
  final DateTime updatedOn;

  /// Each period's days only: no flow.
  final List<PeriodEvent> periods;
  final DateTime? nextPeriod;

  /// How many days the predicted period is marked for.
  final int predictedDays;
  final DateTime? ovulation;

  /// Present only when the sharer shows the window themselves.
  final FertileWindow? fertileWindow;

  /// The sharer's own setting, which picks the disclaimer.
  final FertileWindowMode fertileMode;

  /// True while a life factor holds the sharer's predictions; which one is
  /// not said.
  final bool paused;

  /// Something to show: at least one period.
  bool get hasData => periods.isNotEmpty;

  /// The day of the cycle on [today], counting the last period's start as 1.
  int? cycleDayOn(DateTime today) => switch (periods.lastOrNull) {
    final p? => daysBetween(p.startDate, dateOnly(today)) + 1,
    null => null,
  };

  /// One entry per day of the month, oldest first. A day inside a period is
  /// never also marked as predicted.
  List<CalendarDay> month({required int year, required int month}) {
    final next = nextPeriod;
    final predicted = {
      if (next != null)
        for (var i = 0; i < predictedDays; i++) addDays(next, i),
    };
    final count = DateTime(year, month + 1, 0).day;
    return [
      for (var d = 1; d <= count; d++)
        () {
          final date = DateTime(year, month, d);
          final inPeriod = periods.any((p) => p.contains(date));
          return CalendarDay(
            date: date,
            inPeriod: inPeriod,
            predictedPeriod: !inPeriod && predicted.contains(date),
            ovulation: ovulation == date,
            fertile: fertileWindow?.contains(date) ?? false,
          );
        }(),
    ];
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'updatedOn': updatedOn.toIso8601String(),
    'periods': [for (final p in periods) p.toJson()],
    if (nextPeriod != null) 'nextPeriod': nextPeriod!.toIso8601String(),
    'predictedDays': predictedDays,
    if (ovulation != null) 'ovulation': ovulation!.toIso8601String(),
    if (fertileWindow case final w?)
      'fertileWindow': {
        'start': w.start.toIso8601String(),
        'end': w.end.toIso8601String(),
        'basis': w.basis.name,
      },
    'fertileMode': fertileMode.name,
    if (paused) 'paused': true,
  };

  @override
  bool operator ==(Object other) =>
      other is SharedPhases &&
      other.updatedOn == updatedOn &&
      _samePeriods(other.periods, periods) &&
      other.nextPeriod == nextPeriod &&
      other.predictedDays == predictedDays &&
      other.ovulation == ovulation &&
      other.fertileWindow?.start == fertileWindow?.start &&
      other.fertileWindow?.end == fertileWindow?.end &&
      other.fertileWindow?.basis == fertileWindow?.basis &&
      other.fertileMode == fertileMode &&
      other.paused == paused;

  @override
  int get hashCode => Object.hash(
    updatedOn,
    Object.hashAll(periods),
    nextPeriod,
    predictedDays,
    ovulation,
    fertileWindow?.start,
    fertileWindow?.end,
    fertileMode,
    paused,
  );

  static bool _samePeriods(List<PeriodEvent> a, List<PeriodEvent> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// True when [json] is a phases copy.
bool isPhasesJson(Map<String, dynamic> json) =>
    json['kind'] == SharedPhases.kind;

/// The phases [data] shows on [today], worked out as the sharer's own app
/// does, with the fertile window only when [fertileWindowMode] shows it.
SharedPhases sharedPhases(
  HealthData data, {
  required DateTime today,
  required FertileWindowMode fertileWindowMode,
  CyclePredictor predictor = const CyclePredictor(),
}) {
  final hormonal = data.profile.usesHormonalContraception;
  final prediction = predictor.predict(
    readings: data.readings,
    periods: data.periods,
    today: today,
    nights: data.wearableNights,
    usualCycleLength: data.profile.usualCycleLength,
    suppressShift: hormonal,
    factors: data.profile.lifeFactors,
  );
  return SharedPhases(
    updatedOn: today,
    periods: [for (final p in data.periods) p.copyWith(clearFlow: true)],
    nextPeriod: prediction.predictedNextPeriod,
    predictedDays:
        prediction.averagePeriodLength?.round() ??
        data.profile.usualPeriodLength ??
        defaultPredictedPeriodDays,
    ovulation: prediction.estimatedOvulation,
    fertileWindow: fertileWindowMode == FertileWindowMode.hidden
        ? null
        : fertileWindowFor(
            prediction,
            data.dailyLogs,
            hormonalContraception: hormonal,
          ),
    fertileMode: fertileWindowMode,
    paused: prediction.isOnHold,
  );
}
