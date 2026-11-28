import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/csv_export.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/log/log_summary.dart';

/// A person's own tags in the one-line summary, the CSV, the PDF and what
/// a share carries.
void main() {
  final day = DateTime(2026, 6, 2);
  final today = DateTime(2026, 6, 10);
  final log = DailyLog(
    date: day,
    painLevel: 2,
    signs: BodySigns(
      moods: const {Mood.calm},
      tags: const ['travel', 'Night shift'],
    ),
  );
  const csv = CsvExport();

  test('the summary History shows says the tags last', () {
    expect(logSummary(log), 'pain 2/10, calm, Night shift, travel');
    expect(
      logSummary(
        DailyLog(
          date: day,
          signs: BodySigns(tags: const ['yoga']),
        ),
      ),
      'yoga',
    );
  });

  group('CSV', () {
    test('has a tags column, after the columns it already had', () {
      expect(CsvExport.header.last, 'tags');
      expect(CsvExport.header.indexOf('pregnancy_test'), 20);
      expect(CsvExport.header, hasLength(22));
    });

    test('writes the tags as written, joined like symptoms', () {
      final line = csv.text([ExportRow(date: day, log: log)]).split('\r\n')[1];
      expect(line, '2026-06-02,,,,,,2,,,,,,,,,calm,,,,,,Night shift; travel');
    });

    test('a day without tags leaves the column blank', () {
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

  test('the PDF day row lists the tags with the rest', () {
    expect(
      reportDayCells(ExportRow(date: day, log: log))[5],
      'Calm, Night shift, Travel',
    );
  });

  test('a share carries tags only with moods and body signs', () {
    final data = HealthData.empty.withDailyLog(log);
    String report({required bool include}) => csv.text(
      exportRows(
        sharedView(data, includeSigns: include),
        range: ExportRange.all,
        today: today,
      ),
    );
    expect(report(include: true), contains('Night shift; travel'));
    expect(report(include: false), isNot(contains('travel')));
  });
}
