// One day's flow, symptoms and pain rating.

import 'package:collection/collection.dart';
import 'package:lilith/domain/day.dart';

/// How heavy the flow was, from no bleeding to heavy.
enum FlowIntensity {
  none,
  spotting,
  light,
  medium,
  heavy;

  /// A 0–4 magnitude for charts.
  int get level => index;

  bool get isBleeding => this != FlowIntensity.none;

  /// The stored name's value, or [none] when unknown or missing.
  static FlowIntensity fromName(String? name) => FlowIntensity.values
      .firstWhere((f) => f.name == name, orElse: () => FlowIntensity.none);
}

/// A symptom the user can tag on a day. [name] is the storage key and the key
/// into the relief content.
enum Symptom {
  cramps('Cramps'),
  bloating('Bloating'),
  fatigue('Fatigue'),
  mood('Mood swings'),
  headache('Headache'),
  backPain('Back pain'),
  breastTenderness('Breast tenderness'),
  nausea('Nausea'),
  insomnia('Insomnia'),
  cravings('Cravings');

  const Symptom(this.label);

  final String label;

  /// The stored name's value, or null so removed symptoms drop silently.
  static Symptom? fromName(String? name) =>
      Symptom.values.firstWhereOrNull((s) => s.name == name);
}

const _symptoms = SetEquality<Symptom>();

/// What the user logged for [date], at most one per day.
class DailyLog {
  DailyLog({
    required DateTime date,
    this.flow = FlowIntensity.none,
    Set<Symptom> symptoms = const {},
    int? painLevel,
  }) : date = dateOnly(date),
       symptoms = Set.unmodifiable(symptoms),
       painLevel = painLevel?.clamp(0, 10);

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
    date: DateTime.parse(json['date'] as String),
    flow: FlowIntensity.fromName(json['flow'] as String?),
    symptoms: {
      for (final s in (json['symptoms'] as List? ?? const []))
        ?Symptom.fromName(s as String?),
    },
    painLevel: (json['painLevel'] as num?)?.toInt(),
  );

  final DateTime date;
  final FlowIntensity flow;
  final Set<Symptom> symptoms;

  /// Pain on the 0–10 scale, or null when not rated.
  final int? painLevel;

  /// True when there is nothing worth storing for the day.
  bool get isEmpty =>
      flow == FlowIntensity.none && symptoms.isEmpty && painLevel == null;

  /// A copy with the given fields replaced. [clearPain] unsets the rating,
  /// since a null [painLevel] means "leave it".
  DailyLog copyWith({
    FlowIntensity? flow,
    Set<Symptom>? symptoms,
    int? painLevel,
    bool clearPain = false,
  }) => DailyLog(
    date: date,
    flow: flow ?? this.flow,
    symptoms: symptoms ?? this.symptoms,
    painLevel: clearPain ? null : (painLevel ?? this.painLevel),
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'flow': flow.name,
    'symptoms': symptoms.map((s) => s.name).toList(),
    if (painLevel != null) 'painLevel': painLevel,
  };

  @override
  bool operator ==(Object other) =>
      other is DailyLog &&
      other.date == date &&
      other.flow == flow &&
      _symptoms.equals(other.symptoms, symptoms) &&
      other.painLevel == painLevel;

  @override
  int get hashCode =>
      Object.hash(date, flow, _symptoms.hash(symptoms), painLevel);
}
