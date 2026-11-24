import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/history/history_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  final today = DateTime(2026, 6, 30);
  DateTime may(int d) => DateTime(2026, 5, d);
  DateTime june(int d) => DateTime(2026, 6, d);
  late HealthRepository repo;
  late HistoryViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    await repo.apply(
      (data) => data
          .withPeriod(PeriodEvent(startDate: may(1), endDate: may(5)))
          .withPeriod(PeriodEvent(startDate: may(29), endDate: june(2)))
          .withDailyLog(
            DailyLog(
              date: may(2),
              flow: FlowIntensity.heavy,
              symptoms: const {Symptom.cramps},
              painLevel: 6,
            ),
          )
          .withDailyLog(
            DailyLog(
              date: may(15),
              symptoms: const {Symptom.headache},
              painLevel: 3,
            ),
          )
          .withDailyLog(
            DailyLog(
              date: may(30),
              flow: FlowIntensity.medium,
              symptoms: const {Symptom.cramps},
              painLevel: 7,
            ),
          )
          .withDailyLog(
            DailyLog(date: june(10), symptoms: const {Symptom.bloating}),
          )
          .withReading(TemperatureReading(date: june(12), celsius: 36.5)),
    );
    vm = HistoryViewModel(repo, now: () => today);
  });

  List<DateTime> shownDays() => [
    for (final c in vm.cycles) ...c.days.map((l) => l.date),
  ];

  group('expanding', () {
    test('only the newest cycle starts open', () {
      expect(vm.isExpanded(may(29)), isTrue);
      expect(vm.isExpanded(may(1)), isFalse);
      expect(vm.allExpanded, isFalse);
    });

    test('expand all and collapse all open and close every cycle', () {
      final before = vm.expansionVersion;
      vm.expandAll();
      expect(vm.isExpanded(may(1)), isTrue);
      expect(vm.allExpanded, isTrue);
      expect(vm.expansionVersion, isNot(before));
      vm.collapseAll();
      expect(vm.isExpanded(may(29)), isFalse);
      expect(vm.isExpanded(may(1)), isFalse);
    });

    test('one cycle opened by hand is remembered', () {
      vm.setExpanded(may(1), expanded: true);
      expect(vm.isExpanded(may(1)), isTrue);
      expect(vm.allExpanded, isTrue);
    });
  });

  group('filtering', () {
    final cases = [
      (
        name: 'search matches the day summary, any case',
        apply: (HistoryViewModel v) => v.setQuery('HEAD'),
        want: [may(15)],
      ),
      (
        name: 'search for a symptom word',
        apply: (HistoryViewModel v) => v.setQuery('cramps'),
        want: [may(30), may(2)],
      ),
      (
        name: 'bleeding days',
        apply: (HistoryViewModel v) => v.setBleedingOnly(on: true),
        want: [may(30), may(2)],
      ),
      (
        name: 'pain at or above 5',
        apply: (HistoryViewModel v) => v.setMinPain(5),
        want: [may(30), may(2)],
      ),
      (
        name: 'pain at or above 3',
        apply: (HistoryViewModel v) => v.setMinPain(3),
        want: [may(30), may(15), may(2)],
      ),
      (
        name: 'a symptom',
        apply: (HistoryViewModel v) => v.toggleSymptomFilter(Symptom.bloating),
        want: [june(10)],
      ),
      (
        name: 'either of two symptoms',
        apply: (HistoryViewModel v) => v
          ..toggleSymptomFilter(Symptom.bloating)
          ..toggleSymptomFilter(Symptom.headache),
        want: [june(10), may(15)],
      ),
      (
        name: 'bleeding and pain together',
        apply: (HistoryViewModel v) => v
          ..setBleedingOnly(on: true)
          ..setMinPain(7),
        want: [may(30)],
      ),
      (
        name: 'nothing matching',
        apply: (HistoryViewModel v) => v.setQuery('nausea'),
        want: <DateTime>[],
      ),
    ];
    for (final c in cases) {
      test(c.name, () {
        c.apply(vm);
        expect(vm.isFiltering, isTrue);
        expect(shownDays(), c.want);
        expect(vm.matchCount, c.want.length);
      });
    }

    test('only cycles with a match show, all open, with no readings', () {
      vm.setQuery('headache');
      expect(vm.cycles.map((c) => c.start), [may(1)]);
      expect(vm.isExpanded(may(1)), isTrue);
      expect(vm.cycles.single.readings, isEmpty);
    });

    test('clearing the filters shows everything again', () {
      vm
        ..setQuery('cramps')
        ..setBleedingOnly(on: true)
        ..setMinPain(5)
        ..toggleSymptomFilter(Symptom.cramps)
        ..clearFilters();
      expect(vm.isFiltering, isFalse);
      expect(shownDays(), [june(10), may(30), may(15), may(2)]);
      expect(vm.cycles.first.readings, hasLength(1));
    });

    test('a symptom picked twice is no longer a filter', () {
      vm
        ..toggleSymptomFilter(Symptom.cramps)
        ..toggleSymptomFilter(Symptom.cramps);
      expect(vm.isFiltering, isFalse);
    });
  });
}
