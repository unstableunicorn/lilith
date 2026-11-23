import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  final today = DateTime(2026, 6, 10, 14, 5);

  group('ExportRange.since', () {
    final cases = <(ExportRange, DateTime?)>[
      (ExportRange.threeMonths, DateTime(2026, 3, 10)),
      (ExportRange.sixMonths, DateTime(2025, 12, 10)),
      (ExportRange.year, DateTime(2025, 6, 10)),
      (ExportRange.all, null),
    ];
    for (final (range, expected) in cases) {
      test(range.name, () => expect(range.since(today), expected));
    }
  });

  group('exportRows', () {
    final data = HealthData(
      readings: [
        TemperatureReading(date: DateTime(2025, 11, 1), celsius: 36.2),
        TemperatureReading(date: DateTime(2026, 6, 1, 7), celsius: 36.4),
        TemperatureReading(
          date: DateTime(2026, 6, 3),
          celsius: 36.7,
          source: ReadingSource.ring,
        ),
      ],
      periods: [
        PeriodEvent(startDate: DateTime(2025, 11, 1)),
        PeriodEvent(startDate: DateTime(2026, 6, 1)),
      ],
      dailyLogs: [
        DailyLog(
          date: DateTime(2026, 6, 1),
          flow: FlowIntensity.medium,
          symptoms: const {Symptom.cramps},
          painLevel: 5,
        ),
        DailyLog(date: DateTime(2026, 6, 2), symptoms: const {Symptom.fatigue}),
      ],
    );

    test('merges everything for a day into one row, oldest first', () {
      final rows = exportRows(data, range: ExportRange.all, today: today);
      expect(rows.map((r) => r.date), [
        DateTime(2025, 11, 1),
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 2),
        DateTime(2026, 6, 3),
      ]);
      final june1 = rows[1];
      expect(june1.reading?.celsius, 36.4);
      expect(june1.periodStart, isTrue);
      expect(june1.log?.painLevel, 5);
      expect(rows[2].reading, isNull);
      expect(rows[2].periodStart, isFalse);
      expect(rows[3].log, isNull);
      expect(rows[3].reading?.source, ReadingSource.ring);
    });

    test('a range drops the days before it', () {
      final rows = exportRows(data, range: ExportRange.sixMonths, today: today);
      expect(rows.first.date, DateTime(2026, 6, 1));
      expect(rows.length, 3);
    });

    test('the first day of the range is included', () {
      final edge = HealthData(
        readings: [
          TemperatureReading(date: DateTime(2026, 3, 10), celsius: 36),
          TemperatureReading(date: DateTime(2026, 3, 9), celsius: 36),
        ],
      );
      final rows = exportRows(
        edge,
        range: ExportRange.threeMonths,
        today: today,
      );
      expect(rows.map((r) => r.date), [DateTime(2026, 3, 10)]);
    });

    test('no data gives no rows', () {
      expect(
        exportRows(HealthData.empty, range: ExportRange.all, today: today),
        isEmpty,
      );
    });

    test('rows are equal by value', () {
      expect(
        ExportRow(date: DateTime(2026, 6, 1, 9), periodStart: true),
        ExportRow(date: DateTime(2026, 6, 1), periodStart: true),
      );
      expect(
        ExportRow(date: DateTime(2026, 6, 1)),
        isNot(ExportRow(date: DateTime(2026, 6, 1), periodStart: true)),
      );
    });
  });
}
