import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  receivedShareTests();
  shareInviteTests();
  reportShareTests();
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  final may1 = DateTime(2026, 5, 1);

  group('shareId', () {
    test('is 16 hex characters derived from the WebID', () {
      final id = shareId(wife);
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(shareId(wife), id);
    });

    test('differs between WebIDs and ignores surrounding space', () {
      expect(shareId('$wife '), shareId(wife));
      expect(
        shareId('https://solid.unstableunicorn.dev/other/profile/card#me'),
        isNot(shareId(wife)),
      );
    });
  });

  group('sharedView', () {
    final full = HealthData(
      readings: [TemperatureReading(date: may1, celsius: 36.4)],
      periods: [PeriodEvent(startDate: may1)],
      dailyLogs: [
        DailyLog(date: may1, symptoms: const {Symptom.cramps}),
      ],
      remedyFeedback: const [
        RemedyFeedback(
          symptomKey: 'cramps',
          remedyTitle: 'Heat',
          rating: RemedyRating.helped,
        ),
      ],
      shopping: const [ShoppingItem(name: 'tea')],
      profile: HealthProfile(
        conditions: const {ReproductiveCondition.pcos},
        notes: 'private',
      ),
      shares: [Share(recipientWebId: wife, label: 'W', createdOn: may1)],
    );

    test('keeps the cycle data', () {
      final shared = sharedView(full);
      expect(shared.readings, full.readings);
      expect(shared.periods, full.periods);
      expect(shared.dailyLogs, full.dailyLogs);
    });

    test('leaves out the profile, verdicts, shopping list and shares', () {
      final shared = sharedView(full);
      expect(shared.profile, HealthProfile());
      expect(shared.remedyFeedback, isEmpty);
      expect(shared.shopping, isEmpty);
      expect(shared.shares, isEmpty);
    });

    test('empty stays empty', () {
      expect(sharedView(HealthData.empty), HealthData.empty);
    });

    test('leaves notes out unless asked, dropping a day that held only a '
        'note', () {
      final noted = HealthData(
        dailyLogs: [
          DailyLog(date: may1, painLevel: 3, note: 'private words'),
          DailyLog(date: DateTime(2026, 5, 2), note: 'only a note'),
        ],
      );
      final without = sharedView(noted);
      expect(without.dailyLogs, [DailyLog(date: may1, painLevel: 3)]);
      expect(sharedView(noted, includeNotes: true).dailyLogs, noted.dailyLogs);
    });

    test('never shares a dose marked done, notes or not', () {
      final marked = HealthData(
        dailyLogs: [
          DailyLog(
            date: may1,
            painLevel: 3,
            contraceptionDoneAt: DateTime(2026, 5, 1, 9),
          ),
          DailyLog(
            date: DateTime(2026, 5, 2),
            contraceptionDoneAt: DateTime(2026, 5, 2, 9),
          ),
        ],
      );
      for (final notes in [false, true]) {
        expect(sharedView(marked, includeNotes: notes).dailyLogs, [
          DailyLog(date: may1, painLevel: 3),
        ], reason: 'includeNotes: $notes');
      }
    });
  });

  group('ShareDuration', () {
    test('ends after the given days, or never', () {
      expect(
        ShareDuration.thirtyDays.endFrom(DateTime(2026, 5, 1, 13)),
        DateTime(2026, 5, 31),
      );
      expect(ShareDuration.ninetyDays.endFrom(may1), DateTime(2026, 7, 30));
      expect(ShareDuration.untilRevoked.endFrom(may1), isNull);
    });

    test('recommends 30 days', () {
      expect(ShareDuration.recommended, ShareDuration.thirtyDays);
    });

    test('a custom duration ends on the given day, else has no end', () {
      expect(ShareDuration.custom.isCustom, isTrue);
      expect(ShareDuration.custom.endFrom(may1), isNull);
      expect(
        ShareDuration.custom.endFrom(
          may1,
          customEnd: DateTime(2026, 6, 15, 13),
        ),
        DateTime(2026, 6, 15),
      );
      expect(
        ShareDuration.earliestEnd(DateTime(2026, 5, 1, 23)),
        DateTime(2026, 5, 2),
      );
      expect(
        ShareDuration.thirtyDays.endFrom(may1, customEnd: DateTime(2030)),
        DateTime(2026, 5, 31),
      );
    });
  });

  group('Share', () {
    final share = Share(
      recipientWebId: wife,
      label: 'Alex',
      createdOn: DateTime(2026, 5, 1, 9, 30),
      expiresOn: DateTime(2026, 5, 31, 23),
      code: 'ABCD-EFGH-JKMN-PQRS',
    );

    test('normalises its days to midnight', () {
      expect(share.createdOn, may1);
      expect(share.expiresOn, DateTime(2026, 5, 31));
    });

    test('is readable through its last day and expired after', () {
      expect(share.isExpired(DateTime(2026, 5, 31, 23, 59)), isFalse);
      expect(share.isExpired(DateTime(2026, 6, 1)), isTrue);
      final open = Share(recipientWebId: wife, label: 'A', createdOn: may1);
      expect(open.isExpired(DateTime(2099)), isFalse);
    });

    test('knows its id and whether the copy is encrypted', () {
      expect(share.id, shareId(wife));
      expect(share.isEncrypted, isTrue);
      expect(
        Share(recipientWebId: wife, label: 'A', createdOn: may1).isEncrypted,
        isFalse,
      );
    });

    test('round-trips through JSON, with and without an end or a code', () {
      expect(Share.fromJson(share.toJson()), share);
      final open = Share(recipientWebId: wife, label: 'A', createdOn: may1);
      final json = open.toJson();
      expect(json.containsKey('expiresOn'), isFalse);
      expect(json.containsKey('code'), isFalse);
      expect(Share.fromJson(json), open);
    });

    test('leaves notes out by default; the choice round-trips', () {
      final open = Share(recipientWebId: wife, label: 'A', createdOn: may1);
      expect(open.includeNotes, isFalse);
      expect(open.toJson().containsKey('includeNotes'), isFalse);
      final withNotes = Share(
        recipientWebId: wife,
        label: 'A',
        createdOn: may1,
        includeNotes: true,
      );
      expect(Share.fromJson(withNotes.toJson()), withNotes);
      expect(withNotes, isNot(open));
    });
  });

  group('HealthData shares', () {
    final a = Share(recipientWebId: wife, label: 'A', createdOn: may1);
    const other = 'https://solid.unstableunicorn.dev/o/profile/card#me';
    final b = Share(recipientWebId: other, label: 'B', createdOn: may1);

    test('adds a share and replaces one for the same recipient', () {
      final d = HealthData.empty.withShare(a).withShare(b);
      expect(d.shares, [a, b]);
      final renamed = Share(recipientWebId: wife, label: 'A2', createdOn: may1);
      expect(d.withShare(renamed).shares, [b, renamed]);
    });

    test('removes a share by recipient', () {
      final d = HealthData.empty.withShare(a).withShare(b);
      expect(d.withoutShare(wife).shares, [b]);
      expect(d.withoutShare('nobody'), d);
    });

    test('shares count towards equality but not towards having data', () {
      final d = HealthData.empty.withShare(a);
      expect(d, isNot(HealthData.empty));
      expect(d.hasData, isFalse);
    });
  });
}

