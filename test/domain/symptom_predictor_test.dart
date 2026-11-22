import 'package:flutter_test/flutter_test.dart';
import 'package:lillith/domain/daily_log.dart';
import 'package:lillith/domain/period_event.dart';
import 'package:lillith/domain/symptom_predictor.dart';

DailyLog log(DateTime date, Set<Symptom> symptoms, {int? pain}) =>
    DailyLog(date: date, symptoms: symptoms, painLevel: pain);

void main() {
  const predictor = SymptomPredictor();
  final starts = [
    PeriodEvent(startDate: DateTime(2026, 3, 1)),
    PeriodEvent(startDate: DateTime(2026, 3, 29)),
  ];

  // Four days of cramps at the start of the first cycle, bloating on day one.
  final firstDays = [
    log(DateTime(2026, 3, 1), {Symptom.cramps, Symptom.bloating}, pain: 6),
    log(DateTime(2026, 3, 2), {Symptom.cramps}, pain: 5),
    log(DateTime(2026, 3, 3), {Symptom.cramps}, pain: 3),
    log(DateTime(2026, 3, 4), {Symptom.cramps}),
  ];

  group('without enough history', () {
    final cases =
        <({String name, List<DailyLog> logs, List<PeriodEvent> periods})>[
          (name: 'no period start', logs: firstDays, periods: const []),
          (
            name: 'fewer than three logs',
            logs: firstDays.take(2).toList(),
            periods: starts,
          ),
          (
            name: 'every log precedes the first start',
            logs: [
              for (var d = 1; d <= 3; d++)
                log(DateTime(2026, 2, d), {Symptom.mood}),
            ],
            periods: starts,
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        final f = predictor.predict(
          logs: c.logs,
          periods: c.periods,
          today: DateTime(2026, 3, 29),
        );
        expect(f.likely, isEmpty);
        expect(f.typicalPain, isNull);
        expect(f.hasData, isFalse);
        expect(f.loggedDays, c.logs.length);
      });
    }
  });

  group('at the start of a new cycle', () {
    final f = predictor.predict(
      logs: firstDays,
      periods: starts,
      today: DateTime(2026, 3, 29),
    );

    test(
      'the symptoms of the same cycle days come first, most likely first',
      () {
        expect(f.likely.map((l) => l.symptom), [
          Symptom.cramps,
          Symptom.bloating,
        ]);
        expect(f.likely[0].probability, 1.0);
        expect(f.likely[0].percent, 100);
        expect(f.likely[1].probability, 0.5);
        expect(f.hasData, isTrue);
      },
    );

    test('typical pain averages each matching day once', () {
      expect(f.typicalPain, closeTo((6 + 5 + 3) / 3, 0.001));
    });

    test('counts every logged day', () {
      expect(f.loggedDays, 4);
    });
  });

  test('a symptom below the minimum probability is left out', () {
    const strict = SymptomPredictor(minProbability: 0.6);
    final f = strict.predict(
      logs: firstDays,
      periods: starts,
      today: DateTime(2026, 3, 29),
    );
    expect(f.likely.map((l) => l.symptom), [Symptom.cramps]);
  });

  test('days outside the window are not consulted', () {
    const oneDay = SymptomPredictor(windowDays: 1);
    final f = oneDay.predict(
      logs: firstDays,
      periods: starts,
      today: DateTime(2026, 3, 10),
    );
    expect(f.likely, isEmpty);
    expect(f.typicalPain, isNull);
  });

  test('a log is placed by the most recent start before it', () {
    final logs = [
      log(DateTime(2026, 3, 15), {Symptom.nausea}),
      log(DateTime(2026, 3, 29), {Symptom.headache}),
      log(DateTime(2026, 3, 30), {Symptom.headache}),
    ];
    final f = predictor.predict(
      logs: logs,
      periods: starts,
      today: DateTime(2026, 3, 29),
    );
    expect(f.likely.map((l) => l.symptom), [Symptom.headache]);
    expect(f.likely.single.occurrences, 2);
    expect(f.likely.single.sampleDays, 2);
  });
}
