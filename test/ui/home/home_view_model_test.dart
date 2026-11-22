import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/home/home_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9, 30);
  late FakePodService pod;
  late HealthRepository repo;
  late HomeViewModel vm;

  setUp(() async {
    pod = FakePodService();
    repo = HealthRepository(pod, protection: DataProtection.encrypted);
    await repo.load();
    vm = HomeViewModel(repo, now: () => today);
  });

  test('is loaded once the repository is', () async {
    final fresh = HomeViewModel(
      HealthRepository(FakePodService(), protection: DataProtection.plain),
      now: () => today,
    );
    expect(fresh.isLoaded, isFalse);
    expect(vm.isLoaded, isTrue);
  });

  test('with nothing logged there is no prediction and no data', () {
    expect(vm.hasData, isFalse);
    expect(vm.prediction.method, PredictionMethod.insufficientData);
    expect(vm.daysUntilNextPeriod, isNull);
    expect(vm.isLoading, isFalse);
    expect(vm.error, isNull);
  });

  group('logging a period start', () {
    test('today by default, and the prediction follows', () async {
      await vm.logPeriodStart();
      expect(repo.data.periods.map((p) => p.startDate), [
        DateTime(2026, 6, 10),
      ]);
      expect(vm.prediction.method, PredictionMethod.cycleAverage);
      expect(vm.prediction.currentCycleDay, 1);
      expect(vm.daysUntilNextPeriod, CyclePredictor.defaultCycleLength);
      expect(pod.writes, 1);
    });

    test('on a chosen day', () async {
      await vm.logPeriodStart(DateTime(2026, 5, 13));
      expect(repo.data.periods.single.startDate, DateTime(2026, 5, 13));
      expect(vm.prediction.currentCycleDay, 29);
      expect(vm.daysUntilNextPeriod, 0, reason: '13 May + 28 days is today');
    });

    test('can be undone', () async {
      await vm.logPeriodStart();
      await vm.removePeriodStart(DateTime(2026, 6, 10));
      expect(repo.data.periods, isEmpty);
    });
  });

  group('logging a temperature', () {
    final cases = <({String name, double celsius, bool ok})>[
      (name: 'a normal reading', celsius: 36.4, ok: true),
      (name: 'the lowest plausible', celsius: 34.0, ok: true),
      (name: 'the highest plausible', celsius: 42.0, ok: true),
      (name: 'too low to be a body temperature', celsius: 30.0, ok: false),
      (name: 'too high to be a body temperature', celsius: 45.0, ok: false),
    ];
    for (final c in cases) {
      test(c.name, () async {
        final accepted = await vm.logTemperature(c.celsius);
        expect(accepted, c.ok);
        expect(repo.data.readings.length, c.ok ? 1 : 0);
        if (c.ok) {
          expect(repo.data.readings.single.date, DateTime(2026, 6, 10));
          expect(repo.data.readings.single.source, ReadingSource.manual);
        }
      });
    }

    test('replaces the same day\'s reading', () async {
      await vm.logTemperature(36.4);
      await vm.logTemperature(36.6);
      expect(repo.data.readings.single.celsius, 36.6);
      expect(vm.todaysReading?.celsius, 36.6);
    });
  });

  test('shows the latest reading and the last period start', () async {
    await repo.apply(
      (d) => d
          .withReading(
            TemperatureReading(date: DateTime(2026, 6, 8), celsius: 36.3),
          )
          .withReading(
            TemperatureReading(date: DateTime(2026, 6, 9), celsius: 36.5),
          )
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 27))),
    );
    expect(vm.latestReading?.date, DateTime(2026, 6, 9));
    expect(vm.todaysReading, isNull);
    expect(vm.lastPeriodStart, DateTime(2026, 5, 27));
    expect(vm.prediction.predictedNextPeriod, DateTime(2026, 6, 24));
    expect(vm.daysUntilNextPeriod, 14);
  });

  test('the repository\'s loading flag and error pass through', () async {
    pod.failWrites = const PodAccessException('403');
    await vm.logPeriodStart();
    expect(vm.error, RepositoryError.saveFailed);
    vm.clearError();
    expect(vm.error, isNull);
  });

  test('notifies when the data changes', () async {
    var notified = 0;
    vm.addListener(() => notified++);
    await vm.logPeriodStart();
    expect(notified, greaterThan(0));
  });
}
