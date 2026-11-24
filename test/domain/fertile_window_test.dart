import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/fertile_window.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);

  CyclePrediction predicted({DateTime? ovulation, DateTime? lastStart}) =>
      CyclePrediction(
        method: ovulation == null
            ? PredictionMethod.cycleAverage
            : PredictionMethod.temperatureShift,
        confidence: PredictionConfidence.medium,
        lastPeriodStart: lastStart ?? june(1),
        estimatedOvulation: ovulation,
      );

  DailyLog lh(int day, OvulationTest t) =>
      DailyLog(date: june(day), ovulationTest: t);

  final cases = [
    (
      name: 'a temperature shift gives six days ending the day after it',
      prediction: predicted(ovulation: june(15)),
      logs: <DailyLog>[],
      want: (start: june(11), end: june(16), basis: FertileWindowBasis.shift),
    ),
    (
      name: 'a positive test dates ovulation to the next day',
      prediction: predicted(),
      logs: [lh(13, OvulationTest.positive)],
      want: (start: june(10), end: june(15), basis: FertileWindowBasis.test),
    ),
    (
      name: 'the first positive test in the cycle counts',
      prediction: predicted(),
      logs: [
        lh(12, OvulationTest.negative),
        lh(13, OvulationTest.positive),
        lh(14, OvulationTest.positive),
      ],
      want: (start: june(10), end: june(15), basis: FertileWindowBasis.test),
    ),
    (
      name: 'the shift wins over a test',
      prediction: predicted(ovulation: june(15)),
      logs: [lh(12, OvulationTest.positive)],
      want: (start: june(11), end: june(16), basis: FertileWindowBasis.shift),
    ),
  ];
  for (final c in cases) {
    test(c.name, () {
      final w = fertileWindowFor(c.prediction, c.logs)!;
      expect((start: w.start, end: w.end, basis: w.basis), c.want);
    });
  }

  final noWindow = [
    (
      name: 'nothing supports the estimate',
      prediction: predicted(),
      logs: [lh(13, OvulationTest.negative)],
      hormonal: false,
    ),
    (
      name: 'a positive test from an earlier cycle',
      prediction: predicted(lastStart: june(20)),
      logs: [lh(13, OvulationTest.positive)],
      hormonal: false,
    ),
    (
      name: 'no period logged',
      prediction: const CyclePrediction(
        method: PredictionMethod.insufficientData,
        confidence: PredictionConfidence.low,
      ),
      logs: [lh(13, OvulationTest.positive)],
      hormonal: false,
    ),
    (
      name: 'hormonal contraception, even with a positive test',
      prediction: predicted(),
      logs: [lh(13, OvulationTest.positive)],
      hormonal: true,
    ),
  ];
  for (final c in noWindow) {
    test('no window: ${c.name}', () {
      expect(
        fertileWindowFor(
          c.prediction,
          c.logs,
          hormonalContraception: c.hormonal,
        ),
        isNull,
      );
    });
  }

  test('contains its first and last day and nothing outside', () {
    final w = fertileWindowFor(predicted(ovulation: june(15)), const [])!;
    expect(w.contains(june(11)), isTrue);
    expect(w.contains(june(16)), isTrue);
    expect(w.contains(june(10)), isFalse);
    expect(w.contains(june(17)), isFalse);
  });
}
