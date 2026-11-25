import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/cycle_phase.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/home/home_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  readingDayTests();
  periodInProgressTests();
  forecastTests();
  todaysLogTests();
  cycleStatusTests();
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

    test("replaces the same day's reading", () async {
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

  test("the repository's loading flag and error pass through", () async {
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

void todaysLogTests() {
  final today = DateTime(2026, 6, 10, 9, 30);
  test('todaysLog is the log for today, if any', () async {
    final repo = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await repo.load();
    final vm = HomeViewModel(repo, now: () => today);
    expect(vm.todaysLog, isNull);
    final log = DailyLog(date: today, flow: FlowIntensity.light, painLevel: 2);
    await repo.apply((d) => d.withDailyLog(log));
    expect(vm.todaysLog, log);
  });
}

void forecastTests() {
  final today = DateTime(2026, 6, 10, 9, 30);

  Future<HealthRepository> twoCycles() async {
    final repo = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await repo.load();
    await repo.apply((d) {
      var next = d
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 15)))
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 6, 10)));
      for (final start in [DateTime(2026, 4, 15), DateTime(2026, 5, 13)]) {
        for (var i = 0; i < 3; i++) {
          next = next.withDailyLog(
            DailyLog(
              date: start.add(Duration(days: i)),
              symptoms: const {Symptom.cramps},
              painLevel: 6,
            ),
          );
        }
      }
      return next;
    });
    return repo;
  }

  test('with little logged there is no forecast', () async {
    final repo = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await repo.load();
    final vm = HomeViewModel(repo, now: () => today);
    expect(vm.forecast.hasData, isFalse);
  });

  test('past cycles forecast the week ahead in plain words', () async {
    final vm = HomeViewModel(await twoCycles(), now: () => today);
    expect(vm.forecast.hasData, isTrue);
    expect(vm.forecast.likely.first.symptom, Symptom.cramps);
    expect(vm.forecastSummary, contains('6 logged days'));
    expect(vm.forecastSummary, contains('6/10'));
  });
}

void readingDayTests() {
  final today = DateTime(2026, 6, 10);
  late HealthRepository repo;
  late HomeViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = HomeViewModel(repo, now: () => today);
  });

  test(
    'a temperature can be logged for an earlier day, then today again',
    () async {
      expect(vm.readingDayIsToday, isTrue);
      expect(vm.readingDayLabel, "Today's temperature (°C)");
      vm.setReadingDay(DateTime(2026, 6, 8, 15));
      expect(vm.readingDay, DateTime(2026, 6, 8));
      expect(vm.readingDayLabel, 'Temperature on 8 Jun (°C)');
      vm.setReadingDay(DateTime(2026, 6, 20));
      expect(vm.readingDay, DateTime(2026, 6, 8));
      expect(await vm.logTemperature(36.5), isTrue);
      expect(repo.data.readings.single.date, DateTime(2026, 6, 8));
      expect(vm.readingDayIsToday, isTrue);
    },
  );
}

void periodInProgressTests() {
  final today = DateTime(2026, 6, 10, 9);
  DateTime june(int d) => DateTime(2026, 6, d);
  late HealthRepository repo;
  late HomeViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = HomeViewModel(repo, now: () => today);
  });

  Future<void> started(int day, {int? end}) => repo.apply(
    (d) => d.withPeriod(
      PeriodEvent(
        startDate: june(day),
        endDate: end == null ? null : june(end),
      ),
    ),
  );

  test('no period means none in progress', () {
    expect(vm.periodInProgress, isNull);
    expect(vm.periodDay, isNull);
  });

  final cases = [
    (name: 'started today', start: 10, end: null, day: 1),
    (name: 'started two days ago', start: 8, end: null, day: 3),
    (name: 'bleeding logged yesterday', start: 6, end: 9, day: 5),
    (name: 'nothing logged for three days', start: 5, end: 7, day: null),
  ];
  for (final c in cases) {
    test('in progress: ${c.name}', () async {
      await started(c.start, end: c.end);
      expect(vm.periodDay, c.day);
      expect(vm.periodInProgress != null, c.day != null);
    });
  }

  test('marking it ended records the day and ends it', () async {
    await started(8);
    expect(await vm.markPeriodEnded(june(9)), isTrue);
    final p = repo.data.periods.single;
    expect(p.endDate, june(9));
    expect(p.ended, isTrue);
    expect(vm.periodInProgress, isNull);
  });

  test('an end before the start or after today is refused', () async {
    await started(8);
    expect(await vm.markPeriodEnded(june(7)), isFalse);
    expect(await vm.markPeriodEnded(june(11)), isFalse);
    expect(repo.data.periods.single.ended, isFalse);
  });

  test('yesterday is offered as an end day only when the period began '
      'before today', () async {
    await started(10);
    expect(vm.quickEndDays, [june(10)]);
    await repo.apply((d) => d.withoutPeriod(june(10)));
    await started(8);
    expect(vm.quickEndDays, [june(10), june(9)]);
  });
}

void cycleStatusTests() {
  final today = DateTime(2026, 6, 10, 9);
  late HealthRepository repo;
  late HomeViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = HomeViewModel(repo, now: () => today);
  });

  test('the cycle status follows the logged periods', () async {
    expect(vm.cycleStatus.day, isNull);
    await repo.apply(
      (d) => d.withPeriod(
        PeriodEvent(
          startDate: DateTime(2026, 6, 2),
          endDate: DateTime(2026, 6, 5),
        ),
      ),
    );
    expect(
      (day: vm.cycleStatus.day, phase: vm.cycleStatus.phase),
      (day: 9, phase: CyclePhase.follicular),
    );
  });

  test('hormonal contraception in the profile leaves the phase out', () async {
    await repo.apply(
      (d) => d
          .withPeriod(
            PeriodEvent(
              startDate: DateTime(2026, 6, 2),
              endDate: DateTime(2026, 6, 5),
            ),
          )
          .withProfile(
            HealthProfile(contraception: Contraception.combinedPill),
          ),
    );
    expect(
      (phase: vm.cycleStatus.phase, hormonal: vm.cycleStatus.hormonal),
      (phase: null, hormonal: true),
    );
  });
}
