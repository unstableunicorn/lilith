import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/body_signs.dart';

void main() {
  final full = BodySigns(
    moods: const {Mood.calm, Mood.happy},
    sleep: SleepQuality.poor,
    digestion: const {Digestion.gas},
    skin: const {SkinSign.acne, SkinSign.oily},
    discharge: Discharge.eggWhite,
    pregnancyTest: PregnancyTest.negative,
  );

  group('BodySigns', () {
    test('nothing recorded is empty; any one thing is not', () {
      expect(BodySigns().isEmpty, isTrue);
      expect(BodySigns.none.isEmpty, isTrue);
      expect(BodySigns(moods: const {Mood.sad}).isEmpty, isFalse);
      expect(BodySigns(sleep: SleepQuality.good).isEmpty, isFalse);
      expect(BodySigns(digestion: const {Digestion.gas}).isEmpty, isFalse);
      expect(BodySigns(skin: const {SkinSign.dry}).isEmpty, isFalse);
      expect(BodySigns(discharge: Discharge.dry).isEmpty, isFalse);
      expect(BodySigns(pregnancyTest: PregnancyTest.positive).isEmpty, isFalse);
    });

    test('is a value: equal by what it holds, whatever the order', () {
      final same = BodySigns(
        moods: const {Mood.happy, Mood.calm},
        sleep: SleepQuality.poor,
        digestion: const {Digestion.gas},
        skin: const {SkinSign.oily, SkinSign.acne},
        discharge: Discharge.eggWhite,
        pregnancyTest: PregnancyTest.negative,
      );
      expect(same, full);
      expect(same.hashCode, full.hashCode);
      expect(full, isNot(BodySigns()));
      expect(full, isNot(full.copyWith(sleep: SleepQuality.good)));
    });

    test('round-trips through JSON', () {
      final json = jsonDecode(jsonEncode(full.toJson()));
      expect(BodySigns.fromJson(json), full);
    });

    test('writes only what is recorded', () {
      expect(BodySigns().toJson(), isEmpty);
      expect(BodySigns(sleep: SleepQuality.okay).toJson(), {'sleep': 'okay'});
      expect(BodySigns(moods: const {Mood.low}).toJson(), {
        'moods': ['low'],
      });
    });

    test('skips anything it does not know, and reads nothing as none', () {
      expect(BodySigns.fromJson(null), BodySigns());
      expect(BodySigns.fromJson('nonsense'), BodySigns());
      expect(
        BodySigns.fromJson(const {
          'moods': ['calm', 'giddy', 3],
          'sleep': 'dreamless',
          'digestion': 'gas',
          'skin': ['dry', 'glowing'],
          'discharge': 'creamy',
          'pregnancyTest': 'faint',
          'aura': 'purple',
        }),
        BodySigns(
          moods: const {Mood.calm},
          skin: const {SkinSign.dry},
          discharge: Discharge.creamy,
        ),
      );
    });

    test('copyWith replaces a field and keeps the rest', () {
      final changed = full.copyWith(moods: const {Mood.sad});
      expect(changed.moods, {Mood.sad});
      expect(changed.sleep, SleepQuality.poor);
      expect(changed.skin, full.skin);
      expect(changed.pregnancyTest, PregnancyTest.negative);
    });

    test('copyWith clears a single value only when told to', () {
      expect(full.copyWith().sleep, SleepQuality.poor);
      expect(full.copyWith(clearSleep: true).sleep, isNull);
      expect(full.copyWith(clearDischarge: true).discharge, isNull);
      expect(full.copyWith(clearPregnancyTest: true).pregnancyTest, isNull);
      expect(full.copyWith(clearSleep: true).discharge, Discharge.eggWhite);
    });

    test('what is shared never holds the pregnancy test', () {
      expect(full.shared.pregnancyTest, isNull);
      expect(full.shared, full.copyWith(clearPregnancyTest: true));
      expect(
        BodySigns(pregnancyTest: PregnancyTest.positive).shared.isEmpty,
        isTrue,
      );
    });

    test('says what is recorded, in the order of the Log tab', () {
      expect(BodySigns().summaryParts, isEmpty);
      expect(full.summaryParts, [
        'happy',
        'calm',
        'sleep poor',
        'gas',
        'acne skin',
        'oily skin',
        'discharge egg-white',
        'pregnancy test negative',
      ]);
    });
  });

  group('LogGroup', () {
    test('only moods show until the person chooses', () {
      expect(LogGroup.defaults, {LogGroup.moods});
    });

    test('reads its names, skipping unknown ones', () {
      expect(LogGroup.fromNames(['sleep', 'skin', 'auras', 4]), {
        LogGroup.sleep,
        LogGroup.skin,
      });
      expect(LogGroup.fromNames(const <Object>[]), isEmpty);
    });

    test('anything that is not a list is no choice at all', () {
      expect(LogGroup.fromNames(null), isNull);
      expect(LogGroup.fromNames('moods'), isNull);
    });
  });
}
