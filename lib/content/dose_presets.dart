// What each pill, patch or ring starts with: its form, how late still
// counts as on time, and the regimens offered, with the source for each.

import 'package:lilith/content/symptom_advice.dart' show Source;
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/health_profile.dart';

/// One method as offered on the reminder setup.
class DosePreset {
  const DosePreset({
    required this.label,
    required this.form,
    required this.windowHours,
    required this.regimens,
    required this.source,
  });

  final String label;
  final DoseForm form;

  /// The default for how late still counts as on time; the user can
  /// change it.
  final int windowHours;

  /// The regimens offered, the first the default.
  final List<Regimen> regimens;
  final Source source;
}

const Source _incorrectUseOfChc = Source(
  'FSRH: Recommended actions after incorrect use of combined hormonal '
      'contraception (2020, amended 2021)',
  'https://www.cosrh.org/Common/Uploaded%20files/documents/'
      'fsrh-ceu-recommended-actions-after-incorrect-use-of-chc-march-2020-'
      'amended-jul-2021-.pdf',
);

const Source _progestogenOnlyPill = Source(
  'NHS West of Scotland: Progestogen-only pill guideline (2025)',
  'https://www.wossexualhealthmcn.scot.nhs.uk/wp-content/uploads/2025/12/'
      'WOS-POP-Final-2025_June-version-10.3.pdf',
);

/// The FSRH CHC guideline's regimens, standard first.
const List<Regimen> _combinedRegimens = [
  Regimen.standard,
  Regimen.shortenedBreak,
  Regimen.tricycling,
  Regimen.continuous,
];

/// The presets for [method]; none for a method without a schedule.
List<DosePreset> dosePresetsFor(Contraception? method) => switch (method) {
  Contraception.combinedPill => const [
    DosePreset(
      label: 'Combined pill',
      form: DoseForm.pill,
      windowHours: 24,
      regimens: _combinedRegimens,
      source: _incorrectUseOfChc,
    ),
  ],
  Contraception.progestogenOnlyPill => const [
    DosePreset(
      label: 'Traditional progestogen-only pill',
      form: DoseForm.pill,
      windowHours: 3,
      regimens: [Regimen.continuous],
      source: _progestogenOnlyPill,
    ),
    DosePreset(
      label: 'Desogestrel progestogen-only pill',
      form: DoseForm.pill,
      windowHours: 12,
      regimens: [Regimen.continuous],
      source: _progestogenOnlyPill,
    ),
  ],
  Contraception.patchOrRing => const [
    DosePreset(
      label: 'Patch',
      form: DoseForm.patch,
      windowHours: 48,
      regimens: _combinedRegimens,
      source: _incorrectUseOfChc,
    ),
    DosePreset(
      label: 'Vaginal ring',
      form: DoseForm.ring,
      windowHours: 48,
      regimens: _combinedRegimens,
      source: _incorrectUseOfChc,
    ),
  ],
  _ => const [],
};
