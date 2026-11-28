import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/csv_export.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';

void main() {
  const csv = CsvExport();
  final today = DateTime(2026, 6, 10);

  test('names the file by day and gives it the CSV type', () {
    final file = csv.build(const [], today: today);
    expect(file.name, 'lilith-export-2026-06-10.csv');
    expect(file.mimeType, 'text/csv');
  });

  test('a header only when there are no rows', () {
    expect(
      csv.text(const []),
      'date,temperature_c,temperature_source,period_start,period_end,flow,'
      'pain_0_10,'
      'symptoms,skin_temp_c,skin_temp_source,ovulation_test,notes,'
      'contraception,dose,dose_done_at,'
      'moods,sleep,digestion,skin,discharge,pregnancy_test,tags\r\n',
    );
  });

  test('a dose row gives the method, the verdict and when it was done', () {
    final lines = csv
        .text([
          ExportRow(
            date: DateTime(2026, 6, 4),
            log: DailyLog(
              date: DateTime(2026, 6, 4),
              contraceptionDoneAt: DateTime(2026, 6, 4, 20, 5),
            ),
            dose: DoseStatus.late,
            method: Contraception.combinedPill,
          ),
          ExportRow(
            date: DateTime(2026, 6, 5),
            dose: DoseStatus.missed,
            method: Contraception.combinedPill,
          ),
        ])
        .split('\r\n');
    expect(lines.sublist(1), [
      '2026-06-04,,,,,,,,,,,,combinedPill,late,2026-06-04T20:05,,,,,,,',
      '2026-06-05,,,,,,,,,,,,combinedPill,missed,,,,,,,,',
      '',
    ]);
  });

  test('one line per day with blanks for what was not logged', () {
    final rows = [
      ExportRow(
        date: DateTime(2026, 6, 1),
        reading: TemperatureReading(date: DateTime(2026, 6, 1), celsius: 36.4),
        periodStart: true,
        log: DailyLog(
          date: DateTime(2026, 6, 1),
          flow: FlowIntensity.medium,
          symptoms: const {Symptom.fatigue, Symptom.cramps},
          painLevel: 5,
          ovulationTest: OvulationTest.negative,
        ),
      ),
      ExportRow(
        date: DateTime(2026, 6, 2),
        log: DailyLog(
          date: DateTime(2026, 6, 2),
          painLevel: 2,
          note: 'Tired, "very"',
        ),
        night: WearableNight(date: DateTime(2026, 6, 2), celsius: 0.3),
      ),
      ExportRow(
        date: DateTime(2026, 6, 3),
        reading: TemperatureReading(
          date: DateTime(2026, 6, 3),
          celsius: 37,
          source: ReadingSource.ring,
        ),
      ),
    ];
    final lines = csv.text(rows).split('\r\n');
    const header =
        'date,temperature_c,temperature_source,period_start,period_end,flow,'
        'pain_0_10,'
        'symptoms,skin_temp_c,skin_temp_source,ovulation_test,notes,'
        'contraception,dose,dose_done_at,'
        'moods,sleep,digestion,skin,discharge,pregnancy_test,tags';
    const day1 =
        '2026-06-01,36.4,manual,yes,,medium,5,cramps; fatigue,,,negative,,,,';
    expect(lines, [
      header,
      '$day1,,,,,,,',
      '2026-06-02,,,,,,2,,0.30,watch,,"Tired, ""very""",,,,,,,,,,',
      '2026-06-03,37.0,ring,,,,,,,,,,,,,,,,,,,',
      '',
    ]);
  });

  test('the bytes are the UTF-8 text', () {
    final file = csv.build(const [], today: today);
    expect(utf8.decode(file.bytes), csv.text(const []));
  });

  group('quoting', () {
    final cases = <(String, String, String)>[
      ('plain', 'cramps', 'cramps'),
      ('comma', 'a,b', '"a,b"'),
      ('quote', 'say "hi"', '"say ""hi"""'),
      ('newline', 'two\nlines', '"two\nlines"'),
    ];
    for (final (name, input, expected) in cases) {
      test(name, () => expect(csvField(input), expected));
    }
  });
}
