// What a day's log holds beyond flow, symptoms and pain: moods and the
// body's other signs. Each group can be hidden from the Log tab.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// A mood tagged on a day; several can apply.
enum Mood {
  happy('Happy'),
  calm('Calm'),
  energetic('Energetic'),
  sensitive('Sensitive'),
  sad('Sad'),
  anxious('Anxious'),
  irritable('Irritable'),
  low('Low');

  Mood(this.label);
  final String label;
}

/// How the night's sleep was.
enum SleepQuality {
  good('Good'),
  okay('Okay'),
  poor('Poor');

  SleepQuality(this.label);
  final String label;
}

/// A digestive sign tagged on a day. Bloating and nausea are symptoms.
enum Digestion {
  constipation('Constipation'),
  diarrhoea('Diarrhoea'),
  gas('Gas'),
  indigestion('Indigestion');

  Digestion(this.label);
  final String label;
}

/// A skin sign tagged on a day.
enum SkinSign {
  acne('Acne'),
  oily('Oily'),
  dry('Dry');

  SkinSign(this.label);
  final String label;
}

/// The day's cervical mucus, from driest to most fertile.
enum Discharge {
  dry('Dry'),
  sticky('Sticky'),
  creamy('Creamy'),
  watery('Watery'),
  eggWhite('Egg-white');

  Discharge(this.label);
  final String label;
}

/// A home pregnancy test's result.
enum PregnancyTest {
  negative('Negative'),
  positive('Positive');

  PregnancyTest(this.label);
  final String label;
}

/// A group of the Log tab that can be shown or hidden.
enum LogGroup {
  moods('Moods'),
  sleep('Sleep quality'),
  digestion('Digestion'),
  skin('Skin'),
  discharge('Discharge'),
  pregnancyTest('Pregnancy test');

  LogGroup(this.label);
  final String label;

  /// The groups shown until the person chooses: moods only, so Log stays
  /// short.
  static const Set<LogGroup> defaults = {moods};

  /// The groups written as [names]; null when [names] is not a list, and
  /// unknown names are skipped.
  static Set<LogGroup>? fromNames(Object? names) =>
      names is List ? _known(values, names) : null;
}

/// The one of [values] stored as [name]; null when absent or unknown.
T? _one<T extends Enum>(List<T> values, Object? name) =>
    values.firstWhereOrNull((v) => v.name == name);

/// Those of [values] stored in [names], in the enum's order; anything else
/// in the list, and anything that is not a list, is skipped.
Set<T> _known<T extends Enum>(List<T> values, Object? names) => {
  if (names is List)
    for (final v in values)
      if (names.contains(v.name)) v,
};

const _moods = SetEquality<Mood>();
const _digestion = SetEquality<Digestion>();
const _skin = SetEquality<SkinSign>();

@immutable
class BodySigns {
  BodySigns({
    Set<Mood> moods = const {},
    this.sleep,
    Set<Digestion> digestion = const {},
    Set<SkinSign> skin = const {},
    this.discharge,
    this.pregnancyTest,
  }) : moods = Set.unmodifiable(moods),
       digestion = Set.unmodifiable(digestion),
       skin = Set.unmodifiable(skin);

  /// Reads what was stored; anything unknown or missing is skipped.
  factory BodySigns.fromJson(Object? json) => json is Map
      ? BodySigns(
          moods: _known(Mood.values, json['moods']),
          sleep: _one(SleepQuality.values, json['sleep']),
          digestion: _known(Digestion.values, json['digestion']),
          skin: _known(SkinSign.values, json['skin']),
          discharge: _one(Discharge.values, json['discharge']),
          pregnancyTest: _one(PregnancyTest.values, json['pregnancyTest']),
        )
      : BodySigns();

  static final BodySigns none = BodySigns();

  final Set<Mood> moods;
  final SleepQuality? sleep;
  final Set<Digestion> digestion;
  final Set<SkinSign> skin;
  final Discharge? discharge;
  final PregnancyTest? pregnancyTest;

  /// True when nothing is recorded.
  bool get isEmpty =>
      moods.isEmpty &&
      sleep == null &&
      digestion.isEmpty &&
      skin.isEmpty &&
      discharge == null &&
      pregnancyTest == null;

  /// What goes to someone the day is shared with: everything but the
  /// pregnancy test, which is never shared.
  BodySigns get shared => copyWith(clearPregnancyTest: true);

  /// A copy with the given fields replaced. The `clear…` flags unset a
  /// single value, since null means "leave it".
  BodySigns copyWith({
    Set<Mood>? moods,
    SleepQuality? sleep,
    bool clearSleep = false,
    Set<Digestion>? digestion,
    Set<SkinSign>? skin,
    Discharge? discharge,
    bool clearDischarge = false,
    PregnancyTest? pregnancyTest,
    bool clearPregnancyTest = false,
  }) => BodySigns(
    moods: moods ?? this.moods,
    sleep: clearSleep ? null : (sleep ?? this.sleep),
    digestion: digestion ?? this.digestion,
    skin: skin ?? this.skin,
    discharge: clearDischarge ? null : (discharge ?? this.discharge),
    pregnancyTest: clearPregnancyTest
        ? null
        : (pregnancyTest ?? this.pregnancyTest),
  );

  /// What is recorded, in words, in the order of the Log tab: "happy,
  /// calm", "sleep poor", "discharge egg-white", "pregnancy test negative".
  List<String> get summaryParts => [
    for (final m in Mood.values.where(moods.contains)) m.label.toLowerCase(),
    if (sleep case final s?) 'sleep ${s.label.toLowerCase()}',
    for (final d in Digestion.values.where(digestion.contains))
      d.label.toLowerCase(),
    for (final s in SkinSign.values.where(skin.contains))
      '${s.label.toLowerCase()} skin',
    if (discharge case final d?) 'discharge ${d.label.toLowerCase()}',
    if (pregnancyTest case final t?) 'pregnancy test ${t.label.toLowerCase()}',
  ];

  Map<String, dynamic> toJson() => {
    if (moods.isNotEmpty) 'moods': [for (final m in moods) m.name],
    'sleep': ?sleep?.name,
    if (digestion.isNotEmpty) 'digestion': [for (final d in digestion) d.name],
    if (skin.isNotEmpty) 'skin': [for (final s in skin) s.name],
    'discharge': ?discharge?.name,
    'pregnancyTest': ?pregnancyTest?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is BodySigns &&
      _moods.equals(other.moods, moods) &&
      other.sleep == sleep &&
      _digestion.equals(other.digestion, digestion) &&
      _skin.equals(other.skin, skin) &&
      other.discharge == discharge &&
      other.pregnancyTest == pregnancyTest;

  @override
  int get hashCode => Object.hash(
    _moods.hash(moods),
    sleep,
    _digestion.hash(digestion),
    _skin.hash(skin),
    discharge,
    pregnancyTest,
  );
}