void receivedShareTests() {
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final may1 = DateTime(2026, 5, 1);

  group('ReceivedShare', () {
    final share = ReceivedShare(
      sharerWebId: owner,
      label: 'Elric',
      addedOn: DateTime(2026, 5, 1, 9),
      code: 'ABCD-EFGH-JKMN-PQRS',
    );

    test('round-trips through JSON, with and without a code', () {
      expect(share.addedOn, may1);
      expect(ReceivedShare.fromJson(share.toJson()), share);
      final plain = ReceivedShare(
        sharerWebId: owner,
        label: 'E',
        addedOn: may1,
      );
      expect(plain.toJson().containsKey('code'), isFalse);
      expect(ReceivedShare.fromJson(plain.toJson()), plain);
    });
  });

  group('HealthData received', () {
    final a = ReceivedShare(sharerWebId: owner, label: 'A', addedOn: may1);
    final b = ReceivedShare(
      sharerWebId: '${owner}2',
      label: 'B',
      addedOn: may1,
    );

    test('adds, replaces by sharer, removes, and counts for equality', () {
      final d = HealthData.empty.withReceived(a).withReceived(b);
      expect(d.received, [a, b]);
      final renamed = ReceivedShare(
        sharerWebId: owner,
        label: 'A2',
        addedOn: may1,
      );
      expect(d.withReceived(renamed).received, [b, renamed]);
      expect(d.withoutReceived(owner).received, [b]);
      expect(d, isNot(HealthData.empty));
      expect(d.hasData, isFalse);
      expect(sharedView(d).received, isEmpty);
    });
  });
}

void shareInviteTests() {
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final app = Uri.parse('https://lilith.unstableunicorn.dev/');

  group('ShareInvite', () {
    test('round-trips through a link, with and without a code', () {
      const full = ShareInvite(sharerWebId: owner, code: 'ABCD-EFGH-JKMN-PQRS');
      final link = full.toUri(app);
      expect(link.host, 'lilith.unstableunicorn.dev');
      expect(link.queryParameters['share'], owner);
      expect(link.queryParameters['code'], 'ABCD-EFGH-JKMN-PQRS');
      expect(ShareInvite.fromUri(link), full);
      const plain = ShareInvite(sharerWebId: owner);
      expect(plain.toUri(app).queryParameters.containsKey('code'), isFalse);
      expect(ShareInvite.fromUri(plain.toUri(app)), plain);
    });

    test('a link without a sharer is no invite', () {
      expect(ShareInvite.fromUri(app), isNull);
      expect(ShareInvite.fromUri(Uri.parse('$app?code=X')), isNull);
      expect(ShareInvite.fromUri(Uri.parse('$app?share=')), isNull);
      expect(
        ShareInvite.fromUri(
          app.replace(queryParameters: {'share': owner, 'code': ''}),
        ),
        const ShareInvite(sharerWebId: owner),
      );
    });
  });
}

void reportShareTests() {
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  final may1 = DateTime(2026, 5, 1);

  group('a report share', () {
    test('holds a report over a span and is never encrypted', () {
      final share = Share(
        recipientWebId: wife,
        label: 'Dr Patel',
        createdOn: may1,
        content: ShareContent.report,
      );
      expect(share.isReport, isTrue);
      expect(share.range, ExportRange.sixMonths);
      expect(share.isEncrypted, isFalse);
      expect(Share.fromJson(share.toJson()), share);
      expect(share.toJson()['content'], 'report');
      expect(share.toJson()['range'], 'sixMonths');
    });

    test('an app-view share has no span even when given one', () {
      final share = Share(
        recipientWebId: wife,
        label: 'A',
        createdOn: may1,
        range: ExportRange.year,
      );
      expect(share.range, isNull);
      expect(share.toJson().containsKey('range'), isFalse);
      expect(share.content, ShareContent.cycleData);
    });

    test('an old share without content holds the app view', () {
      final share = Share.fromJson(const {
        'recipient': wife,
        'label': 'A',
        'createdOn': '2026-05-01T00:00:00.000',
      });
      expect(share.content, ShareContent.cycleData);
      expect(ShareContent.fromName('nonsense'), ShareContent.cycleData);
    });
  });
}
