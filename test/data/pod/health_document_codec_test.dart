import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';

void main() {
  v8Tests();
  const codec = HealthDocumentCodec();
  final full = HealthData.empty
      .withReading(
        TemperatureReading(date: DateTime(2026, 5, 1), celsius: 36.4),
      )
      .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 1)))
      .withDailyLog(
        DailyLog(
          date: DateTime(2026, 5, 1),
          flow: FlowIntensity.heavy,
          symptoms: const {Symptom.cramps},
          painLevel: 6,
        ),
      )
      .withRating('cramps', 'Heat pack', RemedyRating.helped)
      .withShoppingItem(
        const ShoppingItem(name: 'Heat pack', symptomKey: 'cramps'),
      )
      .withProfile(
        HealthProfile(
          conditions: const {ReproductiveCondition.pcos},
          notes: 'n',
        ),
      );

  test('round-trips every section', () {
    expect(codec.decode(codec.encode(full)), full);
  });

  test('writes the current version', () {
    final json = jsonDecode(codec.encode(full)) as Map<String, dynamic>;
    expect(json['version'], HealthDocumentCodec.currentVersion);
    expect(
      json.keys,
      unorderedEquals([
        'version',
        'readings',
        'periods',
        'dailyLogs',
        'remedyFeedback',
        'shopping',
        'profile',
        'shares',
        'received',
        'wearableNights',
      ]),
    );
  });

  group('decode', () {
    final emptyCases = <({String name, String input})>[
      (name: 'an empty string', input: ''),
      (name: 'whitespace', input: ' \n'),
      (name: 'an empty object', input: '{}'),
    ];
    for (final c in emptyCases) {
      test(
        '${c.name} is an empty document',
        () => expect(codec.decode(c.input), HealthData.empty),
      );
    }

    test('reads a version 3 document the original app wrote', () {
      const v3 = '''
      {"version":3,
       "readings":[{"date":"2026-05-01T00:00:00.000","celsius":36.4,"source":"manual"}],
       "periods":[{"startDate":"2026-05-01T00:00:00.000"}],
       "dailyLogs":[{"date":"2026-05-01T00:00:00.000","flow":"heavy","symptoms":["cramps"],"painLevel":6}],
       "remedyFeedback":[{"symptom":"cramps","remedy":"Heat pack","rating":"helped"}],
       "shopping":[{"name":"Heat pack","symptom":"cramps","bought":false}],
       "profile":{"conditions":["pcos"],"treatments":[],"notes":"n"}}
      ''';
      expect(codec.decode(v3), full);
    });

    test('migrates a version 1 document: readings and periods only', () {
      const v1 = '''
      {"version":1,
       "readings":[{"date":"2026-05-01T00:00:00.000","celsius":36.4,"source":"manual"}],
       "periods":[{"startDate":"2026-05-01T00:00:00.000"}]}
      ''';
      final got = codec.decode(v1);
      expect(got.readings, full.readings);
      expect(got.periods, full.periods);
      expect(got.dailyLogs, isEmpty);
      expect(got.remedyFeedback, isEmpty);
      expect(got.shopping, isEmpty);
      expect(got.profile, HealthProfile());
    });

    test('treats a document without a version as version 1', () {
      const unversioned =
          '{"periods":[{"startDate":"2026-05-01T00:00:00.000"}]}';
      expect(codec.decode(unversioned).periods, full.periods);
    });

    final badCases = <({String name, String input})>[
      (name: 'not JSON', input: 'hello'),
      (name: 'a JSON list', input: '[1,2]'),
      (
        name: 'a reading without a date',
        input: '{"version":3,"readings":[{"celsius":36.4}]}',
      ),
    ];
    for (final c in badCases) {
      test('${c.name} is malformed', () {
        expect(
          () => codec.decode(c.input),
          throwsA(isA<MalformedDocumentException>()),
        );
      });
    }

    test('refuses a document from a newer app', () {
      expect(
        () => codec.decode(
          '{"version":${HealthDocumentCodec.currentVersion + 1}}',
        ),
        throwsA(isA<UnsupportedDocumentVersionException>()),
      );
    });
  });

  group('migrate', () {
    test('steps version 1 up to the current version with empty sections', () {
      final got = migrate({'version': 1, 'readings': <Object>[]});
      expect(got['version'], HealthDocumentCodec.currentVersion);
      expect(got['readings'], isEmpty);
      expect(got['dailyLogs'], isEmpty);
      expect(got['remedyFeedback'], isEmpty);
      expect(got['shopping'], isEmpty);
      expect(got['shares'], isEmpty);
      expect(got['received'], isEmpty);
      expect(got['profile'], isNull);
    });

    test('steps version 3 up by adding empty shares and received only', () {
      final got = migrate({'version': 3, 'shopping': <Object>[]});
      expect(got, {
        'version': 8,
        'shopping': <Object>[],
        'shares': <Object>[],
        'received': <Object>[],
        'wearableNights': <Object>[],
      });
    });

    test('steps version 4 up by adding empty received only', () {
      final got = migrate({'version': 4, 'shares': <Object>[]});
      expect(got, {
        'version': 8,
        'shares': <Object>[],
        'received': <Object>[],
        'wearableNights': <Object>[],
      });
    });

    test('steps version 6 up by bumping only', () {
      final got = migrate({
        'version': 6,
        'periods': [
          {'startDate': '2026-05-01T00:00:00.000'},
        ],
      });
      expect(got, {
        'version': 8,
        'periods': [
          {'startDate': '2026-05-01T00:00:00.000'},
        ],
        'wearableNights': <Object>[],
      });
    });

    test('a version 6 period without an end or flow still loads', () {
      final data = codec.decode(
        '{"version":6,"periods":[{"startDate":"2026-05-01T00:00:00.000"}]}',
      );
      expect(data.periods.single.startDate, DateTime(2026, 5, 1));
      expect(data.periods.single.isOpen, isTrue);
    });

    test('round-trips a period with an end and flow', () {
      final data = HealthData.empty.withPeriod(
        PeriodEvent(
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 5),
          flow: FlowIntensity.heavy,
        ),
      );
      expect(codec.decode(codec.encode(data)), data);
    });

    test('steps version 5 up by naming what each share holds', () {
      final got = migrate({
        'version': 5,
        'shares': [
          {'recipient': 'https://x.example/a#me', 'label': 'A'},
        ],
      });
      expect(got, {
        'version': 8,
        'shares': [
          {
            'recipient': 'https://x.example/a#me',
            'label': 'A',
            'content': 'cycleData',
          },
        ],
        'wearableNights': <Object>[],
      });
    });

    test('leaves the current version alone', () {
      final doc = {
        'version': HealthDocumentCodec.currentVersion,
        'shopping': <Object>[],
      };
      expect(migrate(doc), doc);
    });
  });
}

void v8Tests() {
  test('a v7 document gains an empty night list and loads', () {
    const codec = HealthDocumentCodec();
    final v7 = jsonEncode({
      'version': 7,
      'readings': <Object>[],
      'periods': <Object>[],
      'dailyLogs': <Object>[],
      'remedyFeedback': <Object>[],
      'profile': <String, Object>{},
      'shares': <Object>[],
      'received': <Object>[],
    });
    final migrated = migrate(jsonDecode(v7) as Map<String, dynamic>);
    expect(migrated['version'], 8);
    expect(migrated['wearableNights'], isEmpty);
    expect(codec.decode(v7).wearableNights, isEmpty);
  });

  test('nights round-trip at v8', () {
    const codec = HealthDocumentCodec();
    final data = HealthData.empty.withNights([
      WearableNight(date: DateTime(2026, 6, 2), celsius: 0.2),
    ]);
    expect(
      codec.decode(codec.encode(data)).wearableNights,
      data.wearableNights,
    );
  });
}
