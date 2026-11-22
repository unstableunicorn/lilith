import 'package:flutter_test/flutter_test.dart';
import 'package:lillith/domain/daily_log.dart';

void main() {
  final day = DateTime(2026, 5, 2);

  group('FlowIntensity', () {
    test('levels rise from none to heavy', () {
      expect(FlowIntensity.values.map((f) => f.level), [0, 1, 2, 3, 4]);
    });

    test('everything but none counts as bleeding', () {
      expect(FlowIntensity.none.isBleeding, isFalse);
      for (final f in FlowIntensity.values.skip(1)) {
        expect(f.isBleeding, isTrue, reason: f.name);
      }
    });

    final cases = <({String name, String? input, FlowIntensity want})>[
      (name: 'known name', input: 'light', want: FlowIntensity.light),
      (
        name: 'unknown falls back to none',
        input: 'flood',
        want: FlowIntensity.none,
      ),
      (
        name: 'missing falls back to none',
        input: null,
        want: FlowIntensity.none,
      ),
    ];
    for (final c in cases) {
      test(
        'fromName: ${c.name}',
        () => expect(FlowIntensity.fromName(c.input), c.want),
      );
    }
  });

  group('Symptom.fromName', () {
    test('finds a known symptom', () {
      expect(Symptom.fromName('backPain'), Symptom.backPain);
    });
    test('returns null for an unknown or missing name', () {
      expect(Symptom.fromName('hiccups'), isNull);
      expect(Symptom.fromName(null), isNull);
    });
  });

  group('DailyLog', () {
    test('normalises its date and defaults to an empty day', () {
      final log = DailyLog(date: DateTime(2026, 5, 2, 13));
      expect(log.date, day);
      expect(log.flow, FlowIntensity.none);
      expect(log.symptoms, isEmpty);
      expect(log.painLevel, isNull);
      expect(log.isEmpty, isTrue);
    });

    final painCases = <({String name, int? input, int? want})>[
      (name: 'keeps a value on the scale', input: 7, want: 7),
      (name: 'clamps above ten', input: 14, want: 10),
      (name: 'clamps below zero', input: -3, want: 0),
      (name: 'leaves unrated as null', input: null, want: null),
    ];
    for (final c in painCases) {
      test('pain ${c.name}', () {
        expect(DailyLog(date: day, painLevel: c.input).painLevel, c.want);
      });
    }

    final emptyCases = <({String name, DailyLog log, bool want})>[
      (
        name: 'flow alone is not empty',
        log: DailyLog(date: day, flow: FlowIntensity.spotting),
        want: false,
      ),
      (
        name: 'a symptom alone is not empty',
        log: DailyLog(date: day, symptoms: {Symptom.cramps}),
        want: false,
      ),
      (
        name: 'a pain rating alone is not empty',
        log: DailyLog(date: day, painLevel: 0),
        want: false,
      ),
      (name: 'nothing logged is empty', log: DailyLog(date: day), want: true),
    ];
    for (final c in emptyCases) {
      test(c.name, () => expect(c.log.isEmpty, c.want));
    }

    test('symptoms cannot be changed after construction', () {
      final log = DailyLog(date: day, symptoms: {Symptom.cramps});
      expect(() => log.symptoms.add(Symptom.nausea), throwsUnsupportedError);
    });

    test('copyWith replaces only what is given', () {
      final log = DailyLog(
        date: day,
        flow: FlowIntensity.medium,
        symptoms: {Symptom.cramps},
        painLevel: 5,
      );
      final changed = log.copyWith(symptoms: {Symptom.mood});
      expect(changed.flow, FlowIntensity.medium);
      expect(changed.symptoms, {Symptom.mood});
      expect(changed.painLevel, 5);
    });

    test('copyWith can clear the pain rating', () {
      final log = DailyLog(date: day, painLevel: 5);
      expect(log.copyWith(painLevel: null).painLevel, 5);
      expect(log.copyWith(clearPain: true).painLevel, isNull);
    });

    test('is equal by value, whatever the symptom order', () {
      final a = DailyLog(
        date: day,
        symptoms: {Symptom.cramps, Symptom.mood},
        painLevel: 2,
      );
      final b = DailyLog(
        date: day,
        symptoms: {Symptom.mood, Symptom.cramps},
        painLevel: 2,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(flow: FlowIntensity.light)));
    });

    test('round-trips through JSON', () {
      final log = DailyLog(
        date: day,
        flow: FlowIntensity.heavy,
        symptoms: {Symptom.cramps, Symptom.backPain},
        painLevel: 6,
      );
      expect(DailyLog.fromJson(log.toJson()), log);
    });

    test('omits the pain key when unrated', () {
      expect(DailyLog(date: day).toJson(), isNot(contains('painLevel')));
    });

    test('drops unknown symptoms instead of failing to load', () {
      final log = DailyLog.fromJson({
        'date': '2026-05-02T00:00:00.000',
        'flow': 'light',
        'symptoms': ['cramps', 'hiccups'],
      });
      expect(log.symptoms, {Symptom.cramps});
      expect(log.flow, FlowIntensity.light);
      expect(log.painLevel, isNull);
    });
  });
}
