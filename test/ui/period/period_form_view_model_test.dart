import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/period/period_form_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  final today = DateTime(2026, 6, 10);
  DateTime june(int d) => DateTime(2026, 6, d);
  late HealthRepository repo;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
  });

  PeriodFormViewModel vm(PeriodFormMode mode, {PeriodEvent? editing}) =>
      PeriodFormViewModel(repo, mode: mode, now: () => today, editing: editing);

  test('needs a first day; the last day may not come before it', () {
    final m = vm(PeriodFormMode.pastPeriod);
    expect(m.problems, [PeriodFormProblem.noFirstDay]);
    expect(m.canSave, isFalse);
    m.setFirstDay(june(5));
    expect(m.canSave, isTrue);
    m.setLastDay(june(3));
    expect(m.problems, [PeriodFormProblem.endBeforeStart]);
    m.setLastDay(null);
    expect(m.canSave, isTrue);
  });

  test('mid-period asks no last day; edit asks nothing about you', () {
    expect(vm(PeriodFormMode.midPeriod).asksLastDay, isFalse);
    expect(vm(PeriodFormMode.midPeriod).asksAboutYou, isTrue);
    expect(vm(PeriodFormMode.edit).asksLastDay, isTrue);
    expect(vm(PeriodFormMode.edit).asksAboutYou, isFalse);
    expect(
      vm(PeriodFormMode.pastPeriod).flows,
      isNot(contains(FlowIntensity.none)),
    );
  });

  test('the usual lengths must be plausible, or blank', () {
    final m = vm(PeriodFormMode.pastPeriod)..setFirstDay(june(1));
    m.setUsualCycleLength('9');
    expect(m.problems, [PeriodFormProblem.cycleLength]);
    m.setUsualCycleLength('28');
    m.setUsualPeriodLength('12');
    expect(m.problems, [PeriodFormProblem.periodLength]);
    m.setUsualPeriodLength('');
    expect(m.problems, isEmpty);
    expect(m.usualPeriodLength, isNull);
  });

  test(
    'save records the period, the usual lengths and contraception at once',
    () async {
      final m = vm(PeriodFormMode.pastPeriod)
        ..setFirstDay(june(1))
        ..setLastDay(june(5))
        ..setFlow(FlowIntensity.medium)
        ..setUsualCycleLength('29')
        ..setUsualPeriodLength('5')
        ..setHormonalContraception(true);
      expect(await m.save(), isTrue);
      expect(repo.data.periods, [
        PeriodEvent(
          startDate: june(1),
          endDate: june(5),
          flow: FlowIntensity.medium,
        ),
      ]);
      expect(repo.data.profile.usualCycleLength, 29);
      expect(repo.data.profile.usualPeriodLength, 5);
      expect(
        repo.data.profile.treatments,
        contains(FertilityTreatment.contraceptive),
      );
    },
  );

  test('mid-period saves an open period', () async {
    final m = vm(PeriodFormMode.midPeriod)..setFirstDay(june(8));
    await m.save();
    expect(repo.data.periods.single.isOpen, isTrue);
    expect(repo.data.periods.single.startDate, june(8));
  });

  test('editing moves the start and keeps the profile as it was', () async {
    await repo.apply(
      (d) => d
          .withPeriod(PeriodEvent(startDate: june(1), endDate: june(4)))
          .withProfile(HealthProfile(usualCycleLength: 31)),
    );
    final m = vm(PeriodFormMode.edit, editing: repo.data.periods.single)
      ..setFirstDay(june(2))
      ..setFlow(FlowIntensity.light);
    expect(m.lastDay, june(4));
    await m.save();
    expect(repo.data.periods, [
      PeriodEvent(
        startDate: june(2),
        endDate: june(4),
        flow: FlowIntensity.light,
      ),
    ]);
    expect(repo.data.profile.usualCycleLength, 31);
  });

  test('a refused save reports false and keeps the error', () async {
    final pod = FakePodService();
    repo = HealthRepository(pod, protection: DataProtection.plain);
    await repo.load();
    pod.failWrites = const PodUnavailableException('offline');
    final m = vm(PeriodFormMode.pastPeriod)..setFirstDay(june(1));
    expect(await m.save(), isFalse);
    expect(m.error, RepositoryError.saveFailed);
    m.clearError();
    expect(m.error, isNull);
  });
}
