// The user's reproductive-health context: conditions, treatments, notes.

import 'package:collection/collection.dart';

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

  const ReproductiveCondition(this.label);

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

  const FertilityTreatment(this.label);

  final String label;

  static FertilityTreatment? fromName(String? name) =>
      FertilityTreatment.values.firstWhereOrNull((t) => t.name == name);
}

const _conditions = SetEquality<ReproductiveCondition>();
const _treatments = SetEquality<FertilityTreatment>();

/// Conditions, treatments and free-text notes kept beside the cycle data.
class HealthProfile {
  HealthProfile({
    Set<ReproductiveCondition> conditions = const {},
    Set<FertilityTreatment> treatments = const {},
    this.notes = '',
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
  );

  final Set<ReproductiveCondition> conditions;
  final Set<FertilityTreatment> treatments;
  final String notes;

  /// True when there is nothing worth storing.
  bool get isEmpty =>
      conditions.isEmpty && treatments.isEmpty && notes.trim().isEmpty;

  HealthProfile copyWith({
    Set<ReproductiveCondition>? conditions,
    Set<FertilityTreatment>? treatments,
    String? notes,
  }) => HealthProfile(
    conditions: conditions ?? this.conditions,
    treatments: treatments ?? this.treatments,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'conditions': conditions.map((c) => c.name).toList(),
    'treatments': treatments.map((t) => t.name).toList(),
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is HealthProfile &&
      _conditions.equals(other.conditions, conditions) &&
      _treatments.equals(other.treatments, treatments) &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    _conditions.hash(conditions),
    _treatments.hash(treatments),
    notes,
  );
}
