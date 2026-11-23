import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';

import '../fakes/fake_pod_service.dart';
import '../fakes/fake_settings_store.dart';
import '../fakes/fake_share_reader.dart';

void main() {
  inviteTests();
  const me = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const codec = HealthDocumentCodec();
  const cipher = ShareCipher();
  final may1 = DateTime(2026, 5, 1);
  final theirs = HealthData.empty.withPeriod(PeriodEvent(startDate: may1));
  final key = ShareKey.generate(Random(5));
  final copyUrl = SharePlan.forRecipient(me).documentUrl(ownerRoot);

  late FakePodService pod;
  late HealthRepository health;
  late FakeShareReader reader;
  late ReceivedShareRepository repo;

  setUp(() async {
    pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.encrypted);
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    repo = ReceivedShareRepository(health, reader, ownWebId: me);
  });

  group('add', () {
    test(
      'reads an encrypted copy with its code and records the share',
      () async {
        reader.documents[copyUrl] = cipher.encrypt(
          codec.encode(theirs),
          key,
          Random(1),
        );
        final error = await repo.add(
          sharerWebId: ' $owner ',
          label: ' Elric ',
          code: key.code.toLowerCase(),
          today: may1,
        );
        expect(error, isNull);
        final share = repo.received.single;
        expect(share.sharerWebId, owner);
        expect(share.label, 'Elric');
        expect(share.code, key.code.toLowerCase());
        expect(codec.decode(pod.documents[health.documentPath]!).received, [
          share,
        ]);
        expect(repo.viewOf(share), isA<SharedViewReady>());
        expect((repo.viewOf(share) as SharedViewReady).data, theirs);
      },
    );

    test('reads a plain copy without a code', () async {
      reader.documents[copyUrl] = codec.encode(theirs);
      final error = await repo.add(
        sharerWebId: owner,
        label: 'E',
        code: '  ',
        today: may1,
      );
      expect(error, isNull);
      expect(repo.received.single.code, isNull);
    });

    test('an encrypted copy without a code asks for one', () async {
      reader.documents[copyUrl] = cipher.encrypt(
        codec.encode(theirs),
        key,
        Random(1),
      );
      final error = await repo.add(
        sharerWebId: owner,
        label: 'E',
        code: null,
        today: may1,
      );
      expect(error, ReceivedShareError.needsCode);
      expect(repo.received, isEmpty);
    });

    test('a wrong or malformed code is reported', () async {
      reader.documents[copyUrl] = cipher.encrypt(
        codec.encode(theirs),
        key,
        Random(1),
      );
      expect(
        await repo.add(
          sharerWebId: owner,
          label: 'E',
          code: ShareKey.generate(Random(9)).code,
          today: may1,
        ),
        ReceivedShareError.wrongCode,
      );
      expect(
        await repo.add(
          sharerWebId: owner,
          label: 'E',
          code: 'nope',
          today: may1,
        ),
        ReceivedShareError.needsCode,
      );
    });

    test('nothing at the folder means the share ended or never was', () async {
      expect(
        await repo.add(sharerWebId: owner, label: 'E', code: null, today: may1),
        ReceivedShareError.ended,
      );
    });

    test(
      'an unreachable pod and a logged-out user are their own errors',
      () async {
        reader.failRead = const PodUnavailableException('offline');
        expect(
          await repo.add(
            sharerWebId: owner,
            label: 'E',
            code: null,
            today: may1,
          ),
          ReceivedShareError.unreachable,
        );
        reader.failRead = const PodNotLoggedInException();
        expect(
          await repo.add(
            sharerWebId: owner,
            label: 'E',
            code: null,
            today: may1,
          ),
          ReceivedShareError.notLoggedIn,
        );
      },
    );

    test('a copy that is not a health document is malformed', () async {
      reader.documents[copyUrl] = '{"version":5,"readings":[{"x":1}]}';
      expect(
        await repo.add(sharerWebId: owner, label: 'E', code: null, today: may1),
        ReceivedShareError.malformed,
      );
    });
  });

  group('with a share recorded', () {
    late ReceivedShare share;

    setUp(() async {
      reader.documents[copyUrl] = cipher.encrypt(
        codec.encode(theirs),
        key,
        Random(1),
      );
      await repo.add(
        sharerWebId: owner,
        label: 'E',
        code: key.code,
        today: may1,
      );
      share = repo.received.single;
    });

    test('a fresh repository shows loading until refreshed', () async {
      final again = ReceivedShareRepository(health, reader, ownWebId: me);
      expect(again.viewOf(share), isA<SharedViewLoading>());
      await again.refresh(share);
      expect((again.viewOf(share) as SharedViewReady).data, theirs);
    });

    test('refresh picks up the sharer\'s new data', () async {
      final newer = theirs.withPeriod(
        PeriodEvent(startDate: DateTime(2026, 5, 29)),
      );
      reader.documents[copyUrl] = cipher.encrypt(
        codec.encode(newer),
        key,
        Random(2),
      );
      await repo.refresh(share);
      expect((repo.viewOf(share) as SharedViewReady).data, newer);
    });

    test(
      'refresh after the share ended says so, and keeps the share',
      () async {
        reader.documents.clear();
        await repo.refresh(share);
        final view = repo.viewOf(share) as SharedViewFailed;
        expect(view.error, ReceivedShareError.ended);
        expect(repo.received, [share]);
      },
    );

    test('refresh reports an unreachable pod with its detail', () async {
      reader.failRead = const PodUnavailableException('timeout');
      await repo.refresh(share);
      final view = repo.viewOf(share) as SharedViewFailed;
      expect(view.error, ReceivedShareError.unreachable);
      expect(view.detail, 'timeout');
    });

    test('changeCode takes a new code after a re-share, or refuses', () async {
      final newKey = ShareKey.generate(Random(11));
      reader.documents[copyUrl] = cipher.encrypt(
        codec.encode(theirs),
        newKey,
        Random(3),
      );
      await repo.refresh(share);
      expect(
        (repo.viewOf(share) as SharedViewFailed).error,
        ReceivedShareError.wrongCode,
      );
      expect(
        await repo.changeCode(share, 'nonsense'),
        ReceivedShareError.needsCode,
      );
      expect(repo.received.single.code, key.code);
      expect(await repo.changeCode(share, newKey.code.toLowerCase()), isNull);
      expect(repo.received.single.code, newKey.code.toLowerCase());
      expect(repo.viewOf(repo.received.single), isA<SharedViewReady>());
      expect(
        codec.decode(pod.documents[health.documentPath]!).received.single.code,
        newKey.code.toLowerCase(),
      );
    });

    test('remove forgets the share and its view', () async {
      await repo.remove(share);
      expect(repo.received, isEmpty);
      expect(repo.viewOf(share), isA<SharedViewLoading>());
      expect(
        codec.decode(pod.documents[health.documentPath]!).received,
        isEmpty,
      );
    });

    test('notifies on refresh', () async {
      var n = 0;
      repo.addListener(() => n++);
      await repo.refresh(share);
      expect(n, 2);
    });
  });

  test('tells an envelope from JSON', () {
    expect(ReceivedShareRepository.isEnvelope('{"version":5}'), isFalse);
    expect(ReceivedShareRepository.isEnvelope('a..b.c.d'), isTrue);
    expect(ReceivedShareRepository.isEnvelope(' a..b.c.d\n'), isTrue);
    expect(ReceivedShareRepository.isEnvelope('a.b.c'), isFalse);
  });
}

