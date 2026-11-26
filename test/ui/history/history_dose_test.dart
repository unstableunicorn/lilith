import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/history/history_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  late HealthRepository repo;
  late HistoryViewModel vm;

  DateTime d(int day) => DateTime(2026, 6, day);
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 6, day, hour, minute);

  // A pill every day at 09:00, three hours' window, from 1 June; now is
  // 10 June at 08:00, so 10 June has no verdict yet.
  final schedule = ContraceptionSchedule(
    form: DoseForm.pill,
    start: d(1),
    daysOn: 21,
    daysOff: 0,
    windowHours: 3,
  );

  Future<void> withPill({
    Map<int, DateTime> done = const {},
    ContraceptionSchedule? s,
  }) => repo.apply((data) {
    var next = data.withProfile(
      HealthProfile(
        contraception: Contraception.combinedPill,
        contraceptionSchedule: s ?? schedule,
      ),
    );
    for (final MapEntry(:key, :value) in done.entries) {
      next = next.withDailyLog(
        DailyLog(date: d(key), contraceptionDoneAt: value),
      );
    }
    return next;
  });

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = HistoryViewModel(repo, now: () => at(10, 8));
  });

  test('without a schedule or a dose done, doses are not tracked', () async {
    await repo.apply(
      (data) =>
          data.withDailyLog(DailyLog(date: d(2), flow: FlowIntensity.light)),
    );
    expect(vm.tracksDoses, isFalse);
    expect(vm.doseStatusOn(d(2)), isNull);
  });

  test('with a schedule, doses are tracked', () async {
    await withPill();
    expect(vm.tracksDoses, isTrue);
  });

  test('a dose done without a schedule is tracked and taken', () async {
    await repo.apply(
      (data) => data.withDailyLog(
        DailyLog(date: d(2), contraceptionDoneAt: at(2, 20)),
      ),
    );
    expect(vm.tracksDoses, isTrue);
    expect(vm.doseStatusOn(d(2)), DoseStatus.taken);
  });

  test('each day is judged against the schedule', () async {
    await withPill(done: {1: at(1, 9, 5), 2: at(2, 15)});
    expect(vm.doseStatusOn(d(1)), DoseStatus.taken);
    expect(vm.doseStatusOn(d(2)), DoseStatus.late);
    expect(vm.doseStatusOn(d(3)), DoseStatus.missed);
    expect(vm.doseStatusOn(d(10)), isNull);
  });

  test('the dose line gives the time it was done', () async {
    await withPill(done: {1: at(1, 9, 5), 2: at(2, 15)});
    expect(vm.doseText(d(1)), contains('09:05'));
    expect(vm.doseText(d(2)), contains('15:00'));
    expect(vm.doseText(d(3)), isNotNull);
    expect(vm.doseText(d(10)), isNull);
  });

  test('missed days are listed though nothing was logged', () async {
    await repo.apply((data) => data.withPeriod(PeriodEvent(startDate: d(1))));
    await withPill(done: {1: at(1, 9), 2: at(2, 9)});
    expect(vm.cycles.single.days.map((l) => l.date), [
      for (var day = 9; day >= 1; day--) d(day),
    ]);
  });

  test('missed days before the first period are listed', () async {
    await repo.apply((data) => data.withPeriod(PeriodEvent(startDate: d(8))));
    await withPill(done: {1: at(1, 9)});
    expect(vm.daysBeforeFirstPeriod.map((l) => l.date), [
      for (var day = 7; day >= 1; day--) d(day),
    ]);
  });

  test('missed days are not listed before the schedule starts', () async {
    await repo.apply((data) => data.withPeriod(PeriodEvent(startDate: d(1))));
    await withPill(s: schedule.copyWith(start: d(8)));
    expect(vm.cycles.single.days.map((l) => l.date), [d(9), d(8)]);
  });

  test('the filter keeps only late and missed days', () async {
    await repo.apply((data) => data.withPeriod(PeriodEvent(startDate: d(1))));
    await withPill(
      done: {for (var day = 1; day <= 9; day++) day: at(day, 9)}
        ..[4] = at(4, 18)
        ..remove(6),
    );
    vm.setDoseProblemsOnly(on: true);
    expect(vm.doseProblemsOnly, isTrue);
    expect(vm.isFiltering, isTrue);
    expect(vm.cycles.single.days.map((l) => l.date), [d(6), d(4)]);
    expect(vm.matchCount, 2);
    vm.clearFilters();
    expect(vm.doseProblemsOnly, isFalse);
  });

  test('the search finds a day by its dose line', () async {
    await repo.apply((data) => data.withPeriod(PeriodEvent(startDate: d(1))));
    await withPill(done: {1: at(1, 9, 41)});
    vm.setQuery('09:41');
    expect(vm.cycles.single.days.map((l) => l.date), [d(1)]);
  });
}
