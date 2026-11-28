// The Log tab is built with the shell, before the pod has answered: its
// draft has to follow the data when it arrives.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/log/log_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  final now = DateTime(2026, 6, 10, 9, 30);
  final day = DateTime(2026, 6, 10);
  final yesterday = DateTime(2026, 6, 9);
  final logged = DailyLog(
    date: day,
    symptoms: const {Symptom.cramps},
    signs: BodySigns(moods: const {Mood.irritable}),
  );
  late FakePodService pod;
  late HealthRepository repo;
  late LogViewModel vm;

  // The pod already holds a log for today and one for yesterday; the view
  // model is made before the repository has read them.
  setUp(() async {
    pod = FakePodService();
    final earlier = HealthRepository(pod, protection: DataProtection.plain);
    await earlier.load();
    await earlier.apply(
      (d) => d
          .withLoggedDay(logged)
          .withLoggedDay(DailyLog(date: yesterday, painLevel: 3)),
    );
    repo = HealthRepository(pod, protection: DataProtection.plain);
    vm = LogViewModel(repo, now: () => now);
  });

  test('before the pod answers the day is empty', () {
    expect(vm.isEmpty, isTrue);
    expect(vm.isDirty, isFalse);
  });

  test('an untouched draft takes up the day once the pod answers', () async {
    var notified = 0;
    vm.addListener(() => notified++);
    await repo.load();
    expect(vm.symptoms, {Symptom.cramps});
    expect(vm.signs.moods, {Mood.irritable});
    expect(vm.isDirty, isFalse);
    expect(vm.isSavedAsIs, isTrue);
    expect(notified, greaterThan(0));
  });

  test('so taking a mood off and saving really takes it off', () async {
    await repo.load();
    vm.toggleMood(Mood.irritable);
    expect(vm.isDirty, isTrue);
    await vm.save();
    expect(
      repo.data.logFor(day),
      DailyLog(date: day, symptoms: logged.symptoms),
    );
  });

  test('what was entered before the pod answered is kept', () async {
    vm.setPain(7);
    await repo.load();
    expect(vm.pain, 7);
    expect(vm.symptoms, isEmpty);
    expect(vm.isDirty, isTrue);
  });

  test('another day picked before the pod answered follows too', () async {
    vm.goBack();
    expect(vm.pain, isNull);
    await repo.load();
    expect(vm.date, yesterday);
    expect(vm.pain, 3);
    expect(vm.isDirty, isFalse);
  });

  test('after a save the draft stays what was saved', () async {
    await repo.load();
    vm.setPain(5);
    await vm.save();
    expect(vm.pain, 5);
    expect(vm.isDirty, isFalse);
    vm.setPain(6);
    await repo.load(force: true);
    expect(vm.pain, 6);
    expect(vm.isDirty, isTrue);
  });
}
