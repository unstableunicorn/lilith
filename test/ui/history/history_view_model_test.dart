import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';
import 'package:lilith/ui/components/trend_chart.dart';
import 'package:lilith/ui/history/history_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  nightTests();
  groupingTests();
  chartSpanTests();
  cycleTextTests();
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

  test('statistics cover every cycle, whatever the filters', () async {
    await repo.apply(
      (data) => data
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 15)))
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
          .withPeriod(PeriodEvent(startDate: d(10))),
    );
    expect(vm.statistics?.cycleCount, 2);
    vm.setBleedingOnly(on: true);
    expect(vm.cycles, isEmpty);
    expect(vm.statistics?.cycleCount, 2);
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

void cycleTextTests() {
  test('describes a cycle with what is known of its period', () {
    final start = DateTime(2026, 5, 1);
    expect(
      HistoryViewModel.cycleText(CycleEntry(start: start)),
      'Current cycle',
    );
    expect(
      HistoryViewModel.cycleText(CycleEntry(start: start, length: 28)),
      '28 days',
    );
    expect(
      HistoryViewModel.cycleText(
        CycleEntry(
          start: start,
          length: 28,
          periodLength: 5,
          flow: FlowIntensity.medium,
        ),
      ),
      '28 days · period 5 days, medium',
    );
    expect(
      HistoryViewModel.cycleText(CycleEntry(start: start, periodLength: 1)),
      'Current cycle · period 1 day',
    );
  });

  final ranges = [
    (name: 'a range', from: 4, to: 7, want: '4 to 7 days'),
    (name: 'the same length every time', from: 5, to: 5, want: '5 days'),
    (name: 'one day every time', from: 1, to: 1, want: '1 day'),
  ];
  for (final r in ranges) {
    test('a length range reads naturally: ${r.name}', () {
      expect(HistoryViewModel.rangeText(r.from, r.to), r.want);
    });
  }
}

void chartSpanTests() {
  DateTime june(int d) => DateTime(2026, 6, d);

  test('every period becomes a span of its known days', () {
    final spans = chartSpansFor([
      PeriodEvent(startDate: june(1), endDate: june(4)),
      PeriodEvent(startDate: june(29)),
    ]);
    expect(spans, [
      ChartSpan(start: june(1), end: june(4)),
      ChartSpan(start: june(29), end: june(29)),
    ]);
  });

  test('the luteal span runs from after ovulation to before the period', () {
    const none = CyclePrediction(
      method: PredictionMethod.cycleAverage,
      confidence: PredictionConfidence.low,
      predictedNextPeriod: null,
    );
    expect(lutealSpanFor(none), isNull);
    final shift = CyclePrediction(
      method: PredictionMethod.temperatureShift,
      confidence: PredictionConfidence.medium,
      estimatedOvulation: june(14),
      predictedNextPeriod: june(28),
    );
    expect(lutealSpanFor(shift), ChartSpan(start: june(15), end: june(27)));
  });

  test('a reading can be added for a past day, within reason', () async {
    final repo = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await repo.load();
    final vm = HistoryViewModel(repo, now: () => DateTime(2026, 6, 10));
    expect(await vm.addReading(DateTime(2026, 6, 8), 36.5), isTrue);
    expect(repo.data.readings.single.date, DateTime(2026, 6, 8));
    expect(await vm.addReading(DateTime(2026, 6, 9), 30), isFalse);
    expect(await vm.addReading(DateTime(2026, 6, 11), 36.5), isFalse);
    expect(repo.data.readings, hasLength(1));
  });
}

void groupingTests() {
  DateTime june(int d) => DateTime(2026, 6, d);

  test(
    'days and readings are grouped into their cycle, newest first',
    () async {
      final repo = HealthRepository(
        FakePodService(),
        protection: DataProtection.plain,
      );
      await repo.load();
      await repo.apply(
        (d) => d
            .withReading(TemperatureReading(date: june(2), celsius: 36.2))
            .withReading(TemperatureReading(date: june(12), celsius: 36.5))
            .withReading(TemperatureReading(date: june(20), celsius: 36.7))
            .withDailyLog(DailyLog(date: june(11), painLevel: 2))
            .withDailyLog(DailyLog(date: june(21), painLevel: 4))
            .withPeriod(PeriodEvent(startDate: june(10)))
            .withPeriod(PeriodEvent(startDate: june(20))),
      );
      final vm = HistoryViewModel(repo, now: () => june(25));
      final cycles = vm.cycles;
      expect(cycles.map((c) => c.start), [june(20), june(10)]);
      expect(cycles[0].readings.map((r) => r.date), [june(20)]);
      expect(cycles[0].days.map((l) => l.date), [june(21)]);
      expect(cycles[1].readings.map((r) => r.date), [june(12)]);
      expect(cycles[1].days.map((l) => l.date), [june(11)]);
      expect(vm.readingsBeforeFirstPeriod.map((r) => r.date), [june(2)]);
      expect(vm.daysBeforeFirstPeriod, isEmpty);
    },
  );

  test('with no period everything is "before the first period"', () async {
    final repo = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await repo.load();
    await repo.apply(
      (d) => d.withReading(TemperatureReading(date: june(2), celsius: 36.2)),
    );
    final vm = HistoryViewModel(repo, now: () => june(25));
    expect(vm.cycles, isEmpty);
    expect(vm.readingsBeforeFirstPeriod, hasLength(1));
  });
}

void nightTests() {
  test('nights are charted relative to their own mean', () {
    final nights = nightsRelativeToMean([
      WearableNight(date: DateTime(2026, 6, 1), celsius: 33.1),
      WearableNight(date: DateTime(2026, 6, 2), celsius: 33.5),
      WearableNight(date: DateTime(2026, 6, 3), celsius: 33.3),
    ]);
    expect(nights.map((n) => n.celsius), [-0.2, 0.2, 0]);
    expect(nightsRelativeToMean(const []), isEmpty);
  });
}
