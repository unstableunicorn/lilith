import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/ui/relief/relief_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9);
  late HealthRepository repo;
  late ReliefViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = ReliefViewModel(repo, now: () => today);
  });

  test(
    'with nothing logged it starts on cramps and every symptom has advice',
    () {
      expect(vm.recent, isEmpty);
      expect(vm.selected, Symptom.cramps);
      for (final s in Symptom.values) {
        vm.select(s);
        expect(vm.advice.symptom, s);
        expect(vm.remedies, isNotEmpty);
      }
    },
  );

  test(
    'recent symptoms are the last fortnight\'s, latest first, and lead',
    () async {
      await repo.apply(
        (d) => d
            .withDailyLog(
              DailyLog(date: DateTime(2026, 5, 1), symptoms: {Symptom.nausea}),
            )
            .withDailyLog(
              DailyLog(
                date: DateTime(2026, 6, 1),
                symptoms: {Symptom.bloating},
              ),
            )
            .withDailyLog(
              DailyLog(
                date: DateTime(2026, 6, 9),
                symptoms: {Symptom.headache, Symptom.bloating},
              ),
            ),
      );
      expect(vm.recent, [Symptom.headache, Symptom.bloating]);
      expect(vm.selected, Symptom.headache);
      expect(vm.ordered.take(2), [Symptom.headache, Symptom.bloating]);
      expect(vm.ordered.length, Symptom.values.length);
    },
  );

  test('a choice sticks even when the logs change', () async {
    vm.select(Symptom.insomnia);
    await repo.apply(
      (d) => d.withDailyLog(DailyLog(date: today, symptoms: {Symptom.cramps})),
    );
    expect(vm.selected, Symptom.insomnia);
  });

  test(
    'rating a remedy toggles and ranks helped first, unhelpful last',
    () async {
      vm.select(Symptom.cramps);
      final first = vm.remedies.first;
      final last = vm.remedies.last;
      await vm.toggleDidNotHelp(first);
      await vm.toggleHelped(last);
      expect(vm.ratingFor(first), RemedyRating.didNotHelp);
      expect(vm.ratingFor(last), RemedyRating.helped);
      expect(vm.remedies.first, last);
      expect(vm.remedies.last, first);
      await vm.toggleHelped(last);
      expect(vm.ratingFor(last), RemedyRating.untried);
      expect(repo.data.remedyFeedback.single.symptomKey, 'cramps');
    },
  );

  test('a remedy with something to buy goes on the list once', () async {
    vm.select(Symptom.cramps);
    final heat = vm.remedies.firstWhere((r) => r.shopItem != null);
    expect(vm.isOnList(heat), isFalse);
    await vm.addToList(heat);
    await vm.addToList(heat);
    expect(vm.isOnList(heat), isTrue);
    expect(repo.data.shopping.single.name, heat.shopItem);
    expect(repo.data.shopping.single.note, 'For Cramps');
    expect(repo.data.shopping.single.symptomKey, 'cramps');
  });
}
