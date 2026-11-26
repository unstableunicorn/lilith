import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/share/share_view_model.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_share_service.dart';

void main() {
  const me =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  final may1 = DateTime(2026, 5, 1, 10);

  late FakeShareService pod;
  late ShareRepository repo;
  late ShareViewModel vm;

  setUp(() async {
    final health = HealthRepository(
      FakePodService(),
      protection: DataProtection.encrypted,
    );
    await health.load();
    pod = FakeShareService();
    repo = ShareRepository(
      health,
      pod,
      protection: DataProtection.encrypted,
      random: Random(1),
    );
    vm = ShareViewModel(repo, ownWebId: me, now: () => may1);
  });

  test('starts empty with the recommended duration and cannot share', () {
    expect(vm.shares, isEmpty);
    expect(vm.duration, ShareDuration.recommended);
    expect(vm.webIdProblem, WebIdProblem.empty);
    expect(vm.canShare, isFalse);
    expect(vm.created, isNull);
  });

  test('says what is wrong with the WebID', () {
    vm.setLabel('Alex');
    vm.setWebId('alex');
    expect(vm.webIdProblem, WebIdProblem.notALink);
    vm.setWebId('ftp://x.example/card#me');
    expect(vm.webIdProblem, WebIdProblem.notALink);
    vm.setWebId(' $me ');
    expect(vm.webIdProblem, WebIdProblem.yourOwn);
    vm.setWebId(wife);
    expect(vm.webIdProblem, isNull);
    expect(vm.canShare, isTrue);
    vm.setLabel('  ');
    expect(vm.canShare, isFalse);
  });

  test('share creates it, shows the code and clears the form', () async {
    vm.setLabel('Alex');
    vm.setWebId(wife);
    vm.setDuration(ShareDuration.ninetyDays);
    await vm.share();
    expect(vm.shares, hasLength(1));
    final share = vm.created!;
    expect(share.label, 'Alex');
    expect(share.expiresOn, DateTime(2026, 7, 30));
    expect(share.code, isNotNull);
    expect(vm.label, '');
    expect(vm.webId, '');
    expect(vm.duration, ShareDuration.recommended);
    vm.dismissCreated();
    expect(vm.created, isNull);
  });

  test('notes stay out unless chosen; the choice resets after', () async {
    expect(vm.includeNotes, isFalse);
    vm
      ..setLabel('Alex')
      ..setWebId(wife)
      ..setIncludeNotes(on: true);
    await vm.share();
    expect(vm.created!.includeNotes, isTrue);
    expect(vm.includeNotes, isFalse);
  });

  test(
    'contraception stays out unless chosen; the choice resets after',
    () async {
      expect(vm.includeContraception, isFalse);
      vm
        ..setLabel('Alex')
        ..setWebId(wife)
        ..setIncludeContraception(on: true);
      expect(vm.includeContraception, isTrue);
      await vm.share();
      expect(vm.created!.includeContraception, isTrue);
      expect(vm.includeContraception, isFalse);
    },
  );

  test('a refused share keeps the form and shows nothing created', () async {
    pod.failOpen = const PodAccessException('403');
    vm.setLabel('Alex');
    vm.setWebId(wife);
    await vm.share();
    expect(vm.created, isNull);
    expect(vm.label, 'Alex');
    expect(vm.error, ShareError.failed);
    vm.clearError();
    expect(vm.error, isNull);
  });

  test('reveals and hides a code, and ends a share', () async {
    vm.setLabel('Alex');
    vm.setWebId(wife);
    await vm.share();
    final share = vm.shares.single;
    expect(vm.isRevealed(share), isFalse);
    vm.toggleRevealed(share);
    expect(vm.isRevealed(share), isTrue);
    vm.toggleRevealed(share);
    expect(vm.isRevealed(share), isFalse);
    await vm.revoke(share);
    expect(vm.shares, isEmpty);
  });

  test('describes when a share ends', () {
    final today = DateTime(2026, 5, 1);
    Share share({DateTime? end}) => Share(
      recipientWebId: wife,
      label: 'A',
      createdOn: today,
      expiresOn: end,
    );
    expect(shareEndText(share(), today: today), 'Until you end it');
    expect(
      shareEndText(share(end: DateTime(2026, 5, 31)), today: today),
      'Until Sun 31 May 2026',
    );
    expect(
      shareEndText(share(end: DateTime(2026, 4, 30)), today: today),
      'Ended on Thu 30 Apr 2026',
    );
  });

  test('summarises the shares for the Pod tab', () {
    Share share(String label) =>
        Share(recipientWebId: '$wife$label', label: label, createdOn: may1);
    expect(sharingSummary([]), 'Not shared with anyone');
    expect(sharingSummary([share('Alex')]), 'Shared with Alex');
    expect(
      sharingSummary([share('A'), share('B'), share('C')]),
      'Shared with 3 people',
    );
  });

  test('the invite link carries the sharer and the code', () async {
    vm.setLabel('Alex');
    vm.setWebId(wife);
    await vm.share();
    final link = vm.inviteLink(vm.shares.single);
    expect(link.origin, 'https://lilith.unstableunicorn.dev');
    expect(
      ShareInvite.fromUri(link),
      ShareInvite(sharerWebId: me, code: vm.shares.single.code),
    );
  });

  test(
    'a report share takes a span, has no code, and knows its folder',
    () async {
      vm.setLabel('Dr Patel');
      vm.setWebId(wife);
      vm.setContent(ShareContent.report);
      vm.setRange(ExportRange.year);
      await vm.share();
      final share = vm.created!;
      expect(share.isReport, isTrue);
      expect(share.range, ExportRange.year);
      expect(share.code, isNull);
      expect(vm.createdLink.toString(), endsWith('/shares/${share.id}/'));
      expect(vm.content, ShareContent.cycleData);
      expect(vm.range, ExportRange.sixMonths);
      expect(await vm.folderUrl(share), vm.createdLink);
      vm.dismissCreated();
      expect(vm.createdLink, isNull);
    },
  );

  test('describes what a share holds', () {
    final today = DateTime(2026, 5, 1);
    expect(
      shareContentText(
        Share(recipientWebId: wife, label: 'A', createdOn: today),
      ),
      'The app view',
    );
    expect(
      shareContentText(
        Share(
          recipientWebId: wife,
          label: 'A',
          createdOn: today,
          content: ShareContent.report,
          range: ExportRange.all,
        ),
      ),
      'A PDF report and CSV, everything',
    );
  });

  test('a custom end needs a day no earlier than tomorrow', () async {
    vm.setLabel('Alex');
    vm.setWebId(wife);
    vm.setDuration(ShareDuration.custom);
    expect(vm.needsCustomEnd, isTrue);
    expect(vm.canShare, isFalse);
    expect(vm.earliestEnd, DateTime(2026, 5, 2));
    vm.setCustomEnd(DateTime(2026, 5, 1));
    expect(vm.customEnd, isNull);
    vm.setCustomEnd(DateTime(2026, 6, 15, 9));
    expect(vm.customEnd, DateTime(2026, 6, 15));
    expect(vm.canShare, isTrue);
    await vm.share();
    expect(vm.created!.expiresOn, DateTime(2026, 6, 15));
    expect(vm.customEnd, isNull);
    expect(vm.duration, ShareDuration.recommended);
  });
}
