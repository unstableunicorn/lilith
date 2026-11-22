import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  receivedShareTests();
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
        conditions: {ReproductiveCondition.pcos},
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
  });

  group('HealthData shares', () {
    final a = Share(recipientWebId: wife, label: 'A', createdOn: may1);
    final other = 'https://solid.unstableunicorn.dev/o/profile/card#me';
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
