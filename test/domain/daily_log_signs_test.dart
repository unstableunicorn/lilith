import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/health_data.dart';

/// Moods and body signs in a day's log, and which groups the Log tab shows.
void main() {
  final day = DateTime(2026, 6, 2);
  final signs = BodySigns(
    moods: const {Mood.calm},
    sleep: SleepQuality.poor,
    pregnancyTest: PregnancyTest.negative,
  );
  const codec = HealthDocumentCodec();

  group('DailyLog.signs', () {
    test('a day starts with none', () {
      expect(DailyLog(date: day).signs, BodySigns.none);
      expect(DailyLog(date: day).isEmpty, isTrue);
    });

    test('a day with only signs is worth storing', () {
      final log = DailyLog(date: day, signs: signs);
      expect(log.signs, signs);
      expect(log.isEmpty, isFalse);
    });

    test('is part of the value', () {
      final log = DailyLog(date: day, signs: signs);
      expect(log, DailyLog(date: day, signs: signs));
      expect(log.hashCode, DailyLog(date: day, signs: signs).hashCode);
      expect(log, isNot(DailyLog(date: day)));
    });

    test('copyWith replaces the signs and otherwise keeps them', () {
      final log = DailyLog(date: day, signs: signs, painLevel: 3);
      expect(log.copyWith(painLevel: 4).signs, signs);
      expect(log.copyWith(signs: BodySigns.none).signs, BodySigns.none);
      expect(log.copyWith(signs: BodySigns.none).painLevel, 3);
    });

    test('round-trips through JSON, nested under one key', () {
      final log = DailyLog(date: day, signs: signs);
      final json = jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>;
      expect(json['signs'], signs.toJson());
      expect(DailyLog.fromJson(json), log);
    });

    test('a day without signs writes no key for them', () {
      expect(DailyLog(date: day).toJson().containsKey('signs'), isFalse);
    });

    test('a log written before signs existed loads with none', () {
      final log = DailyLog.fromJson(const {
        'date': '2026-06-02T00:00:00.000',
        'flow': 'light',
        'symptoms': <String>[],
      });
      expect(log.signs, BodySigns.none);
    });

    test('signs round-trip in the pod document without a version bump', () {
      final data = HealthData.empty.withDailyLog(
        DailyLog(date: day, signs: signs),
      );
      final json = jsonDecode(codec.encode(data)) as Map<String, dynamic>;
      expect(json['version'], 8);
      expect(codec.decode(codec.encode(data)), data);
    });
  });

  group('HealthData.shownLogGroups', () {
    test('moods and tags show until the person chooses', () {
      expect(HealthData.empty.shownLogGroups, {LogGroup.moods, LogGroup.tags});
    });

    test('showing a group adds it and keeps the rest', () {
      final data = HealthData.empty.withLogGroup(LogGroup.sleep, shown: true);
      expect(data.shownLogGroups, {
        LogGroup.moods,
        LogGroup.sleep,
        LogGroup.tags,
      });
      expect(data, isNot(HealthData.empty));
      expect(data.hashCode, isNot(HealthData.empty.hashCode));
    });

    test('hiding a group removes it, moods included', () {
      final data = HealthData.empty.withLogGroup(LogGroup.moods, shown: false);
      expect(data.shownLogGroups, {LogGroup.tags});
    });

    test('the choice survives another change', () {
      final data = HealthData.empty
          .withLogGroup(LogGroup.skin, shown: true)
          .withDailyLog(DailyLog(date: day, painLevel: 2));
      expect(data.shownLogGroups, {
        LogGroup.moods,
        LogGroup.skin,
        LogGroup.tags,
      });
    });

    test('round-trips in the pod document without a version bump', () {
      final data = HealthData.empty
          .withLogGroup(LogGroup.moods, shown: false)
          .withLogGroup(LogGroup.discharge, shown: true);
      final json = jsonDecode(codec.encode(data)) as Map<String, dynamic>;
      expect(json['version'], 8);
      expect(json['logGroups'], ['discharge', 'tags']);
      expect(codec.decode(codec.encode(data)).shownLogGroups, {
        LogGroup.discharge,
        LogGroup.tags,
      });
    });

    HealthData allHidden() => HealthData.empty
        .withLogGroup(LogGroup.moods, shown: false)
        .withLogGroup(LogGroup.tags, shown: false);

    test('hiding everything is kept, not read as no choice', () {
      expect(allHidden().shownLogGroups, isEmpty);
      expect(codec.decode(codec.encode(allHidden())).shownLogGroups, isEmpty);
    });

    test('no choice writes no key, and a document without one shows moods '
        'and tags', () {
      final json =
          jsonDecode(codec.encode(HealthData.empty)) as Map<String, dynamic>;
      expect(json.containsKey('logGroups'), isFalse);
      expect(json.containsKey('logGroupsOffered'), isFalse);
      expect(codec.decode('{"version":8}').shownLogGroups, {
        LogGroup.moods,
        LogGroup.tags,
      });
    });

    test('a choice is written with the groups there were to choose from', () {
      final json =
          jsonDecode(codec.encode(allHidden())) as Map<String, dynamic>;
      expect(json['logGroupsOffered'], [
        for (final g in LogGroup.values) g.name,
      ]);
    });

    test('a choice made before Tags existed gets Tags, which shows from '
        'the start', () {
      expect(
        codec.decode('{"version":8,"logGroups":["sleep"]}').shownLogGroups,
        {LogGroup.sleep, LogGroup.tags},
      );
      expect(codec.decode('{"version":8,"logGroups":[]}').shownLogGroups, {
        LogGroup.tags,
      });
    });

    test('Tags hidden once it was there to choose stays hidden', () {
      expect(
        codec
            .decode(
              '{"version":8,"logGroups":["sleep"],'
              '"logGroupsOffered":["moods","sleep","tags"]}',
            )
            .shownLogGroups,
        {LogGroup.sleep},
      );
    });

    test('a group that was not there to choose and is off at first '
        'stays off', () {
      expect(
        codec
            .decode(
              '{"version":8,"logGroups":["moods"],'
              '"logGroupsOffered":["moods","tags"]}',
            )
            .shownLogGroups,
        {LogGroup.moods},
      );
    });
  });
}
