import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/temperature_reading.dart';

import '../fakes/fake_pod_service.dart';
import '../fakes/fake_share_service.dart';

void main() {
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const codec = HealthDocumentCodec();
  const cipher = ShareCipher();
  final may1 = DateTime(2026, 5, 1);
  final stored = HealthData.empty
      .withPeriod(PeriodEvent(startDate: may1))
      .withProfile(HealthProfile(notes: 'private'));

  late FakePodService pod;
  late FakeShareService shares;
  late HealthRepository health;
  late ShareRepository repo;

  Future<void> setUpWith(DataProtection protection) async {
    pod = FakePodService();
    health = HealthRepository(pod, protection: protection);
    pod.documents[health.documentPath] = codec.encode(stored);
    shares = FakeShareService();
    repo = ShareRepository(
      health,
      shares,
      protection: protection,
      random: Random(1),
    );
    await health.load();
  }

  group('encrypted data', () {
    setUp(() => setUpWith(DataProtection.encrypted));

    test(
      'create opens, writes an encrypted copy, then records the share',
      () async {
        final share = await repo.create(
          recipientWebId: ' $wife ',
          label: ' Alex ',
          duration: ShareDuration.thirtyDays,
          today: may1,
        );
        expect(share, isNotNull);
        expect(share!.recipientWebId, wife);
        expect(share.label, 'Alex');
        expect(share.expiresOn, DateTime(2026, 5, 31));
        expect(share.isEncrypted, isTrue);
        expect(shares.calls, [
          'open shares/${share.id}',
          'write shares/${share.id}',
        ]);
        expect(repo.shares, [share]);
        expect(codec.decode(pod.documents[health.documentPath]!).shares, [
          share,
        ]);
        expect(repo.error, isNull);
      },
    );

    test('the copy is the shared subset under the share key', () async {
      final share = (await repo.create(
        recipientWebId: wife,
        label: 'A',
        duration: ShareDuration.untilRevoked,
        today: may1,
      ))!;
      final copy = shares.folders['shares/${share.id}']!;
      expect(copy.split('.'), hasLength(5));
      final seen = codec.decode(
        cipher.decrypt(copy, ShareKey.fromCode(share.code!)!),
      );
      expect(seen.periods, stored.periods);
      expect(seen.profile, HealthProfile());
      expect(seen.shares, isEmpty);
    });

    test('a save that changes the cycle data rewrites every copy', () async {
      final share = (await repo.create(
        recipientWebId: wife,
        label: 'A',
        duration: ShareDuration.untilRevoked,
        today: may1,
      ))!;
      shares.calls.clear();
      await health.apply(
        (d) => d.withReading(TemperatureReading(date: may1, celsius: 36.5)),
      );
      expect(shares.calls, ['write shares/${share.id}']);
      final seen = codec.decode(
        cipher.decrypt(
          shares.folders['shares/${share.id}']!,
          ShareKey.fromCode(share.code!)!,
        ),
      );
      expect(seen.readings, hasLength(1));
    });

    test(
      'a save that changes only private data leaves the copies alone',
      () async {
        await repo.create(
          recipientWebId: wife,
          label: 'A',
          duration: ShareDuration.untilRevoked,
          today: may1,
        );
        shares.calls.clear();
        await health.apply((d) => d.withProfile(HealthProfile(notes: 'more')));
        expect(shares.calls, isEmpty);
      },
    );

    test('two shares get two keys', () async {
      final a = await repo.create(
        recipientWebId: wife,
        label: 'A',
        duration: ShareDuration.untilRevoked,
        today: may1,
      );
      final b = await repo.create(
        recipientWebId: 'https://solid.unstableunicorn.dev/o/profile/card#me',
        label: 'B',
        duration: ShareDuration.untilRevoked,
        today: may1,
      );
      expect(a!.code, isNot(b!.code));
    });
  });

  group('plain data', () {
    setUp(() => setUpWith(DataProtection.plain));

    test(
      'the copy is plain JSON of the subset and the share has no code',
      () async {
        final share = (await repo.create(
          recipientWebId: wife,
          label: 'A',
          duration: ShareDuration.ninetyDays,
          today: may1,
        ))!;
        expect(share.isEncrypted, isFalse);
        final seen = codec.decode(shares.folders['shares/${share.id}']!);
        expect(seen.periods, stored.periods);
        expect(seen.profile, HealthProfile());
      },
    );
  });

  group('ending shares', () {
    late Share share;

    setUp(() async {
      await setUpWith(DataProtection.encrypted);
      share = (await repo.create(
        recipientWebId: wife,
        label: 'A',
        duration: ShareDuration.thirtyDays,
        today: may1,
      ))!;
      shares.calls.clear();
    });

    test('revoke closes the folder, then forgets the share', () async {
      await repo.revoke(share);
      expect(shares.calls, ['close shares/${share.id}']);
      expect(shares.folders, isEmpty);
      expect(repo.shares, isEmpty);
      expect(codec.decode(pod.documents[health.documentPath]!).shares, isEmpty);
    });

    test('a failed close keeps the share so it can be retried', () async {
      shares.failClose = const PodUnavailableException('offline');
      await repo.revoke(share);
      expect(repo.shares, [share]);
      expect(repo.error, ShareError.unreachable);
      expect(repo.errorDetail, 'offline');
    });

    test('sweep ends the overdue shares only', () async {
      expect(repo.overdue(DateTime(2026, 5, 31)), isEmpty);
      await repo.sweep(DateTime(2026, 5, 31));
      expect(repo.shares, [share]);
      expect(repo.overdue(DateTime(2026, 6, 1)), [share]);
      await repo.sweep(DateTime(2026, 6, 1));
      expect(repo.shares, isEmpty);
      expect(shares.calls, ['close shares/${share.id}']);
    });
  });

  group('failures', () {
    setUp(() => setUpWith(DataProtection.encrypted));

    test('a refused open records nothing and reports it', () async {
      shares.failOpen = const PodAccessException('403');
      final share = await repo.create(
        recipientWebId: wife,
        label: 'A',
        duration: ShareDuration.thirtyDays,
        today: may1,
      );
      expect(share, isNull);
      expect(repo.shares, isEmpty);
      expect(repo.error, ShareError.failed);
      expect(repo.errorDetail, '403');
      repo.clearError();
      expect(repo.error, isNull);
    });

    test('being logged out is its own error', () async {
      shares.failOpen = const PodNotLoggedInException();
      await repo.create(
        recipientWebId: wife,
        label: 'A',
        duration: ShareDuration.thirtyDays,
        today: may1,
      );
      expect(repo.error, ShareError.notLoggedIn);
    });

    test(
      'a failed copy rewrite is reported and the data stays saved',
      () async {
        await repo.create(
          recipientWebId: wife,
          label: 'A',
          duration: ShareDuration.untilRevoked,
          today: may1,
        );
        shares.failWrite = const PodUnavailableException('offline');
        await health.apply(
          (d) => d.withReading(TemperatureReading(date: may1, celsius: 36.5)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(repo.error, ShareError.unreachable);
        expect(
          codec.decode(pod.documents[health.documentPath]!).readings,
          hasLength(1),
        );
      },
    );
  });

  test('notifies when the shares change', () async {
    await setUpWith(DataProtection.plain);
    var notified = 0;
    repo.addListener(() => notified++);
    await repo.create(
      recipientWebId: wife,
      label: 'A',
      duration: ShareDuration.thirtyDays,
      today: may1,
    );
    expect(notified, greaterThan(0));
  });
}
