import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';
import 'package:lilith/ui/received/shared_person_view_model.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_share_reader.dart';

/// What a follower is told while a life factor holds the sharer's
/// predictions.
void main() {
  const me = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const codec = HealthDocumentCodec();
  final copyUrl = SharePlan.forRecipient(me).documentUrl(ownerRoot);
  final today = DateTime(2026, 6, 10);
  final share = ReceivedShare(
    sharerWebId: owner,
    label: 'Elric',
    addedOn: today,
  );
  final pregnant = LifeFactor(
    kind: LifeFactorKind.pregnant,
    start: DateTime(2026, 5, 20),
    dueDate: DateTime(2027, 2, 20),
  );

  late FakeShareReader reader;
  late ReceivedShareRepository repo;

  setUp(() async {
    final health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    repo = ReceivedShareRepository(health, reader, ownWebId: me);
  });

  Future<SharedPersonViewModel> open(String document) async {
    reader.documents[copyUrl] = document;
    final vm = SharedPersonViewModel(repo, share, now: () => today);
    await vm.refresh();
    return vm;
  }

  HealthData theirs({List<LifeFactor> factors = const []}) => sharedView(
    HealthData.empty
        .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 15)))
        .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
        .withProfile(HealthProfile(lifeFactors: factors)),
  );

  test('a full share says why predictions are paused', () async {
    final vm = await open(codec.encode(theirs(factors: [pregnant])));
    const why =
        'Predictions are paused while they are pregnant. Their due date is '
        '20 Feb 2027.';
    expect(vm.prediction!.isOnHold, isTrue);
    expect(vm.nextPeriodText, why);
    expect(vm.headline, why);
  });

  test('a full share without a factor predicts as before', () async {
    final vm = await open(codec.encode(theirs()));
    expect(vm.nextPeriodText, 'Period expected today');
  });

  test('a phases share says only that they are paused, with no cycle '
      'day', () async {
    final vm = await open(
      jsonEncode(
        SharedPhases(
          updatedOn: today,
          periods: [PeriodEvent(startDate: DateTime(2026, 5, 13))],
          paused: true,
        ).toJson(),
      ),
    );
    expect(vm.nextPeriodText, 'Predictions are paused.');
    expect(vm.headline, 'Predictions are paused.');
    expect(vm.phasesCycleLine, isNull);
  });

  test('a phases share that is not paused keeps its cycle day', () async {
    final vm = await open(
      jsonEncode(
        SharedPhases(
          updatedOn: today,
          periods: [PeriodEvent(startDate: DateTime(2026, 5, 13))],
          nextPeriod: today,
        ).toJson(),
      ),
    );
    expect(vm.nextPeriodText, 'Period expected today');
    expect(vm.phasesCycleLine, isNotNull);
  });
}
