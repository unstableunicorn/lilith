import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/cycle_phase.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/period_event.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);

  CyclePrediction predicted({DateTime? ovulation, int nextPeriodDay = 29}) =>
      CyclePrediction(
        method: ovulation == null
            ? PredictionMethod.cycleAverage
            : PredictionMethod.temperatureShift,
        confidence: PredictionConfidence.medium,
        lastPeriodStart: june(1),
        predictedNextPeriod: june(nextPeriodDay),
        estimatedOvulation: ovulation,
        lutealLength: ovulation == null ? null : 14,
      );

  final ended = [PeriodEvent(startDate: june(1), endDate: june(5))];

  final cases = [
    (
      name: 'a bleeding day of the period is menstrual',
      prediction: predicted(),
      periods: ended,
      today: june(3),
      want: (day: 3, phase: CyclePhase.menstrual, basis: PhaseBasis.period),
    ),
    (
      name: 'a period still going is menstrual past its last logged day',
      prediction: predicted(),
      periods: [PeriodEvent(startDate: june(1))],
      today: june(3),
      want: (day: 3, phase: CyclePhase.menstrual, basis: PhaseBasis.period),
    ),
    (
      name: 'after the period and before the calendar ovulation is follicular',
      prediction: predicted(),
      periods: ended,
      today: june(10),
      want: (day: 10, phase: CyclePhase.follicular, basis: PhaseBasis.calendar),
    ),
    (
      name: 'the calendar ovulation day itself is follicular',
      prediction: predicted(),
      periods: ended,
      today: june(15),
      want: (day: 15, phase: CyclePhase.follicular, basis: PhaseBasis.calendar),
    ),
    (
      name: 'the day after the calendar ovulation is luteal',
      prediction: predicted(),
      periods: ended,
      today: june(16),
      want: (day: 16, phase: CyclePhase.luteal, basis: PhaseBasis.calendar),
    ),
    (
      name: 'a temperature shift dates ovulation over the calendar',
      prediction: predicted(ovulation: june(12), nextPeriodDay: 26),
      periods: ended,
      today: june(13),
      want: (day: 13, phase: CyclePhase.luteal, basis: PhaseBasis.shift),
    ),
    (
      name: 'before a shift ovulation it is follicular, dated by the shift',
      prediction: predicted(ovulation: june(18), nextPeriodDay: 32),
      periods: ended,
      today: june(17),
      want: (day: 17, phase: CyclePhase.follicular, basis: PhaseBasis.shift),
    ),
    (
      name: 'a late period stays luteal',
      prediction: predicted(),
      periods: ended,
      today: june(33),
      want: (day: 33, phase: CyclePhase.luteal, basis: PhaseBasis.calendar),
    ),
  ];
  for (final c in cases) {
    test(c.name, () {
      final s = cycleStatusFor(c.prediction, c.periods, today: c.today);
      expect((day: s.day, phase: s.phase, basis: s.basis), c.want);
    });
  }

  test('with no period logged the day and phase are unknown', () {
    final s = cycleStatusFor(
      const CyclePrediction(
        method: PredictionMethod.insufficientData,
        confidence: PredictionConfidence.none,
      ),
      const [],
      today: june(3),
    );
    expect(
      (day: s.day, phase: s.phase, basis: s.basis),
      (day: null, phase: null, basis: null),
    );
  });

  test('a period logged for a later day gives no day yet', () {
    final s = cycleStatusFor(predicted(), [
      PeriodEvent(startDate: june(12)),
    ], today: june(10));
    expect((day: s.day, phase: s.phase), (day: null, phase: null));
  });

  group('on hormonal contraception', () {
    test('a day between bleeds has a day but no phase', () {
      final s = cycleStatusFor(
        predicted(),
        ended,
        today: june(10),
        hormonalContraception: true,
      );
      expect(
        (day: s.day, phase: s.phase, hormonal: s.hormonal),
        (day: 10, phase: null, hormonal: true),
      );
    });

    test('a bleeding day is still menstrual', () {
      final s = cycleStatusFor(
        predicted(),
        ended,
        today: june(2),
        hormonalContraception: true,
      );
      expect(s.phase, CyclePhase.menstrual);
    });
  });
}
