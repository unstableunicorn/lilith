import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/received/received_view_model.dart';
import 'package:lilith/ui/share/share_view_model.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_share_reader.dart';

void main() {
  const me = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const codec = HealthDocumentCodec();
  final may1 = DateTime(2026, 5, 1);
  final key = ShareKey.generate(Random(5));
  final copyUrl = SharePlan.forRecipient(me).documentUrl(ownerRoot);
  final theirs = HealthData.empty.withPeriod(PeriodEvent(startDate: may1));

  late HealthRepository health;
  late FakeShareReader reader;
  late ReceivedShareRepository repo;
  late ReceivedViewModel vm;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    reader.documents[copyUrl] = const ShareCipher().encrypt(
      codec.encode(theirs),
      key,
      Random(1),
    );
    repo = ReceivedShareRepository(health, reader, ownWebId: me);
    vm = ReceivedViewModel(repo, ownWebId: me, now: () => may1);
  });

  test('starts empty and cannot add', () {
    expect(vm.received, isEmpty);
    expect(vm.webIdProblem, WebIdProblem.empty);
    expect(vm.canAdd, isFalse);
    expect(vm.error, isNull);
  });

  test('checks the WebID like the sharing form does', () {
    vm.setLabel('Elric');
    vm.setWebId('elric');
    expect(vm.webIdProblem, WebIdProblem.notALink);
    vm.setWebId(me);
    expect(vm.webIdProblem, WebIdProblem.yourOwn);
    vm.setWebId(owner);
    expect(vm.webIdProblem, isNull);
    expect(vm.canAdd, isTrue);
  });

  test(
    'an encrypted share without the code says so and keeps the form',
    () async {
      vm.setLabel('Elric');
      vm.setWebId(owner);
      expect(await vm.add(), isFalse);
      expect(vm.error, ReceivedShareError.needsCode);
      expect(vm.label, 'Elric');
      expect(vm.received, isEmpty);
      vm.setCode('x');
      expect(vm.error, isNull);
    },
  );

  test('with the code it is added and the form clears', () async {
    vm.setLabel('Elric');
    vm.setWebId(owner);
    vm.setCode(key.code);
    expect(await vm.add(), isTrue);
    expect(vm.received.single.label, 'Elric');
    expect(vm.label, '');
    expect(vm.webId, '');
    expect(vm.code, '');
    expect(vm.isBusy, isFalse);
    await vm.remove(vm.received.single);
    expect(vm.received, isEmpty);
  });

  test('summarises for the Pod tab and explains every error', () {
    ReceivedShare r(String label) =>
        ReceivedShare(sharerWebId: '$owner$label', label: label, addedOn: may1);
    expect(receivedSummary([]), 'Nobody is sharing with you');
    expect(receivedSummary([r('Elric')]), 'Elric shares with you');
    expect(receivedSummary([r('A'), r('B')]), '2 people share with you');
    for (final e in ReceivedShareError.values) {
      expect(describeReceivedError(e), isNotEmpty);
    }
  });

  test('starts from an invite when given one', () {
    final filled = ReceivedViewModel(
      repo,
      ownWebId: me,
      now: () => may1,
      prefill: ShareInvite(sharerWebId: owner, code: key.code),
    );
    expect(filled.webId, owner);
    expect(filled.code, key.code);
    expect(filled.webIdProblem, isNull);
    expect(filled.canAdd, isFalse);
    filled.setLabel('Elric');
    expect(filled.canAdd, isTrue);
  });

  test('describes each share\'s state after a check', () async {
    vm.setLabel('Elric');
    vm.setWebId(owner);
    vm.setCode(key.code);
    await vm.add();
    final share = vm.received.single;
    expect(vm.stateText(share), 'Up to date');
    expect(vm.hasEnded(share), isFalse);
    reader.documents.clear();
    await vm.refreshAll();
    expect(vm.stateText(share), 'Ended');
    expect(vm.hasEnded(share), isTrue);
    final fresh = ReceivedViewModel(
      ReceivedShareRepository(health, reader, ownWebId: me),
      ownWebId: me,
      now: () => may1,
    );
    expect(fresh.stateText(share), 'Checking…');
  });

  test(
    'changes a code in place: refuses a wrong one, keeps a right one',
    () async {
      vm.setLabel('Elric');
      vm.setWebId(owner);
      vm.setCode(key.code);
      await vm.add();
      final share = vm.received.single;
      final newKey = ShareKey.generate(Random(11));
      reader.documents[copyUrl] = const ShareCipher().encrypt(
        codec.encode(theirs),
        newKey,
        Random(3),
      );
      expect(vm.isEditingCode(share), isFalse);
      vm.startChangingCode(share);
      expect(vm.isEditingCode(share), isTrue);
      expect(vm.canSaveCode, isFalse);
      vm.setNewCode(key.code);
      expect(await vm.saveCode(share), isFalse);
      expect(vm.codeError, ReceivedShareError.wrongCode);
      expect(vm.isEditingCode(share), isTrue);
      vm.setNewCode(newKey.code);
      expect(vm.codeError, isNull);
      expect(await vm.saveCode(share), isTrue);
      expect(vm.isEditingCode(share), isFalse);
      expect(vm.received.single.code, newKey.code);
      vm.startChangingCode(vm.received.single);
      vm.cancelChangingCode();
      expect(vm.isEditingCode(vm.received.single), isFalse);
    },
  );
}
