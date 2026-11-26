import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';

void main() {
  DateTime d(int day) => DateTime(2026, 6, day);
  DateTime at(int day, int hour) => DateTime(2026, 6, day, hour);

  // A pill every day at 09:00, three hours' window, from 3 June.
  final pill = HealthProfile(
    contraception: Contraception.combinedPill,
    contraceptionSchedule: ContraceptionSchedule(
      form: DoseForm.pill,
      start: d(3),
      daysOn: 21,
      daysOff: 0,
      windowHours: 3,
    ),
  );

  List<ExportRow> rows(HealthData data, {DateTime? today}) =>
      exportRows(data, range: ExportRange.all, today: today ?? at(7, 8));

  test('each due day carries its verdict and the method', () {
    final r = rows(
      HealthData(
        profile: pill,
        dailyLogs: [
          DailyLog(date: d(3), contraceptionDoneAt: at(3, 9)),
          DailyLog(date: d(4), contraceptionDoneAt: at(4, 20)),
        ],
      ),
    );
    expect(r.map((x) => (x.date, x.dose, x.method)), [
      (d(3), DoseStatus.taken, Contraception.combinedPill),
      (d(4), DoseStatus.late, Contraception.combinedPill),
      (d(5), DoseStatus.missed, Contraception.combinedPill),
      (d(6), DoseStatus.missed, Contraception.combinedPill),
    ]);
  });

  test('missed days within the span only', () {
    final r = exportRows(
      HealthData(
        profile: pill.copyWith(
          contraceptionSchedule: pill.contraceptionSchedule!.copyWith(
            start: DateTime(2026, 1, 1),
          ),
        ),
      ),
      range: ExportRange.threeMonths,
      today: at(7, 8),
    );
    expect(r.isEmpty ? null : (r.first.date, r.last.date, r.length), (
      DateTime(2026, 3, 7),
      d(6),
      92,
    ));
  });

  test('rows without a verdict carry no dose or method', () {
    final r = rows(
      HealthData(
        profile: pill,
        dailyLogs: [DailyLog(date: d(1), flow: FlowIntensity.light)],
      ),
      today: at(3, 8),
    );
    expect(r.single.dose, isNull);
    expect(r.single.method, isNull);
  });

  test('a dose done without a schedule is taken', () {
    final r = rows(
      HealthData(
        profile: HealthProfile(contraception: Contraception.patchOrRing),
        dailyLogs: [DailyLog(date: d(1), contraceptionDoneAt: at(1, 9))],
      ),
    );
    expect(r.single.dose, DoseStatus.taken);
    expect(r.single.method, Contraception.patchOrRing);
  });
}
