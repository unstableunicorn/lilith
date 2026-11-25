// The day of the current cycle and its phase: menstrual while bleeding,
// then follicular up to ovulation and luteal after it.

import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:meta/meta.dart';

enum CyclePhase { menstrual, follicular, luteal }

/// What placed today in its phase.
enum PhaseBasis {
  /// A logged period covers today.
  period,

  /// Ovulation dated from a temperature shift.
  shift,

  /// Ovulation taken as the luteal length before the predicted period.
  calendar,
}

/// Today's place in the cycle. [day] and [phase] are null when unknown.
@immutable
class CycleStatus {
  const CycleStatus({this.day, this.phase, this.basis, this.hormonal = false});

  final int? day;
  final CyclePhase? phase;
  final PhaseBasis? basis;

  /// True on hormonal contraception, where only bleeding gives a phase.
  final bool hormonal;
}

/// Day and phase of [today] from [prediction] and the logged [periods].
/// A late period stays luteal until the next start is logged.
CycleStatus cycleStatusFor(
  CyclePrediction prediction,
  List<PeriodEvent> periods, {
  required DateTime today,
  bool hormonalContraception = false,
}) {
  final latest = periods.isEmpty
      ? null
      : periods.reduce((a, b) => a.startDate.isAfter(b.startDate) ? a : b);
  if (latest == null || latest.startDate.isAfter(dateOnly(today))) {
    return CycleStatus(hormonal: hormonalContraception);
  }
  final day = daysBetween(latest.startDate, today) + 1;
  if (latest.contains(today) || latest.inProgressOn(today)) {
    return CycleStatus(
      day: day,
      phase: CyclePhase.menstrual,
      basis: PhaseBasis.period,
      hormonal: hormonalContraception,
    );
  }
  if (hormonalContraception) return CycleStatus(day: day, hormonal: true);
  final next = prediction.predictedNextPeriod;
  final (ovulation, basis) = switch (prediction.estimatedOvulation) {
    final o? => (o, PhaseBasis.shift),
    null when next != null => (
      addDays(next, -CyclePredictor.defaultLutealLength),
      PhaseBasis.calendar,
    ),
    null => (null, null),
  };
  if (ovulation == null) return CycleStatus(day: day);
  return CycleStatus(
    day: day,
    phase: dateOnly(today).isAfter(ovulation)
        ? CyclePhase.luteal
        : CyclePhase.follicular,
    basis: basis,
  );
}
