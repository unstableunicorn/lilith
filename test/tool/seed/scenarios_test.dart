import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/temperature_reading.dart';

import '../../../tool/seed/scenarios.dart';

void main() {
  const codec = HealthDocumentCodec();

  List<double> readingsBetween(HealthData d, DateTime from, DateTime to) => [
    for (final r in d.readings)
      if (!r.date.isBefore(from) && !r.date.isAfter(to)) r.celsius,
  ];

  void expectDeterministic(HealthData Function({int seed}) build) {
    expect(codec.encode(build(seed: 7)), codec.encode(build(seed: 7)));
    expect(codec.encode(build(seed: 7)), isNot(codec.encode(build(seed: 8))));
  }

  void expectRoundTrip(HealthData d) =>
      expect(codec.encode(codec.decode(codec.encode(d))), codec.encode(d));

  group('healthy-year', () {
    final d = healthyYear();
    final first = DateTime(2025, 11, 24);
    final last = DateTime(2026, 11, 24);

    test('is the same for a seed and differs between seeds', () {
      expectDeterministic(healthyYear);
    });

    test('survives the document codec', () => expectRoundTrip(d));

    test('stays within the year', () {
      final dates = [
        ...d.readings.map((r) => r.date),
        ...d.dailyLogs.map((l) => l.date),
        ...d.wearableNights.map((n) => n.date),
      ];
      expect(
        dates.every((t) => !t.isBefore(first) && !t.isAfter(last)),
        isTrue,
      );
    });

    test('has 13 five-day periods, cycles of 27 to 30 days', () {
      expect(d.periods, hasLength(13));
      expect(d.periods.first.startDate, first);
      for (final p in d.periods) {
        expect(daysBetween(p.startDate, p.endDate!), 4);
      }
      final lengths = [
        for (final (a, b) in IterableZip([
          d.periods,
          d.periods.skip(1),
        ]).map((pair) => (pair[0], pair[1])))
          daysBetween(a.startDate, b.startDate),
      ];
      expect(
        lengths.every((n) => n >= 27 && n <= 30),
        isTrue,
        reason: '$lengths',
      );
      expect(lengths.average, inInclusiveRange(27.5, 29.5));
    });

    test('flows medium, heavy, medium, light, light', () {
      for (final p in d.periods) {
        final flows = [
          for (var i = 0; i < 5; i++) d.logFor(addDays(p.startDate, i))?.flow,
        ];
        expect(flows, [
          FlowIntensity.medium,
          FlowIntensity.heavy,
          FlowIntensity.medium,
          FlowIntensity.light,
          FlowIntensity.light,
        ]);
      }
    });

    test('has manual readings on most mornings', () {
      final days = daysBetween(first, last) + 1;
      expect(d.readings.length / days, inInclusiveRange(0.8, 0.9));
      expect(d.readings.every((r) => r.source == ReadingSource.manual), isTrue);
    });

    test('each full cycle shows a rise of about 0.3 °C after ovulation', () {
      for (final (a, b) in IterableZip([
        d.periods,
        d.periods.skip(1),
      ]).map((pair) => (pair[0], pair[1]))) {
        final length = daysBetween(a.startDate, b.startDate);
        final ovulation = addDays(a.startDate, length - 14);
        final before = readingsBetween(d, a.startDate, ovulation);
        final after = readingsBetween(
          d,
          addDays(ovulation, 2),
          addDays(b.startDate, -1),
        );
        expect(after.average - before.average, inInclusiveRange(0.2, 0.45));
      }
    });

    test('has watch nights for the last 90 days only', () {
      expect(d.wearableNights, isNotEmpty);
      final from = addDays(last, -89);
      expect(d.wearableNights.every((n) => !n.date.isBefore(from)), isTrue);
      expect(
        d.wearableNights.every((n) => n.source == ReadingSource.watch),
        isTrue,
      );
      expect(
        d.wearableNights.map((n) => n.celsius).average,
        inInclusiveRange(33.6, 33.9),
      );
    });

    test('has the profile of a regular cycle', () {
      expect(d.profile.usualCycleLength, 28);
      expect(d.profile.usualPeriodLength, 5);
      expect(d.profile.contraception, Contraception.none);
      expect(d.profile.regularity, CycleRegularity.regular);
      expect(d.profile.birthYear, 1992);
      expect(d.profile.history.isEmpty, isTrue);
    });
  });

  group('pregnancy-loss', () {
    final d = pregnancyLoss();

    test('is the same for a seed and differs between seeds', () {
      expectDeterministic(pregnancyLoss);
    });

    test('survives the document codec', () => expectRoundTrip(d));

    test('has three normal cycles, then one long bleed', () {
      expect(
        [for (final p in d.periods) p.startDate],
        [
          DateTime(2026, 5, 28),
          DateTime(2026, 6, 25),
          DateTime(2026, 7, 23),
          DateTime(2026, 8, 20),
          DateTime(2026, 10, 22),
        ],
      );
      final loss = d.periods.last;
      expect(loss.endDate, DateTime(2026, 11, 16));
      expect(daysBetween(loss.startDate, loss.endDate!) + 1, 26);
    });

    test('has no period while pregnant, only implantation spotting', () {
      final bleeding = [
        for (final l in d.dailyLogs)
          if (l.date.isAfter(DateTime(2026, 8, 24)) &&
              l.date.isBefore(DateTime(2026, 10, 22)) &&
              l.flow.isBleeding)
            (l.date, l.flow),
      ];
      expect(bleeding, [
        (DateTime(2026, 9, 10), FlowIntensity.spotting),
        (DateTime(2026, 9, 11), FlowIntensity.spotting),
      ]);
    });

    test('keeps the temperature up through the pregnancy', () {
      final held = readingsBetween(
        d,
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 21),
      );
      expect(held, isNotEmpty);
      expect(held.every((c) => c >= 36.6), isTrue, reason: '$held');
    });

    test('miscarries on 22 October with heavy flow and severe pain', () {
      final day = d.logFor(DateTime(2026, 10, 22))!;
      expect(day.flow, FlowIntensity.heavy);
      expect(day.painLevel, 8);
      expect(day.symptoms, containsAll([Symptom.cramps, Symptom.backPain]));
    });

    test('has a low-grade fever from 3 November', () {
      final fever = readingsBetween(
        d,
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 24),
      );
      expect(fever, isNotEmpty);
      expect(fever.every((c) => c >= 37.6 && c <= 38.0), isTrue);
      final before = readingsBetween(
        d,
        DateTime(2026, 10, 25),
        DateTime(2026, 11, 2),
      );
      expect(before.every((c) => c < 36.6), isTrue, reason: '$before');
    });

    test('has the profile as it is after the loss', () {
      expect(d.profile.birthYear, 1994);
      expect(
        d.profile.history,
        const ObstetricHistory(pregnancies: 1, births: 0, miscarriages: 1),
      );
    });
  });

  group('seedDocument', () {
    test('is the encoded scenario for its name and seed', () {
      expect(
        seedDocument(['pregnancy-loss', '--seed', '3']),
        codec.encode(pregnancyLoss(seed: 3)),
      );
      expect(seedDocument(['healthy-year']), codec.encode(healthyYear()));
    });

    final bad = <(String, List<String>)>[
      ('no scenario', []),
      ('an unknown scenario', ['nope']),
      ('a seed that is not a number', ['healthy-year', '--seed', 'x']),
      ('a seed with no value', ['healthy-year', '--seed']),
    ];
    for (final (name, args) in bad) {
      test('refuses $name', () {
        expect(() => seedDocument(args), throwsA(isA<UsageException>()));
      });
    }
  });
}
