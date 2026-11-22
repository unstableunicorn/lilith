import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/history/history_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  late HealthRepository repo;
  late HistoryViewModel vm;

  DateTime d(int day) => DateTime(2026, 6, day);

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = HistoryViewModel(repo);
  });

  test('with nothing logged there is no history', () {
    expect(vm.hasHistory, isFalse);
    expect(vm.cycles, isEmpty);
    expect(vm.readings, isEmpty);
    expect(vm.days, isEmpty);
  });

  test('cycles are newest first with the length to the next start', () async {
    await repo.apply(
      (data) => data
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 15)))
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
          .withPeriod(PeriodEvent(startDate: d(10))),
    );
    expect(vm.cycles.map((c) => c.start), [
      d(10),
      DateTime(2026, 5, 13),
      DateTime(2026, 4, 15),
    ]);
    expect(vm.cycles.map((c) => c.length), [null, 28, 28]);
    expect(vm.hasHistory, isTrue);
  });

  test('readings and days come newest first', () async {
    await repo.apply(
      (data) => data
          .withReading(TemperatureReading(date: d(1), celsius: 36.2))
          .withReading(TemperatureReading(date: d(3), celsius: 36.5))
          .withDailyLog(DailyLog(date: d(2), painLevel: 3))
          .withDailyLog(DailyLog(date: d(4), flow: FlowIntensity.light)),
    );
    expect(vm.readings.map((r) => r.date), [d(3), d(1)]);
    expect(vm.days.map((l) => l.date), [d(4), d(2)]);
  });

  test(
    'the chart takes the last 60 readings in order, with period starts',
    () async {
      await repo.apply((data) {
        var next = data.withPeriod(
          PeriodEvent(startDate: DateTime(2026, 3, 1)),
        );
        for (var i = 0; i < 70; i++) {
          next = next.withReading(
            TemperatureReading(
              date: DateTime(2026, 3, 1 + i),
              celsius: 36.0 + (i % 5) / 10,
            ),
          );
        }
        return next;
      });
      expect(vm.chartReadings, hasLength(60));
      expect(vm.chartReadings.first.date, DateTime(2026, 3, 11));
      expect(vm.chartReadings.last.date, DateTime(2026, 5, 9));
      expect(vm.periodStarts, {DateTime(2026, 3, 1)});
    },
  );

  test('removing a reading or a period start writes through', () async {
    await repo.apply(
      (data) => data
          .withReading(TemperatureReading(date: d(1), celsius: 36.2))
          .withPeriod(PeriodEvent(startDate: d(1))),
    );
    await vm.removeReading(d(1));
    await vm.removePeriod(d(1));
    expect(repo.data.readings, isEmpty);
    expect(repo.data.periods, isEmpty);
  });
}
