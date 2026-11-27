import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/share/share_view_model.dart';

import '../fakes/fake_pod_service.dart';
import '../fakes/fake_share_service.dart';

/// Moods and body signs go to a recipient only when the sharer says so,
/// and a pregnancy test never does.
void main() {
  const me = 'https://pod.example.org/me/profile/card#me';
  const wife = 'https://pod.example.org/wife/profile/card#me';
  const codec = HealthDocumentCodec();
  final may1 = DateTime(2026, 5, 1);
  final may2 = DateTime(2026, 5, 2);
  final may3 = DateTime(2026, 5, 3);
  final signs = BodySigns(
    moods: const {Mood.calm},
    sleep: SleepQuality.poor,
    pregnancyTest: PregnancyTest.positive,
  );
  final stored = HealthData.empty
      .withPeriod(PeriodEvent(startDate: may1))
      .withDailyLog(DailyLog(date: may1, painLevel: 4, signs: signs))
      // A day that holds nothing but signs, and one with only a test.
      .withDailyLog(DailyLog(date: may2, signs: signs))
      .withDailyLog(
        DailyLog(
          date: may3,
          signs: BodySigns(pregnancyTest: PregnancyTest.negative),
        ),
      );

  group('sharedView', () {
    test('leaves moods and body signs out unless asked', () {
      final seen = sharedView(stored);
      expect(seen.dailyLogs.map((l) => l.date), [may1]);
      expect(seen.dailyLogs.single.signs, BodySigns.none);
      expect(seen.dailyLogs.single.painLevel, 4);
    });

    test('includes them when asked, never the pregnancy test', () {
      final seen = sharedView(stored, includeSigns: true);
      expect(seen.dailyLogs.map((l) => l.date), [may1, may2]);
      for (final log in seen.dailyLogs) {
        expect(log.signs, signs.shared);
        expect(log.signs.pregnancyTest, isNull);
      }
    });

    test('never carries which Log groups the sharer shows', () {
      final data = stored.withLogGroup(LogGroup.skin, shown: true);
      expect(sharedView(data, includeSigns: true).logGroups, isNull);
    });
  });

  group('Share.includeSigns', () {
    Share share({bool include = false}) => Share(
      recipientWebId: wife,
      label: 'A',
      createdOn: may1,
      includeSigns: include,
    );

    test('is off unless chosen, and then not written', () {
      expect(share().includeSigns, isFalse);
      expect(share().toJson().containsKey('includeSigns'), isFalse);
    });

    test('round-trips when on, and is part of the value', () {
      final on = share(include: true);
      expect(on.includeSigns, isTrue);
      expect(Share.fromJson(on.toJson()), on);
      expect(Share.fromJson(on.toJson()).includeSigns, isTrue);
      expect(on, isNot(share()));
      expect(on.hashCode, isNot(share().hashCode));
    });
  });

  group('ShareRepository', () {
    late FakeShareService shares;
    late HealthRepository health;
    late ShareRepository repo;

    setUp(() async {
      final pod = FakePodService();
      health = HealthRepository(pod, protection: DataProtection.plain);
      pod.documents[health.documentPath] = codec.encode(stored);
      shares = FakeShareService();
      repo = ShareRepository(
        health,
        shares,
        protection: DataProtection.plain,
        random: Random(1),
      );
      await health.load();
    });

    Future<Share> create({
      bool include = false,
      ShareContent content = ShareContent.cycleData,
    }) async => (await repo.create(
      recipientWebId: wife,
      label: 'A',
      duration: ShareDuration.thirtyDays,
      today: may1,
      content: content,
      includeSigns: include,
    ))!;

    HealthData copyOf(Share share) =>
        codec.decode(shares.folders['shares/${share.id}']!);

    test('a share without the choice holds no moods or body signs', () async {
      final share = await create();
      expect(share.includeSigns, isFalse);
      expect(copyOf(share).dailyLogs.every((l) => l.signs.isEmpty), isTrue);
      expect(shares.folders['shares/${share.id}'], isNot(contains('calm')));
    });

    test('a share with the choice holds them, never the test', () async {
      final share = await create(include: true);
      expect(share.includeSigns, isTrue);
      expect(copyOf(share).dailyLogs.first.signs, signs.shared);
      expect(
        shares.folders['shares/${share.id}'],
        isNot(contains('pregnancyTest')),
      );
    });

    test('a phases share never takes the choice', () async {
      final share = await create(include: true, content: ShareContent.phases);
      expect(share.includeSigns, isFalse);
    });

    test('logging a mood rewrites a copy that includes them', () async {
      final share = await create(include: true);
      await health.apply(
        (d) => d.withDailyLog(
          DailyLog(
            date: DateTime(2026, 5, 4),
            signs: BodySigns(moods: const {Mood.sad}),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(shares.folders['shares/${share.id}'], contains('sad'));
    });
  });

  group('ShareViewModel', () {
    late ShareViewModel vm;

    setUp(() async {
      final health = HealthRepository(
        FakePodService(),
        protection: DataProtection.plain,
      );
      await health.load();
      vm = ShareViewModel(
        ShareRepository(
          health,
          FakeShareService(),
          protection: DataProtection.plain,
          random: Random(1),
        ),
        ownWebId: me,
        now: () => may1,
      );
    });

    test('signs stay out unless chosen; the choice resets after', () async {
      expect(vm.includeSigns, isFalse);
      var told = 0;
      vm
        ..addListener(() => told++)
        ..setLabel('Alex')
        ..setWebId(wife)
        ..setIncludeSigns(on: true);
      expect(vm.includeSigns, isTrue);
      expect(told, 3);
      await vm.share();
      expect(vm.created!.includeSigns, isTrue);
      expect(vm.includeSigns, isFalse);
    });
  });
}
