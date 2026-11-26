import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/calendar.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/shared_phases.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);
  final today = june(17);

  List<TemperatureReading> flat(DateTime from, int count, double celsius) => [
    for (var i = 0; i < count; i++)
      TemperatureReading(
        date: DateTime(from.year, from.month, from.day + i),
        celsius: celsius,
      ),
  ];

  // A period from 1 June with flow, a temperature rise from 9 June, and a
  // day with symptoms, a note and a test: everything a phases copy must drop.
  final data = HealthData(
    periods: [
      PeriodEvent(
        startDate: DateTime(2026, 5, 4),
        endDate: DateTime(2026, 5, 8),
        flow: FlowIntensity.heavy,
      ),
      PeriodEvent(
        startDate: june(1),
        endDate: june(5),
        flow: FlowIntensity.medium,
        ended: true,
      ),
    ],
    readings: [...flat(june(1), 8, 36.30), ...flat(june(9), 8, 36.65)],
    dailyLogs: [
      DailyLog(
        date: june(10),
        symptoms: const {Symptom.cramps},
        note: 'private',
        ovulationTest: OvulationTest.positive,
      ),
    ],
  );

  CyclePrediction predict(HealthData d) => const CyclePredictor().predict(
    readings: d.readings,
    periods: d.periods,
    today: today,
    nights: d.wearableNights,
    usualCycleLength: d.profile.usualCycleLength,
    suppressShift: d.profile.usesHormonalContraception,
  );

  test('keeps the period days and the dates the sharer sees, nothing more', () {
    final p = sharedPhases(
      data,
      today: today,
      fertileWindowMode: FertileWindowMode.hidden,
    );
    final expected = predict(data);
    expect(expected.estimatedOvulation, isNotNull);
    expect(p.updatedOn, today);
    expect(p.periods, [
      PeriodEvent(
        startDate: DateTime(2026, 5, 4),
        endDate: DateTime(2026, 5, 8),
      ),
      PeriodEvent(startDate: june(1), endDate: june(5), ended: true),
    ]);
    expect(p.nextPeriod, expected.predictedNextPeriod);
    expect(p.ovulation, expected.estimatedOvulation);
    expect(p.fertileWindow, isNull);
    expect(p.toJson().keys.toSet(), {
      'kind',
      'updatedOn',
      'periods',
      'nextPeriod',
      'predictedDays',
      'ovulation',
      'fertileMode',
    });
  });

  test('the fertile window goes only when the sharer shows it', () {
    for (final mode in [
      FertileWindowMode.information,
      FertileWindowMode.conceiving,
    ]) {
      final p = sharedPhases(data, today: today, fertileWindowMode: mode);
      final w = fertileWindowFor(predict(data), data.dailyLogs)!;
      expect(p.fertileWindow, isNotNull);
      expect((p.fertileWindow!.start, p.fertileWindow!.end), (w.start, w.end));
      expect(p.fertileMode, mode);
    }
  });

  test('on hormonal contraception: no ovulation and no window', () {
    final hormonal = data.withProfile(
      HealthProfile(contraception: Contraception.combinedPill),
    );
    final p = sharedPhases(
      hormonal,
      today: today,
      fertileWindowMode: FertileWindowMode.information,
    );
    expect(p.ovulation, isNull);
    expect(p.fertileWindow, isNull);
    expect(p.periods, hasLength(2));
  });

  test('round-trips through JSON and is told apart from a health document', () {
    final p = sharedPhases(
      data,
      today: today,
      fertileWindowMode: FertileWindowMode.conceiving,
    );
    final json = p.toJson();
    expect(isPhasesJson(json), isTrue);
    expect(isPhasesJson(const {'version': 8, 'readings': <Object>[]}), isFalse);
    final back = SharedPhases.fromJson(json);
    expect(back, p);
    expect(back.fertileWindow!.start, p.fertileWindow!.start);
  });

  test('the cycle day counts from the last period start', () {
    final p = SharedPhases(
      updatedOn: june(10),
      periods: [PeriodEvent(startDate: june(1))],
    );
    expect(p.cycleDayOn(june(1)), 1);
    expect(p.cycleDayOn(june(20)), 20);
    expect(SharedPhases(updatedOn: june(10)).cycleDayOn(june(20)), isNull);
  });

  test('the month marks period, predicted period, ovulation and window', () {
    final p = SharedPhases(
      updatedOn: june(10),
      periods: [PeriodEvent(startDate: june(1), endDate: june(3))],
      nextPeriod: june(28),
      predictedDays: 2,
      ovulation: june(14),
      fertileWindow: FertileWindow(
        start: june(10),
        end: june(15),
        basis: FertileWindowBasis.shift,
      ),
      fertileMode: FertileWindowMode.information,
    );
    final days = p.month(year: 2026, month: 6);
    expect(days, hasLength(30));
    Set<int> where(bool Function(CalendarDay d) f) => {
      for (final d in days)
        if (f(d)) d.date.day,
    };
    expect(where((d) => d.inPeriod), {1, 2, 3});
    expect(where((d) => d.predictedPeriod), {28, 29});
    expect(where((d) => d.ovulation), {14});
    expect(where((d) => d.fertile), {10, 11, 12, 13, 14, 15});
    expect(where((d) => d.logged || d.positiveTest), isEmpty);
  });
}
