import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/symptom_predictor.dart';

DailyLog log(
  DateTime date,
  Set<Mood> moods, {
  Set<Symptom> symptoms = const {},
}) => DailyLog(
  date: date,
  symptoms: symptoms,
  signs: BodySigns(moods: moods),
);

void main() {
  const predictor = SymptomPredictor();
  final starts = [
    PeriodEvent(startDate: DateTime(2026, 3, 1)),
    PeriodEvent(startDate: DateTime(2026, 3, 29)),
  ];
  final newCycle = DateTime(2026, 3, 29);

  // Four irritable days at the start of the first cycle, low on day one.
  final firstDays = [
    log(DateTime(2026, 3, 1), {Mood.irritable, Mood.low}),
    log(DateTime(2026, 3, 2), {Mood.irritable}),
    log(DateTime(2026, 3, 3), {Mood.irritable}),
    log(DateTime(2026, 3, 4), {Mood.irritable}),
  ];

  group('at the start of a new cycle', () {
    final f = predictor.predict(
      logs: firstDays,
      periods: starts,
      today: newCycle,
    );

    test('the moods of the same cycle days, most likely first', () {
      expect(f.likelyMoods.map((l) => l.mood), [Mood.irritable, Mood.low]);
      expect(f.likelyMoods[0].probability, 1.0);
      expect(f.likelyMoods[0].percent, 100);
      expect(f.likelyMoods[1].probability, 0.5);
      expect(f.likelyMoods[1].percent, 50);
    });

    test('moods alone are a forecast', () {
      expect(f.likely, isEmpty);
      expect(f.typicalPain, isNull);
      expect(f.hasData, isTrue);
    });
  });

  test('a mood below the minimum probability is left out', () {
    const strict = SymptomPredictor(minProbability: 0.6);
    final f = strict.predict(logs: firstDays, periods: starts, today: newCycle);
    expect(f.likelyMoods.map((l) => l.mood), [Mood.irritable]);
  });

  test('a day without the mood counts against it', () {
    final logs = [
      log(DateTime(2026, 3, 1), {Mood.sad}),
      log(DateTime(2026, 3, 2), const {}, symptoms: {Symptom.cramps}),
      log(DateTime(2026, 3, 3), const {}, symptoms: {Symptom.cramps}),
    ];
    final f = predictor.predict(logs: logs, periods: starts, today: newCycle);
    final sad = f.likelyMoods.single;
    expect(sad.mood, Mood.sad);
    expect(sad.occurrences, 1);
    expect(sad.sampleDays, 2);
    expect(sad.probability, 0.5);
  });

  test('moods and symptoms are forecast side by side', () {
    final logs = [
      for (var d = 1; d <= 3; d++)
        log(DateTime(2026, 3, d), {Mood.anxious}, symptoms: {Symptom.cramps}),
    ];
    final f = predictor.predict(logs: logs, periods: starts, today: newCycle);
    expect(f.likely.map((l) => l.symptom), [Symptom.cramps]);
    expect(f.likelyMoods.map((l) => l.mood), [Mood.anxious]);
  });

  test('every mood can be forecast, the good ones too', () {
    final logs = [
      for (var d = 1; d <= 3; d++)
        log(DateTime(2026, 3, d), Mood.values.toSet()),
    ];
    final f = predictor.predict(logs: logs, periods: starts, today: newCycle);
    expect(f.likelyMoods.map((l) => l.mood).toSet(), Mood.values.toSet());
  });

  test('days outside the window are not consulted', () {
    const oneDay = SymptomPredictor(windowDays: 1);
    final f = oneDay.predict(
      logs: firstDays,
      periods: starts,
      today: DateTime(2026, 3, 10),
    );
    expect(f.likelyMoods, isEmpty);
    expect(f.hasData, isFalse);
  });

  group('without enough history there are no moods', () {
    final cases =
        <({String name, List<DailyLog> logs, List<PeriodEvent> periods})>[
          (name: 'no period start', logs: firstDays, periods: const []),
          (
            name: 'fewer than three logs',
            logs: firstDays.take(2).toList(),
            periods: starts,
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        final f = predictor.predict(
          logs: c.logs,
          periods: c.periods,
          today: newCycle,
        );
        expect(f.likelyMoods, isEmpty);
        expect(f.hasData, isFalse);
      });
    }
  });
}
