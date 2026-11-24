// The user's reproductive-health context: conditions, treatments, notes.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// A diagnosed condition that affects the cycle.
enum ReproductiveCondition {
  endometriosis('Endometriosis'),
  pcos('PCOS'),
  dysmenorrhea('Dysmenorrhea (painful periods)'),
  adenomyosis('Adenomyosis'),
  fibroids('Uterine fibroids'),
  pmdd('PMDD'),
  ovarianCysts('Ovarian cysts'),
  thyroidDisorder('Thyroid disorder'),
  perimenopause('Perimenopause');

  ReproductiveCondition(this.label);

  final String label;

  static ReproductiveCondition? fromName(String? name) =>
      ReproductiveCondition.values.firstWhereOrNull((c) => c.name == name);
}

/// A fertility treatment or goal the user is engaged with.
enum FertilityTreatment {
  tryingToConceive('Trying to conceive'),
  ivf('IVF'),
  iui('IUI'),
  ovulationInduction('Ovulation induction'),
  hormoneTherapy('Hormone therapy'),
  eggFreezing('Egg freezing'),
  contraceptive('Hormonal contraceptive');

  FertilityTreatment(this.label);

  final String label;

  static FertilityTreatment? fromName(String? name) =>
      FertilityTreatment.values.firstWhereOrNull((t) => t.name == name);
}

const _conditions = SetEquality<ReproductiveCondition>();
const _treatments = SetEquality<FertilityTreatment>();

/// Conditions, treatments and free-text notes kept beside the cycle data.
/// The contraception in use, if any. Hormonal methods stop ovulation or
/// mask the temperature shift, so the predictor stops looking for one.
enum Contraception {
  none('None', isHormonal: false),
  combinedPill('Combined pill', isHormonal: true),
  progestogenOnlyPill('Progestogen-only pill', isHormonal: true),
  hormonalIud('Hormonal IUD', isHormonal: true),
  copperIud('Copper IUD', isHormonal: false),
  implant('Implant', isHormonal: true),
  injection('Injection', isHormonal: true),
  patchOrRing('Patch or vaginal ring', isHormonal: true),
  other('Other', isHormonal: false);

  Contraception(this.label, {required this.isHormonal});

  final String label;
  final bool isHormonal;

  static Contraception? fromName(String? name) =>
      Contraception.values.firstWhereOrNull((c) => c.name == name);
}

/// How regular the cycles are, as the user sees them.
enum CycleRegularity {
  regular('Regular'),
  somewhatIrregular('Somewhat irregular'),
  irregular('Irregular');

  CycleRegularity(this.label);

  final String label;

  static CycleRegularity? fromName(String? name) =>
      CycleRegularity.values.firstWhereOrNull((r) => r.name == name);
}

/// Pregnancies so far, all optional, for the doctor's report.
@immutable
class ObstetricHistory {
  const ObstetricHistory({
    this.pregnancies,
    this.births,
    this.miscarriages,
    this.lastPregnancyYear,
  });

  factory ObstetricHistory.fromJson(Map<String, dynamic> json) =>
      ObstetricHistory(
        pregnancies: (json['pregnancies'] as num?)?.toInt(),
        births: (json['births'] as num?)?.toInt(),
        miscarriages: (json['miscarriages'] as num?)?.toInt(),
        lastPregnancyYear: (json['lastPregnancyYear'] as num?)?.toInt(),
      );

  final int? pregnancies;
  final int? births;
  final int? miscarriages;
  final int? lastPregnancyYear;

  bool get isEmpty =>
      pregnancies == null &&
      births == null &&
      miscarriages == null &&
      lastPregnancyYear == null;

  /// A null argument means "unchanged"; [unset] names the fields to clear.
  ObstetricHistory copyWith({
    int? pregnancies,
    int? births,
    int? miscarriages,
    int? lastPregnancyYear,
    Set<String> unset = const {},
  }) => ObstetricHistory(
    pregnancies: unset.contains('pregnancies')
        ? null
        : pregnancies ?? this.pregnancies,
    births: unset.contains('births') ? null : births ?? this.births,
    miscarriages: unset.contains('miscarriages')
        ? null
        : miscarriages ?? this.miscarriages,
    lastPregnancyYear: unset.contains('lastPregnancyYear')
        ? null
        : lastPregnancyYear ?? this.lastPregnancyYear,
  );

  Map<String, dynamic> toJson() => {
    if (pregnancies != null) 'pregnancies': pregnancies,
    if (births != null) 'births': births,
    if (miscarriages != null) 'miscarriages': miscarriages,
    if (lastPregnancyYear != null) 'lastPregnancyYear': lastPregnancyYear,
  };

  @override
  bool operator ==(Object other) =>
      other is ObstetricHistory &&
      other.pregnancies == pregnancies &&
      other.births == births &&
      other.miscarriages == miscarriages &&
      other.lastPregnancyYear == lastPregnancyYear;

  @override
  int get hashCode =>
      Object.hash(pregnancies, births, miscarriages, lastPregnancyYear);
}

