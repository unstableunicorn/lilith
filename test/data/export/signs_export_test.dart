import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/csv_export.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/log/log_summary.dart';

/// Moods and body signs in the one-line summary, the CSV and the PDF.
void main() {
  final day = DateTime(2026, 6, 2);
  final today = DateTime(2026, 6, 10);
  final signs = BodySigns(
    moods: const {Mood.calm, Mood.happy},
    sleep: SleepQuality.poor,
    digestion: const {Digestion.gas, Digestion.constipation},
    skin: const {SkinSign.acne},
    discharge: Discharge.eggWhite,
    pregnancyTest: PregnancyTest.negative,
  );
  final log = DailyLog(
    date: day,
    symptoms: const {Symptom.cramps},
    painLevel: 2,
    ovulationTest: OvulationTest.positive,
    signs: signs,
  );
  const csv = CsvExport();

  group('logSummary', () {
    test('says the signs after everything else', () {
      expect(
        logSummary(log),
        'cramps, pain 2/10, ovulation test positive, happy, calm, sleep poor, '
        'constipation, gas, acne skin, discharge egg-white, '
        'pregnancy test negative',
      );
    });

    test('a day with only a mood is not "nothing logged"', () {
      expect(
        logSummary(
          DailyLog(
            date: day,
            signs: BodySigns(moods: const {Mood.sad}),
          ),
        ),
        'sad',
      );
    });
  });

  group('CSV', () {
    test('has a column per group, after the columns it already had', () {
      expect(CsvExport.header.sublist(15, 21), [
        'moods',
        'sleep',
        'digestion',
        'skin',
        'discharge',
        'pregnancy_test',
      ]);
      expect(CsvExport.header.indexOf('dose_done_at'), 14);
    });

    test('writes the stored names, several joined like symptoms', () {
      final line = csv.text([ExportRow(date: day, log: log)]).split('\r\n')[1];
      expect(
        line,
        '2026-06-02,,,,,,2,cramps,,,positive,,,,,'
        'happy; calm,poor,constipation; gas,acne,eggWhite,negative,',
      );
    });

    test('a day without signs leaves the columns blank', () {
      final line = csv
          .text([
            ExportRow(
              date: day,
              log: DailyLog(date: day, painLevel: 1),
            ),
          ])
          .split('\r\n')[1];
      expect(line, '2026-06-02,,,,,,1,,,,,,,,,,,,,,,');
    });
  });

  group('PDF day row', () {
    test('lists the signs with the symptoms', () {
      expect(
        reportDayCells(ExportRow(date: day, log: log))[5],
        'Cramps, Ovulation test positive, Happy, Calm, Sleep poor, '
        'Constipation, Gas, Acne skin, Discharge egg-white, '
        'Pregnancy test negative',
      );
    });

    test('a day with nothing but signs still has them', () {
      expect(
        reportDayCells(
          ExportRow(
            date: day,
            log: DailyLog(
              date: day,
              signs: BodySigns(sleep: SleepQuality.good),
            ),
          ),
        )[5],
        'Sleep good',
      );
    });
  });

  group('whose export', () {
    final data = HealthData.empty.withDailyLog(log);

    test('your own export holds everything, the pregnancy test too', () {
      final rows = exportRows(data, range: ExportRange.all, today: today);
      expect(csv.text(rows), contains('eggWhite,negative'));
    });

    test('a report for someone else holds no signs unless chosen, and never '
        'the pregnancy test', () {
      String report({required bool include}) => csv.text(
        exportRows(
          sharedView(data, includeSigns: include),
          range: ExportRange.all,
          today: today,
        ),
      );
      expect(report(include: false), isNot(contains('calm')));
      expect(report(include: true), contains('happy; calm'));
      expect(report(include: true), isNot(contains('negative')));
    });
  });
}
