import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_profile.dart';

void main() {
  final start = DateTime(2026, 3, 2);

  ContraceptionSchedule schedule(DoseForm form, Regimen r) =>
      ContraceptionSchedule(
        form: form,
        start: start,
        daysOn: r.daysOn,
        daysOff: r.daysOff,
        windowHours: 12,
      );

  final cases = <(String, DoseForm, Regimen, int, DoseStep?)>[
    (
      'pill: the day before the start',
      DoseForm.pill,
      Regimen.standard,
      -1,
      null,
    ),
    ('pill: day 1', DoseForm.pill, Regimen.standard, 0, DoseStep.take),
    ('pill: day 21', DoseForm.pill, Regimen.standard, 20, DoseStep.take),
    ('pill: first break day', DoseForm.pill, Regimen.standard, 21, null),
    ('pill: last break day', DoseForm.pill, Regimen.standard, 27, null),
    ('pill: the next pack', DoseForm.pill, Regimen.standard, 28, DoseStep.take),
    ('pill: a 4-day break', DoseForm.pill, Regimen.shortenedBreak, 24, null),
    (
      'pill: after a 4-day break',
      DoseForm.pill,
      Regimen.shortenedBreak,
      25,
      DoseStep.take,
    ),
    (
      'pill: tricycling, day 63',
      DoseForm.pill,
      Regimen.tricycling,
      62,
      DoseStep.take,
    ),
    (
      'pill: tricycling, its break',
      DoseForm.pill,
      Regimen.tricycling,
      63,
      null,
    ),
    (
      'pill: tricycling, after it',
      DoseForm.pill,
      Regimen.tricycling,
      70,
      DoseStep.take,
    ),
    ('pill: continuous', DoseForm.pill, Regimen.continuous, 100, DoseStep.take),
    ('patch: day 1', DoseForm.patch, Regimen.standard, 0, DoseStep.newPatch),
    ('patch: between changes', DoseForm.patch, Regimen.standard, 3, null),
    (
      'patch: second week',
      DoseForm.patch,
      Regimen.standard,
      7,
      DoseStep.newPatch,
    ),
    (
      'patch: third week',
      DoseForm.patch,
      Regimen.standard,
      14,
      DoseStep.newPatch,
    ),
    (
      'patch: off for the break',
      DoseForm.patch,
      Regimen.standard,
      21,
      DoseStep.removePatch,
    ),
    ('patch: during the break', DoseForm.patch, Regimen.standard, 22, null),
    (
      'patch: after the break',
      DoseForm.patch,
      Regimen.standard,
      28,
      DoseStep.newPatch,
    ),
    (
      'patch: continuous, no break',
      DoseForm.patch,
      Regimen.continuous,
      21,
      DoseStep.newPatch,
    ),
    ('ring: day 1', DoseForm.ring, Regimen.standard, 0, DoseStep.insertRing),
    ('ring: while worn', DoseForm.ring, Regimen.standard, 10, null),
    (
      'ring: out for the break',
      DoseForm.ring,
      Regimen.standard,
      21,
      DoseStep.removeRing,
    ),
    ('ring: during the break', DoseForm.ring, Regimen.standard, 24, null),
    (
      'ring: after the break',
      DoseForm.ring,
      Regimen.standard,
      28,
      DoseStep.insertRing,
    ),
    (
      'ring: continuous, changed',
      DoseForm.ring,
      Regimen.continuous,
      21,
      DoseStep.changeRing,
    ),
  ];
  for (final (name, form, regimen, day, want) in cases) {
    test(name, () {
      expect(schedule(form, regimen).stepOn(addDays(start, day)), want);
    });
  }

  group('stored in the profile', () {
    final ring = ContraceptionSchedule(
      form: DoseForm.ring,
      start: start,
      daysOn: 21,
      daysOff: 7,
      windowHours: 48,
      hour: 20,
      minute: 30,
      quietHours: true,
    );

    test('round-trips with the profile', () {
      final p = HealthProfile(
        contraception: Contraception.patchOrRing,
        contraceptionSchedule: ring,
      );
      expect(p.isEmpty, isFalse);
      expect(HealthProfile.fromJson(p.toJson()), p);
      expect(
        HealthProfile.fromJson(p.toJson()).contraceptionSchedule?.quietHours,
        isTrue,
      );
    });

    test('loads absent from a profile that lacks it', () {
      expect(HealthProfile.fromJson(const {}).contraceptionSchedule, isNull);
      expect(
        HealthProfile().toJson().containsKey('contraceptionSchedule'),
        isFalse,
      );
    });

    final broken = <(String, Object?)>[
      ('not a map', 'ring'),
      ('an unknown form', {...ring.toJson(), 'form': 'spray'}),
      ('no start', {...ring.toJson()}..remove('start')),
      ('no days on', {...ring.toJson(), 'daysOn': 0}),
      ('a negative break', {...ring.toJson(), 'daysOff': -1}),
      ('no window', {...ring.toJson()}..remove('windowHours')),
    ];
    for (final (name, json) in broken) {
      test('drops one with $name', () {
        expect(ring.toJson(), isNotEmpty);
        expect(ContraceptionSchedule.tryFromJson(json), isNull);
      });
    }

    test('cleared with unset', () {
      final p = HealthProfile(contraceptionSchedule: ring);
      expect(
        p.copyWith(unset: const {'contraceptionSchedule'}).isEmpty,
        isTrue,
      );
    });
  });

  test('a break started today pauses, then the doses carry on', () {
    final today = addDays(start, 40);
    final paused = schedule(
      DoseForm.pill,
      Regimen.continuous,
    ).startBreak(today);
    expect(
      [for (var d = 0; d < 6; d++) paused.stepOn(addDays(today, d))],
      [null, null, null, null, DoseStep.take, DoseStep.take],
    );
  });
}