@immutable
class HealthProfile {
  HealthProfile({
    Set<ReproductiveCondition> conditions = const {},
    Set<FertilityTreatment> treatments = const {},
    this.notes = '',
    this.usualCycleLength,
    this.usualPeriodLength,
    this.birthYear,
    this.contraception,
    this.regularity,
    this.history = const ObstetricHistory(),
  }) : conditions = Set.unmodifiable(conditions),
       treatments = Set.unmodifiable(treatments);

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
    conditions: {
      for (final c in (json['conditions'] as List? ?? const []))
        ?ReproductiveCondition.fromName(c as String?),
    },
    treatments: {
      for (final t in (json['treatments'] as List? ?? const []))
        ?FertilityTreatment.fromName(t as String?),
    },
    notes: json['notes'] as String? ?? '',
    usualCycleLength: (json['usualCycleLength'] as num?)?.toInt(),
    usualPeriodLength: (json['usualPeriodLength'] as num?)?.toInt(),
    birthYear: (json['birthYear'] as num?)?.toInt(),
    contraception: Contraception.fromName(json['contraception'] as String?),
    regularity: CycleRegularity.fromName(json['regularity'] as String?),
    history: switch (json['history']) {
      final Map<String, dynamic> h => ObstetricHistory.fromJson(h),
      _ => const ObstetricHistory(),
    },
  );

  /// What the app accepts as a usual cycle length, in days.
  static const int minCycleLength = 15;
  static const int maxCycleLength = 60;

  /// What the app accepts as a usual period length, in days.
  static const int minPeriodLength = 1;
  static const int maxPeriodLength = 10;

  final Set<ReproductiveCondition> conditions;
  final Set<FertilityTreatment> treatments;
  final String notes;

  /// The user's own idea of their cycle and period length, in days, used
  /// only until real cycles have been logged.
  final int? usualCycleLength;
  final int? usualPeriodLength;

  final int? birthYear;
  final Contraception? contraception;
  final CycleRegularity? regularity;
  final ObstetricHistory history;

  /// Hormonal contraception, said either way: through [contraception] or
  /// the older treatment flag.
  bool get usesHormonalContraception =>
      contraception?.isHormonal == true ||
      treatments.contains(FertilityTreatment.contraceptive);

  /// True when there is nothing worth storing.
  bool get isEmpty =>
      conditions.isEmpty &&
      treatments.isEmpty &&
      notes.trim().isEmpty &&
      usualCycleLength == null &&
      usualPeriodLength == null &&
      birthYear == null &&
      contraception == null &&
      regularity == null &&
      history.isEmpty;

  /// A null argument means "unchanged"; [unset] names the optional fields
  /// to clear: `usualCycleLength`, `usualPeriodLength`, `birthYear`,
  /// `contraception`, `regularity`. The clear flags for the usual lengths
  /// stay for the callers that use them.
  HealthProfile copyWith({
    Set<ReproductiveCondition>? conditions,
    Set<FertilityTreatment>? treatments,
    String? notes,
    int? usualCycleLength,
    bool clearUsualCycleLength = false,
    int? usualPeriodLength,
    bool clearUsualPeriodLength = false,
    int? birthYear,
    Contraception? contraception,
    CycleRegularity? regularity,
    ObstetricHistory? history,
    Set<String> unset = const {},
  }) => HealthProfile(
    conditions: conditions ?? this.conditions,
    treatments: treatments ?? this.treatments,
    notes: notes ?? this.notes,
    usualCycleLength:
        clearUsualCycleLength || unset.contains('usualCycleLength')
        ? null
        : usualCycleLength ?? this.usualCycleLength,
    usualPeriodLength:
        clearUsualPeriodLength || unset.contains('usualPeriodLength')
        ? null
        : usualPeriodLength ?? this.usualPeriodLength,
    birthYear: unset.contains('birthYear') ? null : birthYear ?? this.birthYear,
    contraception: unset.contains('contraception')
        ? null
        : contraception ?? this.contraception,
    regularity: unset.contains('regularity')
        ? null
        : regularity ?? this.regularity,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'conditions': conditions.map((c) => c.name).toList(),
    'treatments': treatments.map((t) => t.name).toList(),
    'notes': notes,
    if (usualCycleLength != null) 'usualCycleLength': usualCycleLength,
    if (usualPeriodLength != null) 'usualPeriodLength': usualPeriodLength,
    if (birthYear != null) 'birthYear': birthYear,
    if (contraception != null) 'contraception': contraception!.name,
    if (regularity != null) 'regularity': regularity!.name,
    if (!history.isEmpty) 'history': history.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is HealthProfile &&
      _conditions.equals(other.conditions, conditions) &&
      _treatments.equals(other.treatments, treatments) &&
      other.notes == notes &&
      other.usualCycleLength == usualCycleLength &&
      other.usualPeriodLength == usualPeriodLength &&
      other.birthYear == birthYear &&
      other.contraception == contraception &&
      other.regularity == regularity &&
      other.history == history;

  @override
  int get hashCode => Object.hash(
    _conditions.hash(conditions),
    _treatments.hash(treatments),
    notes,
    usualCycleLength,
    usualPeriodLength,
    birthYear,
    contraception,
    regularity,
    history,
  );
}
