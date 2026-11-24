import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/health_profile.dart';

void main() {
  usualLengthTests();
  group('HealthProfile', () {
    test('defaults to empty', () {
      final p = HealthProfile();
      expect(p.conditions, isEmpty);
      expect(p.treatments, isEmpty);
      expect(p.notes, '');
      expect(p.isEmpty, isTrue);
    });

    final emptyCases = <({String name, HealthProfile profile, bool want})>[
      (
        name: 'a condition is content',
        profile: HealthProfile(conditions: const {ReproductiveCondition.pcos}),
        want: false,
      ),
      (
        name: 'a treatment is content',
        profile: HealthProfile(treatments: const {FertilityTreatment.ivf}),
        want: false,
      ),
      (
        name: 'a note is content',
        profile: HealthProfile(notes: 'see GP'),
        want: false,
      ),
      (
        name: 'whitespace is not a note',
        profile: HealthProfile(notes: '  \n'),
        want: true,
      ),
    ];
    for (final c in emptyCases) {
      test(c.name, () => expect(c.profile.isEmpty, c.want));
    }

    test('sets cannot be changed after construction', () {
      final p = HealthProfile(conditions: const {ReproductiveCondition.pcos});
      expect(
        () => p.conditions.add(ReproductiveCondition.pmdd),
        throwsUnsupportedError,
      );
    });

    test('copyWith replaces only what is given', () {
      final p = HealthProfile(
        conditions: const {ReproductiveCondition.pcos},
        notes: 'a',
      );
      final changed = p.copyWith(treatments: {FertilityTreatment.iui});
      expect(changed.conditions, {ReproductiveCondition.pcos});
      expect(changed.treatments, {FertilityTreatment.iui});
      expect(changed.notes, 'a');
    });

    test('is equal by value', () {
      final a = HealthProfile(
        conditions: const {
          ReproductiveCondition.pcos,
          ReproductiveCondition.pmdd,
        },
        treatments: const {FertilityTreatment.ivf},
        notes: 'n',
      );
      final b = HealthProfile(
        conditions: const {
          ReproductiveCondition.pmdd,
          ReproductiveCondition.pcos,
        },
        treatments: const {FertilityTreatment.ivf},
        notes: 'n',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(notes: 'm')));
    });

    test('round-trips through JSON', () {
      final p = HealthProfile(
        conditions: const {ReproductiveCondition.endometriosis},
        treatments: const {FertilityTreatment.contraceptive},
        notes: 'n',
      );
      expect(HealthProfile.fromJson(p.toJson()), p);
    });

    test('drops unknown names and tolerates missing keys', () {
      final p = HealthProfile.fromJson(const {
        'conditions': ['pcos', 'gout'],
      });
      expect(p.conditions, {ReproductiveCondition.pcos});
      expect(p.treatments, isEmpty);
      expect(p.notes, '');
    });
  });

  test('ReproductiveCondition.fromName and FertilityTreatment.fromName', () {
    expect(ReproductiveCondition.fromName('pcos'), ReproductiveCondition.pcos);
    expect(ReproductiveCondition.fromName('x'), isNull);
    expect(FertilityTreatment.fromName('ivf'), FertilityTreatment.ivf);
    expect(FertilityTreatment.fromName(null), isNull);
  });
}

void usualLengthTests() {
  test('usual lengths are optional, stored, cleared, and count as content', () {
    final p = HealthProfile(usualCycleLength: 28, usualPeriodLength: 5);
    expect(p.isEmpty, isFalse);
    expect(HealthProfile.fromJson(p.toJson()), p);
    expect(p.toJson()['usualCycleLength'], 28);
    expect(HealthProfile().toJson().containsKey('usualCycleLength'), isFalse);
    expect(p.copyWith(clearUsualCycleLength: true).usualCycleLength, isNull);
    expect(p.copyWith(usualPeriodLength: 6).usualPeriodLength, 6);
    expect(HealthProfile(usualCycleLength: 30), isNot(HealthProfile()));
  });
}
