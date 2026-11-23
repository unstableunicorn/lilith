import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

/// [count] readings of [celsius] on consecutive days from [from].
List<TemperatureReading> flat(DateTime from, int count, double celsius) => [
  for (var i = 0; i < count; i++)
    TemperatureReading(
      date: DateTime(from.year, from.month, from.day + i),
      celsius: celsius,
    ),
];

List<PeriodEvent> periodsOn(List<DateTime> starts) => [
  for (final s in starts) PeriodEvent(startDate: s),
];

void main() {
  const predictor = CyclePredictor();

  test('no periods logged: insufficient data', () {
    final result = predictor.predict(
      readings: const [],
      periods: const [],
      today: DateTime(2026, 7, 15),
    );
    expect(result.method, PredictionMethod.insufficientData);
    expect(result.confidence, PredictionConfidence.none);
    expect(result.predictedNextPeriod, isNull);
    expect(result.lastPeriodStart, isNull);
    expect(result.currentCycleDay, isNull);
  });

  test('one period and no shift: a typical cycle from the last start', () {
    final result = predictor.predict(
      readings: const [],
      periods: periodsOn([DateTime(2026, 5, 27)]),
      today: DateTime(2026, 6, 10),
    );
    expect(result.method, PredictionMethod.cycleAverage);
    expect(result.confidence, PredictionConfidence.low);
    expect(result.averageCycleLength, isNull);
    expect(result.cycleCount, 0);
    expect(
      result.predictedNextPeriod,
      DateTime(2026, 5, 27 + CyclePredictor.defaultCycleLength),
    );
    expect(result.currentCycleDay, 15);
  });

  test('regular history: the average cycle from the last start', () {
    final result = predictor.predict(
      readings: const [],
      periods: periodsOn([
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 29),
        DateTime(2026, 5, 27),
      ]),
      today: DateTime(2026, 6, 10),
    );
    expect(result.method, PredictionMethod.cycleAverage);
    expect(result.averageCycleLength, closeTo(28, 0.01));
    expect(result.cycleCount, 2);
    expect(result.predictedNextPeriod, DateTime(2026, 6, 24));
    expect(result.lastPeriodStart, DateTime(2026, 5, 27));
    expect(result.currentCycleDay, 15);
  });

  test('period starts arrive in any order', () {
    final result = predictor.predict(
      readings: const [],
      periods: periodsOn([
        DateTime(2026, 5, 27),
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 29),
      ]),
      today: DateTime(2026, 6, 10),
    );
    expect(result.predictedNextPeriod, DateTime(2026, 6, 24));
  });

  test('implausible gaps between starts are left out of the average', () {
    final result = predictor.predict(
      readings: const [],
      periods: periodsOn([
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 5),
        DateTime(2026, 2, 2),
      ]),
      today: DateTime(2026, 2, 10),
    );
    expect(result.cycleCount, 1);
    expect(result.averageCycleLength, 28);
    expect(result.predictedNextPeriod, DateTime(2026, 3, 2));
  });

  group('average-based confidence grows with recorded cycles', () {
    final cases = <({int starts, PredictionConfidence want})>[
      (starts: 2, want: PredictionConfidence.low),
      (starts: 3, want: PredictionConfidence.medium),
      (starts: 4, want: PredictionConfidence.high),
      (starts: 6, want: PredictionConfidence.high),
    ];
    for (final c in cases) {
      test('${c.starts} starts: ${c.want.name}', () {
        final starts = [
          for (var i = 0; i < c.starts; i++) DateTime(2026, 1, 1 + 28 * i),
        ];
        final result = predictor.predict(
          readings: const [],
          periods: periodsOn(starts),
          today: DateTime(
            starts.last.year,
            starts.last.month,
            starts.last.day + 5,
          ),
        );
        expect(result.method, PredictionMethod.cycleAverage);
        expect(result.confidence, c.want);
      });
    }
  });

  test('a sustained temperature rise predicts from ovulation', () {
    final start = DateTime(2026, 6, 1);
    final readings = [
      ...flat(start, 8, 36.30),
      ...flat(DateTime(2026, 6, 9), 8, 36.65),
      // Readings after today must not count.
      ...flat(DateTime(2026, 6, 18), 5, 35),
    ];
    final result = predictor.predict(
      readings: readings,
      periods: periodsOn([start]),
      today: DateTime(2026, 6, 17),
    );
    expect(result.method, PredictionMethod.temperatureShift);
    expect(result.confidence, PredictionConfidence.medium);
    expect(result.estimatedOvulation, DateTime(2026, 6, 8));
    expect(result.lutealLength, CyclePredictor.defaultLutealLength);
    expect(result.predictedNextPeriod, DateTime(2026, 6, 22));
    expect(result.currentCycleDay, 17);
  });

  test('a two-day blip is not a shift', () {
    final start = DateTime(2026, 6, 1);
    final readings = [
      ...flat(start, 8, 36.30),
      ...flat(DateTime(2026, 6, 9), 2, 36.70),
      ...flat(DateTime(2026, 6, 11), 5, 36.30),
    ];
    final result = predictor.predict(
      readings: readings,
      periods: periodsOn([start]),
      today: DateTime(2026, 6, 16),
    );
    expect(result.method, PredictionMethod.cycleAverage);
    expect(result.estimatedOvulation, isNull);
  });

  test('flat temperatures fall back to the cycle average', () {
    final result = predictor.predict(
      readings: flat(DateTime(2026, 5, 30), 14, 36.4),
      periods: periodsOn([DateTime(2026, 5, 1), DateTime(2026, 5, 30)]),
      today: DateTime(2026, 6, 12),
    );
    expect(result.method, PredictionMethod.cycleAverage);
    expect(result.predictedNextPeriod, DateTime(2026, 6, 28));
  });

  test('too few readings in the cycle cannot show a shift', () {
    final start = DateTime(2026, 6, 1);
    final result = predictor.predict(
      readings: [
        ...flat(start, 3, 36.3),
        ...flat(DateTime(2026, 6, 4), 3, 36.7),
      ],
      periods: periodsOn([start]),
      today: DateTime(2026, 6, 7),
    );
    expect(result.method, PredictionMethod.cycleAverage);
  });

  test('a past cycle with a visible shift sets the luteal length', () {
    // Cycle one: rise on 13 March, next period 24 March: a 12-day luteal phase.
    final one = [
      ...flat(DateTime(2026, 3, 1), 12, 36.3),
      ...flat(DateTime(2026, 3, 13), 11, 36.65),
    ];
    // Cycle two: rise on 3 April, ovulation 2 April.
    final two = [
      ...flat(DateTime(2026, 3, 24), 10, 36.3),
      ...flat(DateTime(2026, 4, 3), 6, 36.65),
    ];
    final result = predictor.predict(
      readings: [...one, ...two],
      periods: periodsOn([DateTime(2026, 3, 1), DateTime(2026, 3, 24)]),
      today: DateTime(2026, 4, 8),
    );
    expect(result.method, PredictionMethod.temperatureShift);
    expect(result.estimatedOvulation, DateTime(2026, 4, 2));
    expect(result.lutealLength, 12);
    expect(result.predictedNextPeriod, DateTime(2026, 4, 14));
    expect(result.averageCycleLength, 23);
  });

  test('shift-based confidence is high once two cycles are recorded', () {
    final start = DateTime(2026, 6, 1);
    final result = predictor.predict(
      readings: [
        ...flat(start, 8, 36.3),
        ...flat(DateTime(2026, 6, 9), 6, 36.7),
      ],
      periods: periodsOn([DateTime(2026, 4, 4), DateTime(2026, 5, 3), start]),
      today: DateTime(2026, 6, 15),
    );
    expect(result.method, PredictionMethod.temperatureShift);
    expect(result.confidence, PredictionConfidence.high);
  });

  group('daysUntilNextPeriod', () {
    final prediction = CyclePrediction(
      method: PredictionMethod.cycleAverage,
      confidence: PredictionConfidence.low,
      predictedNextPeriod: DateTime(2026, 6, 24),
    );
    final cases = <({String name, DateTime today, int want})>[
      (name: 'ahead', today: DateTime(2026, 6, 10, 15), want: 14),
      (name: 'the day itself', today: DateTime(2026, 6, 24), want: 0),
      (name: 'overdue is negative', today: DateTime(2026, 6, 30), want: -6),
    ];
    for (final c in cases) {
      test(
        c.name,
        () => expect(prediction.daysUntilNextPeriod(c.today), c.want),
      );
    }
    test('is null without a prediction', () {
      const none = CyclePrediction(
        method: PredictionMethod.insufficientData,
        confidence: PredictionConfidence.none,
      );
      expect(none.daysUntilNextPeriod(DateTime(2026, 6, 1)), isNull);
    });
  });
}
