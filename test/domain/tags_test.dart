// A person's own tags: how one is stored, what a day holds, and which
// past ones are offered again.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/tags.dart';

void main() {
  DailyLog on(int day, List<String> tags) => DailyLog(
    date: DateTime(2026, 6, day),
    signs: BodySigns(tags: tags),
  );

  group('cleanTag', () {
    test('trims and closes up spaces', () {
      expect(cleanTag('  night   shift '), 'night shift');
      expect(cleanTag('Travel'), 'Travel');
    });

    test('nothing left is no tag', () {
      expect(cleanTag(''), isNull);
      expect(cleanTag('   '), isNull);
      expect(cleanTag(' ,; '), isNull);
    });

    test('drops what the exports join with', () {
      expect(cleanTag('late; night, out'), 'late night out');
    });

    test('is cut at the longest length', () {
      final long = 'a' * (maxTagLength + 5);
      expect(cleanTag(long), 'a' * maxTagLength);
      expect(
        cleanTag('${'a' * (maxTagLength - 1)} b'),
        'a' * (maxTagLength - 1),
      );
    });
  });

  group('cleanTags', () {
    test('cleans each, in A to Z order whatever the case', () {
      expect(cleanTags(['travel', ' Alcohol ', 'night  shift']), [
        'Alcohol',
        'night shift',
        'travel',
      ]);
    });

    test('keeps the first of two that differ only in case', () {
      expect(cleanTags(['Travel', 'travel', 'TRAVEL']), ['Travel']);
    });

    test('skips blanks and anything that is not text', () {
      expect(cleanTags(['', 4, null, 'ok', '  ']), ['ok']);
      expect(cleanTags(const []), isEmpty);
    });

    test('holds no more than a day can', () {
      final many = [for (var i = 0; i < maxTagsPerDay + 3; i++) 'tag $i'];
      expect(cleanTags(many), hasLength(maxTagsPerDay));
    });
  });

  group('withTag and withoutTag', () {
    test('adds a cleaned tag', () {
      expect(withTag(const ['travel'], '  Alcohol '), ['Alcohol', 'travel']);
    });

    test('a blank or one already there changes nothing', () {
      expect(withTag(const ['travel'], '  '), ['travel']);
      expect(withTag(const ['travel'], 'TRAVEL'), ['travel']);
    });

    test('a full day takes no more', () {
      final full = cleanTags([
        for (var i = 0; i < maxTagsPerDay; i++) 'tag $i',
      ]);
      expect(withTag(full, 'one more'), full);
    });

    test('removes a tag whatever its case', () {
      expect(withoutTag(const ['Alcohol', 'travel'], 'TRAVEL'), ['Alcohol']);
      expect(withoutTag(const ['travel'], 'other'), ['travel']);
      expect(withoutTag(const ['travel'], 'travel'), isEmpty);
    });
  });

  group('knownSpelling', () {
    final logs = [
      on(1, ['Travel']),
      on(5, ['travel', 'alcohol']),
      on(3, ['TRAVEL']),
    ];

    test('is the spelling of the latest day that has the tag', () {
      expect(knownSpelling(logs, ' TRAVEL '), 'travel');
      expect(knownSpelling(logs, 'Alcohol'), 'alcohol');
    });

    test('is none for a tag never logged, or a blank', () {
      expect(knownSpelling(logs, 'holiday'), isNull);
      expect(knownSpelling(logs, '  '), isNull);
      expect(knownSpelling(const [], 'travel'), isNull);
    });
  });

  group('tagSuggestions', () {
    final logs = [
      on(1, ['travel', 'alcohol']),
      on(2, ['travel', 'night shift']),
      on(3, ['Travel', 'alcohol', 'trampoline']),
      on(4, ['yoga']),
    ];

    test('offers past tags, the most used first, then A to Z', () {
      expect(tagSuggestions(logs), [
        'Travel',
        'alcohol',
        'night shift',
        'trampoline',
        'yoga',
      ]);
    });

    test('no past tags, nothing to offer', () {
      expect(tagSuggestions(const []), isEmpty);
      expect(tagSuggestions([DailyLog(date: DateTime(2026, 6))]), isEmpty);
    });

    test('leaves out what the day already has, whatever the case', () {
      expect(tagSuggestions(logs, chosen: ['TRAVEL', 'yoga']), [
        'alcohol',
        'night shift',
        'trampoline',
      ]);
    });

    test('while typing, offers those that hold the text, the ones that '
        'start with it first', () {
      expect(tagSuggestions(logs, typed: 'tra'), ['Travel', 'trampoline']);
      expect(tagSuggestions(logs, typed: ' SH '), ['night shift']);
      expect(tagSuggestions(logs, typed: 'a'), [
        'alcohol',
        'Travel',
        'trampoline',
        'yoga',
      ]);
      expect(tagSuggestions(logs, typed: 'zzz'), isEmpty);
    });

    test('offers no more than asked', () {
      expect(tagSuggestions(logs, max: 2), ['Travel', 'alcohol']);
      final many = [
        on(1, [for (var i = 0; i < 10; i++) 'tag $i']),
        on(2, [for (var i = 0; i < 10; i++) 'more $i']),
      ];
      expect(tagSuggestions(many), hasLength(maxTagSuggestions));
    });
  });

  group('BodySigns tags', () {
    final tagged = BodySigns(tags: const ['travel', ' Alcohol ', 'TRAVEL']);

    test('holds them cleaned', () {
      expect(tagged.tags, ['Alcohol', 'travel']);
      expect(BodySigns().tags, isEmpty);
    });

    test('a tag alone is something recorded', () {
      expect(tagged.isEmpty, isFalse);
      expect(BodySigns(tags: const ['  ']).isEmpty, isTrue);
    });

    test('is equal by its tags, whatever order they were given in', () {
      final same = BodySigns(tags: const ['Alcohol', 'travel']);
      expect(same, tagged);
      expect(same.hashCode, tagged.hashCode);
      expect(tagged, isNot(BodySigns()));
      expect(tagged, isNot(BodySigns(tags: const ['travel'])));
    });

    test('round-trips through JSON, and writes none when there are none', () {
      expect(tagged.toJson(), {
        'tags': ['Alcohol', 'travel'],
      });
      expect(
        BodySigns.fromJson(jsonDecode(jsonEncode(tagged.toJson()))),
        tagged,
      );
      expect(BodySigns(moods: const {Mood.sad}).toJson().keys, ['moods']);
    });

    test('reads anything that is not a list of text as no tags', () {
      expect(BodySigns.fromJson(const {'tags': 'travel'}).tags, isEmpty);
      expect(
        BodySigns.fromJson(const {
          'tags': [3, 'ok', null],
        }).tags,
        ['ok'],
      );
    });

    test('copyWith replaces the tags and otherwise keeps them', () {
      expect(tagged.copyWith(sleep: SleepQuality.good).tags, tagged.tags);
      expect(tagged.copyWith(tags: const ['yoga']).tags, ['yoga']);
      expect(tagged.copyWith(tags: const []).tags, isEmpty);
      expect(
        BodySigns(moods: const {Mood.calm}).copyWith(tags: const ['a']).moods,
        {Mood.calm},
      );
    });

    test('are said last, as written', () {
      expect(
        BodySigns(
          moods: const {Mood.calm},
          pregnancyTest: PregnancyTest.negative,
          tags: const ['Night shift', 'travel'],
        ).summaryParts,
        ['calm', 'pregnancy test negative', 'Night shift', 'travel'],
      );
    });

    test('go to someone the day is shared with', () {
      expect(tagged.shared.tags, tagged.tags);
    });

    test('a day with only a tag saves and loads back', () {
      final log = on(2, ['travel']);
      expect(log.isEmpty, isFalse);
      expect(
        DailyLog.fromJson(
          jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>,
        ),
        log,
      );
    });
  });

  test('Tags is a group of Log, shown from the start beside moods', () {
    expect(LogGroup.tags.label, 'Tags');
    expect(LogGroup.defaults, {LogGroup.moods, LogGroup.tags});
    expect(LogGroup.fromNames(['tags']), {LogGroup.tags});
  });
}
