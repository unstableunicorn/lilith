import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/shared_phases.dart';

import '../fakes/fake_pod_service.dart';
import '../fakes/fake_share_reader.dart';

void main() {
  const me = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const cipher = ShareCipher();
  final may1 = DateTime(2026, 5, 1);
  final key = ShareKey.generate(Random(5));
  final copyUrl = SharePlan.forRecipient(me).documentUrl(ownerRoot);
  final phases = SharedPhases(
    updatedOn: may1,
    periods: [PeriodEvent(startDate: may1)],
    nextPeriod: DateTime(2026, 5, 29),
  );

  late FakeShareReader reader;
  late ReceivedShareRepository repo;

  setUp(() async {
    final health = HealthRepository(
      FakePodService(),
      protection: DataProtection.encrypted,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    repo = ReceivedShareRepository(health, reader, ownWebId: me);
  });

  Future<ReceivedShareError?> add(String? code) =>
      repo.add(sharerWebId: owner, label: 'Elric', code: code, today: may1);

  test('an encrypted phases copy reads as phases', () async {
    reader.documents[copyUrl] = cipher.encrypt(
      jsonEncode(phases.toJson()),
      key,
      Random(1),
    );
    expect(await add(key.code), isNull);
    final view = repo.viewOf(repo.received.single);
    expect(view, isA<SharedViewPhases>());
    expect((view as SharedViewPhases).phases, phases);
  });

  test('a plain phases copy reads as phases', () async {
    reader.documents[copyUrl] = jsonEncode(phases.toJson());
    expect(await add(null), isNull);
    expect(repo.viewOf(repo.received.single), isA<SharedViewPhases>());
  });

  test('a broken phases copy is malformed', () async {
    reader.documents[copyUrl] = jsonEncode({'kind': 'phases'});
    expect(await add(null), ReceivedShareError.malformed);
  });
}
