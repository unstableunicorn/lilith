import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';

void main() {
  DateTime d(int day) => DateTime(2026, 6, day);
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 6, day, hour, minute);
  final dose = reportDayHeaders.indexOf('Dose');

  test('the day table has a dose column before the notes', () {
    expect(dose, reportDayHeaders.length - 2);
  });

  test('a day row gives the verdict and the time it was done', () {
    List<String> cells(DoseStatus status, DateTime? doneAt) => reportDayCells(
      ExportRow(
        date: d(4),
        log: doneAt == null
            ? null
            : DailyLog(date: d(4), contraceptionDoneAt: doneAt),
        dose: status,
        method: Contraception.combinedPill,
      ),
    );
    expect(
      [
        cells(DoseStatus.taken, at(4, 9, 5))[dose],
        cells(DoseStatus.late, at(4, 20))[dose],
        cells(DoseStatus.missed, null)[dose],
      ],
      ['taken 09:05', 'late 20:00', 'missed'],
    );
  });

  test('a day without a verdict leaves the dose blank', () {
    expect(reportDayCells(ExportRow(date: d(4)))[dose], isEmpty);
  });

  Map<String, String> summary(HealthData data) => Map.fromEntries(
    reportContent(
      data,
      range: ExportRange.all,
      today: at(7, 8),
    ).summary.map((s) => MapEntry(s.$1, s.$2)),
  );

  test('the summary counts the doses in the span', () {
    final data = HealthData(
      profile: HealthProfile(
        contraception: Contraception.combinedPill,
        contraceptionSchedule: ContraceptionSchedule(
          form: DoseForm.pill,
          start: d(3),
          daysOn: 21,
          daysOff: 0,
          windowHours: 3,
        ),
      ),
      dailyLogs: [
        DailyLog(date: d(3), contraceptionDoneAt: at(3, 9)),
        DailyLog(date: d(4), contraceptionDoneAt: at(4, 20)),
      ],
    );
    expect(
      summary(data)['Doses in this export'],
      '1 on time, 1 late, 2 missed',
    );
  });

  test('no dose summary without doses', () {
    expect(
      summary(HealthData.empty).containsKey('Doses in this export'),
      isFalse,
    );
  });
}
