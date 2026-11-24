import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/period_linker.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);
  DailyLog flow(int d, FlowIntensity f) => DailyLog(date: june(d), flow: f);
  PeriodEvent period(int start, {int? end}) => PeriodEvent(
    startDate: june(start),
    endDate: end == null ? null : june(end),
  );

  group('a bleeding day', () {
    test('inside a period changes nothing', () {
      final logs = [flow(3, FlowIntensity.medium)];
      expect(linkPeriods([period(1, end: 5)], logs, june(3)), [
        period(1, end: 5),
      ]);
    });

    test('just after a period extends it', () {
      final logs = [flow(6, FlowIntensity.light)];
      expect(linkPeriods([period(1, end: 5)], logs, june(6)), [
        period(1, end: 6),
      ]);
      final gap = [flow(7, FlowIntensity.light)];
      expect(linkPeriods([period(1, end: 5)], gap, june(7)), [
        period(1, end: 7),
      ]);
    });

    test('just after a period marked ended reopens it', () {
      final ended = PeriodEvent(
        startDate: june(1),
        endDate: june(5),
        ended: true,
      );
      final logs = [flow(6, FlowIntensity.light)];
      expect(linkPeriods([ended], logs, june(6)), [period(1, end: 6)]);
    });

    test('just before a period moves its start back', () {
      final logs = [flow(9, FlowIntensity.heavy)];
      expect(linkPeriods([period(10, end: 14)], logs, june(9)), [
        period(9, end: 14),
      ]);
    });

    test('far from any period starts a new one-day period', () {
      final logs = [flow(20, FlowIntensity.medium)];
      expect(linkPeriods([period(1, end: 5)], logs, june(20)), [
        period(1, end: 5),
        period(20, end: 20),
      ]);
    });

    test('two runs five days apart are two periods', () {
      var periods = <PeriodEvent>[];
      final logs = [
        flow(1, FlowIntensity.medium),
        flow(2, FlowIntensity.medium),
        flow(7, FlowIntensity.medium),
      ];
      for (final d in [1, 2, 7]) {
        periods = linkPeriods(periods, logs, june(d));
      }
      expect(periods, [period(1, end: 2), period(7, end: 7)]);
    });

    test('spotting alone creates nothing and extends nothing', () {
      final logs = [
        flow(20, FlowIntensity.spotting),
        flow(6, FlowIntensity.spotting),
      ];
      expect(linkPeriods([], logs, june(20)), isEmpty);
      expect(linkPeriods([period(1, end: 5)], logs, june(6)), [
        period(1, end: 5),
      ]);
    });

    test('an open period is extended too', () {
      final logs = [flow(2, FlowIntensity.light)];
      expect(linkPeriods([period(1)], logs, june(2)), [period(1, end: 2)]);
    });
  });

  group('a dry day', () {
    test('on the end moves it back to the last bleeding day', () {
      final logs = [flow(3, FlowIntensity.medium), flow(5, FlowIntensity.none)];
      expect(linkPeriods([period(1, end: 5)], logs, june(5)), [
        period(1, end: 3),
      ]);
    });

    test('on the end with no bleeding logged keeps the start', () {
      final logs = [flow(5, FlowIntensity.none)];
      expect(linkPeriods([period(1, end: 5)], logs, june(5)), [
        period(1, end: 1),
      ]);
    });

    test('on a one-day period removes it', () {
      final logs = [flow(1, FlowIntensity.none)];
      expect(linkPeriods([period(1, end: 1)], logs, june(1)), isEmpty);
      expect(linkPeriods([period(1)], logs, june(1)), isEmpty);
    });

    test('on the start moves it on to the next bleeding day', () {
      final logs = [flow(1, FlowIntensity.none), flow(3, FlowIntensity.light)];
      expect(linkPeriods([period(1, end: 5)], logs, june(1)), [
        period(3, end: 5),
      ]);
      final none = [flow(1, FlowIntensity.none)];
      expect(linkPeriods([period(1, end: 5)], none, june(1)), [
        period(2, end: 5),
      ]);
    });

    test('strictly inside a period changes nothing', () {
      final logs = [flow(3, FlowIntensity.none)];
      expect(linkPeriods([period(1, end: 5)], logs, june(3)), [
        period(1, end: 5),
      ]);
    });

    test('outside every period changes nothing', () {
      expect(linkPeriods([period(1, end: 5)], [], june(20)), [
        period(1, end: 5),
      ]);
    });
  });

  test('is idempotent', () {
    final logs = [flow(6, FlowIntensity.light)];
    final once = linkPeriods([period(1, end: 5)], logs, june(6));
    expect(linkPeriods(once, logs, june(6)), once);
  });

  test('bleeds means light flow or more', () {
    expect(bleeds(null), isFalse);
    expect(bleeds(flow(1, FlowIntensity.none)), isFalse);
    expect(bleeds(flow(1, FlowIntensity.spotting)), isFalse);
    expect(bleeds(flow(1, FlowIntensity.light)), isTrue);
    expect(bleeds(flow(1, FlowIntensity.heavy)), isTrue);
  });
}