void inviteTests() {
  const me = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const codec = HealthDocumentCodec();
  final may1 = DateTime(2026, 5, 1);
  const invite = ShareInvite(sharerWebId: owner);

  late FakeSettingsStore settings;
  late FakeShareReader reader;
  late ReceivedShareRepository repo;

  setUp(() async {
    final health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    settings = FakeSettingsStore()..invite = invite;
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    reader.documents[SharePlan.forRecipient(me).documentUrl(ownerRoot)] = codec
        .encode(HealthData.empty);
    repo = ReceivedShareRepository(
      health,
      reader,
      ownWebId: me,
      settings: settings,
    );
  });

  test('has no invite until loaded, then the stored one', () async {
    expect(repo.pendingInvite, isNull);
    await repo.loadInvite();
    expect(repo.pendingInvite, invite);
  });

  test('clearing forgets it here and in settings', () async {
    await repo.loadInvite();
    await repo.clearInvite();
    expect(repo.pendingInvite, isNull);
    expect(settings.invite, isNull);
  });

  test(
    'adding the invited sharer clears the invite; another does not',
    () async {
      await repo.loadInvite();
      await repo.add(
        sharerWebId: '${owner}other',
        label: 'O',
        code: null,
        today: may1,
      );
      expect(repo.pendingInvite, invite);
      await repo.add(sharerWebId: owner, label: 'E', code: null, today: may1);
      expect(repo.pendingInvite, isNull);
      expect(settings.invite, isNull);
    },
  );

  test('without settings there is never an invite', () async {
    final bare = ReceivedShareRepository(
      HealthRepository(FakePodService(), protection: DataProtection.plain),
      reader,
      ownWebId: me,
    );
    await bare.loadInvite();
    expect(bare.pendingInvite, isNull);
    await bare.clearInvite();
  });
}
