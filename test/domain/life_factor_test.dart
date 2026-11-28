// Life factors: when one is in force, what ends it, and what it does to
// predictions, statistics and the profile.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/cycle_phase.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/cycle_statistics.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/period_reminders.dart';
import 'package:lilith/domain/reminder_setting.dart';

void main() {
  List<PeriodEvent> periodsOn(List<DateTime> starts) => [
    for (final s in starts) PeriodEvent(startDate: s),
  ];
  final jan = DateTime(2026, 1, 5);
  final feb = DateTime(2026, 2, 2);
  final mar = DateTime(2026, 3, 2);
  final regular = periodsOn([jan, feb, mar]);

  LifeFactor pregnant({DateTime? start, DateTime? end, DateTime? due}) =>
      LifeFactor(
        kind: LifeFactorKind.pregnant,
        start: start ?? DateTime(2026, 3, 20),
        end: end,
        dueDate: due,
      );
  LifeFactor feeding({DateTime? start, DateTime? end}) => LifeFactor(
    kind: LifeFactorKind.breastfeeding,
    start: start ?? DateTime(2026, 3, 20),
    end: end,
  );
  LifeFactor miscarriage(DateTime start) =>
      LifeFactor(kind: LifeFactorKind.miscarriage, start: start);

  group('LifeFactor', () {
    test('names its kinds, and only pregnancy outlasts a period', () {
      expect(
        [for (final k in LifeFactorKind.values) k.label],
        ['Pregnant', 'Breastfeeding', 'Miscarriage'],
      );
      expect(
        [for (final k in LifeFactorKind.values) k.endsWithPeriod],
        [false, true, true],
      );
    });

    test('keeps whole days', () {
      final f = pregnant(
        start: DateTime(2026, 3, 20, 14, 5),
        end: DateTime(2026, 11, 30, 9),
        due: DateTime(2026, 12, 20, 23),
      );
      expect(f.start, DateTime(2026, 3, 20));
      expect(f.end, DateTime(2026, 11, 30));
      expect(f.dueDate, DateTime(2026, 12, 20));
    });

    test('only a pregnancy has a due date', () {
      expect(
        LifeFactor(
          kind: LifeFactorKind.breastfeeding,
          start: jan,
          dueDate: mar,
        ).dueDate,
        isNull,
      );
    });

    test('an end before the start is no end', () {
      expect(pregnant(end: DateTime(2026, 3, 19)).end, isNull);
      expect(pregnant(end: DateTime(2026, 3, 20)).end, DateTime(2026, 3, 20));
    });

    test('is a value', () {
      expect(pregnant(due: mar), pregnant(due: mar));
      expect(pregnant(due: mar).hashCode, pregnant(due: mar).hashCode);
      expect(pregnant(), isNot(feeding()));
      expect(pregnant(), isNot(pregnant(end: DateTime(2026, 4))));
      expect(pregnant(), isNot(pregnant(due: mar)));
    });

    test('round-trips through JSON, writing only what is set', () {
      final full = pregnant(
        end: DateTime(2026, 11, 30),
        due: DateTime(2026, 12, 20),
      );
      expect(full.toJson(), {
        'kind': 'pregnant',
        'start': '2026-03-20',
        'end': '2026-11-30',
        'dueDate': '2026-12-20',
      });
      expect(
        LifeFactor.tryFromJson(jsonDecode(jsonEncode(full.toJson()))),
        full,
      );
      expect(feeding().toJson(), {
        'kind': 'breastfeeding',
        'start': '2026-03-20',
      });
      expect(LifeFactor.tryFromJson(feeding().toJson()), feeding());
    });

    test('reads nothing from what it cannot understand', () {
      expect(LifeFactor.tryFromJson(null), isNull);
      expect(LifeFactor.tryFromJson('pregnant'), isNull);
      expect(
        LifeFactor.tryFromJson(const {
          'kind': 'menopause',
          'start': '2026-01-01',
        }),
        isNull,
      );
      expect(LifeFactor.tryFromJson(const {'kind': 'pregnant'}), isNull);
      expect(
        LifeFactor.tryFromJson(const {'kind': 'pregnant', 'start': 'soon'}),
        isNull,
      );
    });

    test('endedOn sets the end and keeps the rest', () {
      final ended = pregnant(due: mar).endedOn(DateTime(2026, 11, 30, 8));
      expect(ended, pregnant(due: mar, end: DateTime(2026, 11, 30)));
    });
  });

  group('lastDayOf', () {
    test('an open pregnancy has none, whatever is logged', () {
      expect(lastDayOf(pregnant(), regular), isNull);
      expect(lastDayOf(pregnant(), periodsOn([DateTime(2026, 5)])), isNull);
    });

    test('is the end that was set', () {
      expect(
        lastDayOf(pregnant(end: DateTime(2026, 11, 30)), regular),
        DateTime(2026, 11, 30),
      );
    });

    test('breastfeeding and a miscarriage last until the day before the '
        'first period that starts after them', () {
      final later = periodsOn([
        jan,
        DateTime(2026, 6, 1),
        DateTime(2026, 7, 1),
      ]);
      expect(lastDayOf(feeding(), later), DateTime(2026, 5, 31));
      expect(
        lastDayOf(miscarriage(DateTime(2026, 3, 20)), later),
        DateTime(2026, 5, 31),
      );
      expect(lastDayOf(feeding(), regular), isNull);
    });

    test('a period on the very day it starts does not end it', () {
      expect(
        lastDayOf(
          miscarriage(DateTime(2026, 3, 20)),
          periodsOn([DateTime(2026, 3, 20)]),
        ),
        isNull,
      );
    });

    test('the earlier of a set end and a period wins', () {
      final later = periodsOn([DateTime(2026, 6, 1)]);
      expect(
        lastDayOf(feeding(end: DateTime(2026, 4, 30)), later),
        DateTime(2026, 4, 30),
      );
      expect(
        lastDayOf(feeding(end: DateTime(2026, 8, 30)), later),
        DateTime(2026, 5, 31),
      );
    });
  });

  group('activeFactor', () {
    test('none without factors', () {
      expect(activeFactor(const [], regular, today: mar), isNull);
    });

    test('from its first day to its last, both included', () {
      final f = pregnant(end: DateTime(2026, 11, 30));
      LifeFactor? on(DateTime day) => activeFactor([f], regular, today: day);
      expect(on(DateTime(2026, 3, 19)), isNull);
      expect(on(DateTime(2026, 3, 20, 22)), f);
      expect(on(DateTime(2026, 11, 30)), f);
      expect(on(DateTime(2026, 12, 1)), isNull);
    });

    test('an open one stays in force', () {
      expect(
        activeFactor([pregnant()], regular, today: DateTime(2028)),
        pregnant(),
      );
    });

    test('breastfeeding stops being in force once a period is logged', () {
      final later = [...regular, PeriodEvent(startDate: DateTime(2026, 6, 1))];
      expect(
        activeFactor([feeding()], later, today: DateTime(2026, 5, 31)),
        feeding(),
      );
      expect(
        activeFactor([feeding()], later, today: DateTime(2026, 6, 1)),
        isNull,
      );
    });

    test('a pregnancy stays in force though a period is logged', () {
      final later = [...regular, PeriodEvent(startDate: DateTime(2026, 6, 1))];
      expect(
        activeFactor([pregnant()], later, today: DateTime(2026, 6, 10)),
        pregnant(),
      );
    });

    test('of two in force, the one that began last', () {
      final a = pregnant(start: DateTime(2026, 3, 20));
      final b = feeding(start: DateTime(2026, 4, 20));
      expect(activeFactor([a, b], regular, today: DateTime(2026, 5)), b);
      expect(activeFactor([b, a], regular, today: DateTime(2026, 5)), b);
    });
  });

  group('the predictor', () {
    const predictor = CyclePredictor();
    final today = DateTime(2026, 4, 10);

    test('pauses under a factor in force: no dates, the factor named, the '
        'averages kept', () {
      final p = predictor.predict(
        readings: const [],
        periods: regular,
        today: today,
        factors: [pregnant()],
      );
      expect(p.method, PredictionMethod.paused);
      expect(p.pausedBy, pregnant());
      expect(p.isOnHold, isTrue);
      expect(p.confidence, PredictionConfidence.none);
      expect(p.predictedNextPeriod, isNull);
      expect(p.lastPeriodStart, isNull);
      expect(p.currentCycleDay, isNull);
      expect(p.estimatedOvulation, isNull);
      expect(p.daysUntilNextPeriod(today), isNull);
      expect(p.averageCycleLength, 28);
      expect(p.cycleCount, 2);
    });

    test('pauses under a factor with no period logged at all', () {
      final p = predictor.predict(
        readings: const [],
        periods: const [],
        today: today,
        factors: [pregnant()],
      );
      expect(p.method, PredictionMethod.paused);
      expect(p.pausedBy, pregnant());
    });

    test('without factors nothing changes', () {
      final p = predictor.predict(
        readings: const [],
        periods: regular,
        today: today,
      );
      expect(p.method, PredictionMethod.cycleAverage);
      expect(p.pausedBy, isNull);
      expect(p.isOnHold, isFalse);
      expect(p.predictedNextPeriod, DateTime(2026, 3, 30));
    });

    test('a factor that has not begun changes nothing', () {
      final p = predictor.predict(
        readings: const [],
        periods: regular,
        today: today,
        factors: [pregnant(start: DateTime(2026, 5))],
      );
      expect(p.method, PredictionMethod.cycleAverage);
      expect(p.predictedNextPeriod, DateTime(2026, 3, 30));
    });

    test('after a factor ends, waits for a period to predict from', () {
      final p = predictor.predict(
        readings: const [],
        periods: regular,
        today: DateTime(2026, 12, 10),
        factors: [pregnant(end: DateTime(2026, 11, 30))],
      );
      expect(p.method, PredictionMethod.awaitingPeriod);
      expect(p.isOnHold, isTrue);
      expect(p.pausedBy, isNull);
      expect(p.predictedNextPeriod, isNull);
      expect(p.lastPeriodStart, isNull);
      expect(p.currentCycleDay, isNull);
      expect(p.averageCycleLength, 28);
    });

    test('a pregnancy dated from the last period start waits too once it '
        'has ended', () {
      final p = predictor.predict(
        readings: const [],
        periods: regular,
        today: DateTime(2026, 12, 10),
        factors: [pregnant(start: mar, end: DateTime(2026, 11, 30))],
      );
      expect(p.method, PredictionMethod.awaitingPeriod);
    });

    test('restarts from the first period after the factor, leaving the '
        'gap out of the average', () {
      final back = DateTime(2027, 2, 1);
      final p = predictor.predict(
        readings: const [],
        periods: [
          ...regular,
          PeriodEvent(startDate: back),
        ],
        today: DateTime(2027, 2, 10),
        factors: [
          pregnant(end: DateTime(2026, 11, 30)),
          feeding(start: DateTime(2026, 12)),
        ],
      );
      expect(p.method, PredictionMethod.cycleAverage);
      expect(p.isOnHold, isFalse);
      expect(p.lastPeriodStart, back);
      expect(p.currentCycleDay, 10);
      expect(p.cycleCount, 2);
      expect(p.averageCycleLength, 28);
      expect(p.predictedNextPeriod, addDays(back, 28));
    });

    test('a short cycle around a miscarriage is left out of the average', () {
      final periods = periodsOn([jan, feb, mar, DateTime(2026, 4, 20)]);
      final p = predictor.predict(
        readings: const [],
        periods: periods,
        today: DateTime(2026, 4, 25),
        factors: [miscarriage(DateTime(2026, 3, 25))],
      );
      expect(p.method, PredictionMethod.cycleAverage);
      expect(p.cycleCount, 2);
      expect(p.averageCycleLength, 28);
    });

    test('a capped confidence leaves a pause as it is', () {
      final p = predictor.predict(
        readings: const [],
        periods: regular,
        today: today,
        factors: [pregnant()],
        maxConfidence: PredictionConfidence.low,
      );
      expect(p.method, PredictionMethod.paused);
      expect(p.pausedBy, pregnant());
    });
  });

  group('what follows from a pause', () {
    const predictor = CyclePredictor();
    final today = DateTime(2026, 4, 10);
    CyclePrediction paused() => predictor.predict(
      readings: const [],
      periods: regular,
      today: today,
      factors: [pregnant()],
    );

    test('no cycle day or phase', () {
      final s = cycleStatusFor(paused(), regular, today: today);
      expect(s.day, isNull);
      expect(s.phase, isNull);
    });

    test('no fertile window, even with a positive test', () {
      expect(
        fertileWindowFor(paused(), [
          DailyLog(
            date: DateTime(2026, 4, 8),
            ovulationTest: OvulationTest.positive,
          ),
        ]),
        isNull,
      );
    });

    test('no period reminders', () {
      final plan = periodRemindersFor(
        predictedStart: paused().predictedNextPeriod,
        spread: 2,
        setting: const ReminderSetting(
          enabled: true,
          hour: 8,
          beforePeriod: true,
          whenLate: true,
        ),
        now: today,
      );
      expect(plan.isEmpty, isTrue);
    });
  });

  group('cycle statistics', () {
    final today = DateTime(2027, 6);

    test('leave out a cycle that overlaps a factor', () {
      final periods = periodsOn([
        jan,
        feb,
        mar,
        DateTime(2027, 2, 1),
        DateTime(2027, 3, 3),
      ]);
      final s = cycleStatisticsFor(
        periods,
        today: today,
        factors: [pregnant(end: DateTime(2026, 11, 30))],
      )!;
      expect(s.cycleCount, 3);
      expect(s.longestCycle, 30);
      expect(s.shortestCycle, 28);
      expect(s.flags, isEmpty);
    });

    test('without factors every cycle counts', () {
      final periods = periodsOn([jan, feb, mar, DateTime(2027, 2, 1)]);
      final s = cycleStatisticsFor(periods, today: today)!;
      expect(s.cycleCount, 3);
      expect(s.longestCycle, 336);
    });

    test('too few cycles left gives none', () {
      final periods = periodsOn([jan, feb, DateTime(2027, 2, 1)]);
      expect(
        cycleStatisticsFor(periods, today: today, factors: [pregnant()]),
        isNull,
      );
    });
  });

  group('cycleOverlapsFactor', () {
    test('a factor inside the cycle, or reaching into it, overlaps', () {
      final f = pregnant(end: DateTime(2026, 11, 30));
      final back = DateTime(2027, 2, 1);
      expect(cycleOverlapsFactor(mar, back, [f], regular), isTrue);
      expect(cycleOverlapsFactor(feb, mar, [f], regular), isFalse);
      expect(
        cycleOverlapsFactor(back, DateTime(2027, 3, 1), [f], regular),
        isFalse,
      );
    });

    test('a factor that begins on the day the next period starts does '
        'not', () {
      expect(
        cycleOverlapsFactor(feb, mar, [pregnant(start: mar)], regular),
        isFalse,
      );
    });

    test('an open factor overlaps every cycle that ends after it began', () {
      expect(
        cycleOverlapsFactor(mar, DateTime(2028), [pregnant()], regular),
        isTrue,
      );
    });
  });

  group('HealthProfile.lifeFactors', () {
    final factors = [
      feeding(start: DateTime(2026, 12)),
      pregnant(end: DateTime(2026, 11, 30)),
    ];

    test('are kept oldest first', () {
      expect(HealthProfile(lifeFactors: factors).lifeFactors, [
        factors[1],
        factors[0],
      ]);
      expect(HealthProfile().lifeFactors, isEmpty);
    });

    test('make the profile worth storing and part of what it equals', () {
      final p = HealthProfile(lifeFactors: factors);
      expect(p.isEmpty, isFalse);
      expect(p, HealthProfile(lifeFactors: factors.reversed.toList()));
      expect(p.hashCode, HealthProfile(lifeFactors: factors).hashCode);
      expect(p, isNot(HealthProfile()));
    });

    test('round-trip through JSON, absent when there are none', () {
      final p = HealthProfile(lifeFactors: factors);
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      expect(HealthProfile.fromJson(json), p);
      expect(HealthProfile().toJson().containsKey('lifeFactors'), isFalse);
    });

    test('skip entries that cannot be read', () {
      final p = HealthProfile.fromJson(const {
        'lifeFactors': [
          {'kind': 'pregnant', 'start': '2026-03-20'},
          {'kind': 'unknown', 'start': '2026-03-20'},
          'nonsense',
        ],
      });
      expect(p.lifeFactors, [pregnant()]);
      expect(
        HealthProfile.fromJson(const {'lifeFactors': 'x'}).lifeFactors,
        isEmpty,
      );
    });

    test('copyWith replaces them and otherwise keeps them', () {
      final p = HealthProfile(lifeFactors: factors);
      expect(p.copyWith(notes: 'n').lifeFactors, p.lifeFactors);
      expect(p.copyWith(lifeFactors: const []).lifeFactors, isEmpty);
    });
  });
}
