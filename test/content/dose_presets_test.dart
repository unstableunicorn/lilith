import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/content/dose_presets.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/health_profile.dart';

void main() {
  test('each method offers its forms, with sourced windows', () {
    final cases = <(Contraception?, List<(DoseForm, int)>)>[
      (Contraception.combinedPill, [(DoseForm.pill, 24)]),
      (
        Contraception.progestogenOnlyPill,
        [(DoseForm.pill, 3), (DoseForm.pill, 12)],
      ),
      (Contraception.patchOrRing, [(DoseForm.patch, 48), (DoseForm.ring, 48)]),
      (Contraception.implant, []),
      (Contraception.copperIud, []),
      (null, []),
    ];
    for (final (method, want) in cases) {
      expect(
        [for (final p in dosePresetsFor(method)) (p.form, p.windowHours)],
        want,
        reason: '$method',
      );
    }
  });

  test('the progestogen-only pill has no break; the others start '
      'standard and offer every regimen', () {
    for (final p in dosePresetsFor(Contraception.progestogenOnlyPill)) {
      expect(p.regimens, [Regimen.continuous]);
    }
    for (final method in [
      Contraception.combinedPill,
      Contraception.patchOrRing,
    ]) {
      for (final p in dosePresetsFor(method)) {
        expect(p.regimens.first, Regimen.standard);
        expect(p.regimens.toSet(), Regimen.values.toSet());
      }
    }
  });

  test('every preset links its source', () {
    final all = [for (final m in Contraception.values) ...dosePresetsFor(m)];
    expect(all, isNotEmpty);
    for (final p in all) {
      expect(Uri.parse(p.source.url).scheme, 'https');
    }
  });
}
