import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/calendar.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);

  final data = HealthData.empty
      .withPeriod(PeriodEvent(startDate: june(3), endDate: june(6)))
      .withDailyLog(DailyLog(date: june(10), painLevel: 2))
      .withReading(TemperatureReading(date: june(12), celsius: 36.4));

  final prediction = CyclePrediction(
    method: PredictionMethod.cycleAverage,
    confidence: PredictionConfidence.medium,
    predictedNextPeriod: june(30),
    estimatedOvulation: june(16),
    averagePeriodLength: 4,
  );

  group('calendarMonth', () {
    test('has one entry per day of the month, in order', () {
      final days = calendarMonth(data, prediction, year: 2026, month: 6);
      expect(days, hasLength(30));
      expect(days.first.date, june(1));
      expect(days.last.date, june(30));
    });

    test('marks the known period days and nothing else as period', () {
      final days = calendarMonth(data, prediction, year: 2026, month: 6);
      final period = [
        for (final d in days)
          if (d.inPeriod) d.date.day,
      ];
      expect(period, [3, 4, 5, 6]);
    });

    test('marks the predicted period for the average period length', () {
      final days = calendarMonth(data, prediction, year: 2026, month: 6);
      expect(days[29].predictedPeriod, isTrue);
      final july = calendarMonth(data, prediction, year: 2026, month: 7);
      final predicted = [
        for (final d in july)
          if (d.predictedPeriod) d.date.day,
      ];
      expect(predicted, [1, 2, 3]);
    });

    test('a logged period day is never also predicted', () {
      final overlapping = data.withPeriod(PeriodEvent(startDate: june(30)));
      final days = calendarMonth(overlapping, prediction, year: 2026, month: 6);
      expect(days[29].inPeriod, isTrue);
      expect(days[29].predictedPeriod, isFalse);
    });

    test('marks the estimated ovulation and the logged days', () {
      final days = calendarMonth(data, prediction, year: 2026, month: 6);
      expect(days[15].ovulation, isTrue);
      expect(
        [
          for (final d in days)
            if (d.logged) d.date.day,
        ],
        [10, 12],
      );
    });

    test('without a prediction only the logged facts show', () {
      final days = calendarMonth(data, null, year: 2026, month: 6);
      expect(days.any((d) => d.predictedPeriod), isFalse);
      expect(days.any((d) => d.ovulation), isFalse);
      expect(days[2].inPeriod, isTrue);
    });
  });

  test('leadingBlanks counts the weekdays before the 1st, Monday first', () {
    expect(leadingBlanks(year: 2026, month: 6), 0); // 1 June 2026 is a Monday
    expect(leadingBlanks(year: 2026, month: 7), 2); // 1 July is a Wednesday
    expect(leadingBlanks(year: 2026, month: 11), 6); // 1 November is a Sunday
  });
}
