import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/log/log_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9, 30);
  final day = DateTime(2026, 6, 10);
  late FakePodService pod;
  late HealthRepository repo;
  late LogViewModel vm;

  setUp(() async {
    pod = FakePodService();
    repo = HealthRepository(pod, protection: DataProtection.encrypted);
    await repo.load();
    vm = LogViewModel(repo, now: () => today);
  });

  test('starts on today with an empty draft and nothing to save', () {
    expect(vm.date, day);
    expect(vm.flow, FlowIntensity.none);
    expect(vm.symptoms, isEmpty);
    expect(vm.pain, isNull);
    expect(vm.isEmpty, isTrue);
    expect(vm.isDirty, isFalse);
    expect(vm.canGoForward, isFalse);
  });

  test(
    'edits make the draft dirty and save stores one log for the day',
    () async {
      vm.setFlow(FlowIntensity.medium);
      vm.toggleSymptom(Symptom.cramps);
      vm.toggleSymptom(Symptom.bloating);
      vm.toggleSymptom(Symptom.bloating);
      vm.setPain(4);
      expect(vm.isDirty, isTrue);
      await vm.save();
      expect(vm.isDirty, isFalse);
      expect(repo.data.dailyLogs, [
        DailyLog(
          date: day,
          flow: FlowIntensity.medium,
          symptoms: const {Symptom.cramps},
          painLevel: 4,
        ),
      ]);
    },
  );

  test('moving between days loads what was logged there', () async {
    final yesterday = DateTime(2026, 6, 9);
    await repo.apply(
      (d) => d.withDailyLog(DailyLog(date: yesterday, painLevel: 7)),
    );
    vm.goBack();
    expect(vm.date, yesterday);
    expect(vm.pain, 7);
    expect(vm.canGoForward, isTrue);
    vm.goForward();
    expect(vm.date, day);
    expect(vm.pain, isNull);
    vm.goForward();
    expect(vm.date, day, reason: 'the future cannot be logged');
  });

  test('picking a date clamps to today and discards the draft', () {
    vm.setPain(2);
    vm.pickDate(DateTime(2027, 1, 1));
    expect(vm.date, day);
    expect(
      vm.pain,
      isNull,
      reason: 'the draft belongs to the day it was made on',
    );
  });

  test('clearing and saving removes the day', () async {
    await repo.apply(
      (d) => d.withDailyLog(DailyLog(date: day, flow: FlowIntensity.heavy)),
    );
    vm = LogViewModel(repo, now: () => today);
    expect(vm.flow, FlowIntensity.heavy);
    expect(vm.isDirty, isFalse);
    vm.clear();
    expect(vm.isEmpty, isTrue);
    expect(vm.isDirty, isTrue);
    await vm.save();
    expect(repo.data.dailyLogs, isEmpty);
  });

  test('a pain rating can be unset', () {
    vm.setPain(5);
    vm.setPain(null);
    expect(vm.pain, isNull);
  });

  test(
    'a note is saved alone, reloads with the day, and blank clears it',
    () async {
      vm.setNote('Slept badly');
      expect(vm.isDirty, isTrue);
      await vm.save();
      expect(repo.data.logFor(day)?.note, 'Slept badly');
      vm
        ..goBack()
        ..goForward();
      expect(vm.note, 'Slept badly');
      vm.setNote('  ');
      await vm.save();
      expect(repo.data.logFor(day), isNull);
    },
  );

  group('the pill, patch or ring', () {
    final schedule = ContraceptionSchedule(
      form: DoseForm.ring,
      start: DateTime(2026, 5, 20),
      daysOn: 21,
      daysOff: 7,
      windowHours: 48,
      hour: 20,
    );

    Future<void> profile(Contraception? method, [ContraceptionSchedule? s]) =>
        repo.apply(
          (d) => d.copyWith(
            profile: HealthProfile(
              contraception: method,
              contraceptionSchedule: s,
            ),
          ),
        );

    test('asked about only for a method with a schedule to keep', () async {
      final cases = <(String, Contraception?, ContraceptionSchedule?, bool)>[
        ('no contraception', null, null, false),
        ('an implant', Contraception.implant, null, false),
        ('a pill, no schedule yet', Contraception.combinedPill, null, true),
        ('a ring, due today', Contraception.patchOrRing, schedule, true),
      ];
      for (final (name, method, s, want) in cases) {
        await profile(method, s);
        expect(vm.offersDose, want, reason: name);
      }
      expect(vm.doseIsPatchOrRing, isTrue);
    });

    test('not asked on a day nothing is due', () async {
      await profile(Contraception.patchOrRing, schedule);
      vm.pickDate(DateTime(2026, 6, 1));
      expect(vm.offersDose, isFalse);
    });

    test(
      'marked today now, an earlier day at its time, and unmarked',
      () async {
        await profile(Contraception.patchOrRing, schedule);
        vm.setDoseDone(true);
        expect(vm.doseDone, isTrue);
        await vm.save();
        expect(repo.data.logFor(day)?.contraceptionDoneAt, today);
        vm
          ..pickDate(DateTime(2026, 5, 20))
          ..setDoseDone(true);
        await vm.save();
        expect(
          repo.data.logFor(DateTime(2026, 5, 20))?.contraceptionDoneAt,
          DateTime(2026, 5, 20, 20),
        );
        vm.setDoseDone(false);
        await vm.save();
        expect(repo.data.logFor(DateTime(2026, 5, 20)), isNull);
      },
    );
  });

  test('an ovulation test result is saved, and can be unset', () async {
    expect(vm.ovulationTest, isNull);
    vm.setOvulationTest(OvulationTest.positive);
    expect(vm.isDirty, isTrue);
    await vm.save();
    expect(repo.data.logFor(day)?.ovulationTest, OvulationTest.positive);
    vm.setOvulationTest(null);
    await vm.save();
    expect(repo.data.logFor(day), isNull);
  });

  test(
    'is saving while the repository writes, and surfaces its error',
    () async {
      pod.failWrites = const PodUnavailableException('down');
      vm.setPain(1);
      final saving = vm.save();
      expect(vm.isSaving, isTrue);
      await saving;
      expect(vm.isSaving, isFalse);
      expect(vm.error, RepositoryError.saveFailed);
      vm.clearError();
      expect(vm.error, isNull);
    },
  );

  test('saving a bleeding day makes it part of a period', () async {
    vm.setFlow(FlowIntensity.medium);
    await vm.save();
    expect(repo.data.periods, hasLength(1));
    expect(repo.data.periods.single.startDate, vm.date);
    expect(repo.data.periods.single.endDate, vm.date);
  });
}
