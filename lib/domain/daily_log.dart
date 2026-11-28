// One day's flow, symptoms and pain rating.

import 'package:collection/collection.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/day.dart';
import 'package:meta/meta.dart';

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

  Symptom(this.label);

  final String label;

  /// The stored name's value, or null so removed symptoms drop silently.
  static Symptom? fromName(String? name) =>
      Symptom.values.firstWhereOrNull((s) => s.name == name);
}

/// An ovulation (LH) test read as positive or negative; a faint line is
/// negative.
enum OvulationTest {
  negative,
  positive;

  /// The stored name's value, or null when absent or unknown.
  static OvulationTest? fromName(String? name) =>
      OvulationTest.values.firstWhereOrNull((t) => t.name == name);
}

const _symptoms = SetEquality<Symptom>();

/// What the user logged for [date], at most one per day.
@immutable
class DailyLog {
  DailyLog({
    required DateTime date,
    this.flow = FlowIntensity.none,
    Set<Symptom> symptoms = const {},
    int? painLevel,
    this.ovulationTest,
    String? note,
    this.contraceptionDoneAt,
    BodySigns? signs,
    // STUB
    // ignore: avoid_unused_constructor_parameters
    bool miscarriage = false,
  }) : date = dateOnly(date),
       symptoms = Set.unmodifiable(symptoms),
       painLevel = painLevel?.clamp(0, 10),
       note = (note == null || note.trim().isEmpty) ? null : note.trim(),
       signs = signs ?? BodySigns.none;

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
    date: DateTime.parse(json['date'] as String),
    flow: FlowIntensity.fromName(json['flow'] as String?),
    symptoms: {
      for (final s in (json['symptoms'] as List? ?? const []))
        ?Symptom.fromName(s as String?),
    },
    painLevel: (json['painLevel'] as num?)?.toInt(),
    ovulationTest: OvulationTest.fromName(json['ovulationTest'] as String?),
    note: json['note'] as String?,
    contraceptionDoneAt: DateTime.tryParse(
      json['contraceptionDoneAt'] as String? ?? '',
    ),
    signs: BodySigns.fromJson(json['signs']),
  );

  final DateTime date;
  final FlowIntensity flow;
  final Set<Symptom> symptoms;

  /// Pain on the 0–10 scale, or null when not rated.
  final int? painLevel;

  /// The day's ovulation test, or null when none was taken.
  final OvulationTest? ovulationTest;

  /// The person's own words for the day, trimmed; null when blank.
  final String? note;

  /// When the day's pill was taken, or its patch or ring done; null when
  /// not marked.
  final DateTime? contraceptionDoneAt;

  /// The day's moods and other body signs; empty when none were logged.
  final BodySigns signs;

  // STUB
  bool get miscarriage => false;

  /// The longest note the Log tab takes.
  static const int maxNoteLength = 1000;

  /// True when there is nothing worth storing for the day.
  bool get isEmpty =>
      flow == FlowIntensity.none &&
      symptoms.isEmpty &&
      painLevel == null &&
      ovulationTest == null &&
      note == null &&
      contraceptionDoneAt == null &&
      signs.isEmpty;

  /// A copy with the given fields replaced. [clearPain],
  /// [clearOvulationTest], [clearNote] and [clearContraceptionDone] unset a
  /// value, since null means "leave it".
  DailyLog copyWith({
    FlowIntensity? flow,
    Set<Symptom>? symptoms,
    int? painLevel,
    bool clearPain = false,
    OvulationTest? ovulationTest,
    bool clearOvulationTest = false,
    String? note,
    bool clearNote = false,
    DateTime? contraceptionDoneAt,
    bool clearContraceptionDone = false,
    BodySigns? signs,
    bool? miscarriage,
  }) => DailyLog(
    contraceptionDoneAt: clearContraceptionDone
        ? null
        : (contraceptionDoneAt ?? this.contraceptionDoneAt),
    note: clearNote ? null : (note ?? this.note),
    signs: signs ?? this.signs,
    date: date,
    flow: flow ?? this.flow,
    symptoms: symptoms ?? this.symptoms,
    painLevel: clearPain ? null : (painLevel ?? this.painLevel),
    ovulationTest: clearOvulationTest
        ? null
        : (ovulationTest ?? this.ovulationTest),
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'flow': flow.name,
    'symptoms': symptoms.map((s) => s.name).toList(),
    if (painLevel != null) 'painLevel': painLevel,
    if (ovulationTest case final t?) 'ovulationTest': t.name,
    'note': ?note,
    if (contraceptionDoneAt case final at?)
      'contraceptionDoneAt': at.toIso8601String(),
    if (!signs.isEmpty) 'signs': signs.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is DailyLog &&
      other.date == date &&
      other.flow == flow &&
      _symptoms.equals(other.symptoms, symptoms) &&
      other.painLevel == painLevel &&
      other.ovulationTest == ovulationTest &&
      other.note == note &&
      other.contraceptionDoneAt == contraceptionDoneAt &&
      other.signs == signs;

  @override
  int get hashCode => Object.hash(
    date,
    flow,
    _symptoms.hash(symptoms),
    painLevel,
    ovulationTest,
    note,
    contraceptionDoneAt,
    signs,
  );
}
