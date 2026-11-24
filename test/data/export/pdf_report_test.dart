import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  periodLengthRowTests();
  fertileWindowReportTests();
  dayCellTests();
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime(2026, 6, 10, 8);
  HealthData threeCycles() {
    var data = HealthData.empty;
    for (final start in [
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 29),
      DateTime(2026, 4, 26),
      DateTime(2026, 5, 24),
    ]) {
      data = data.withPeriod(PeriodEvent(startDate: start));
    }
    for (var i = 0; i < 17; i++) {
      final day = DateTime(2026, 5, 24 + i);
      data = data.withReading(
        TemperatureReading(date: day, celsius: i < 12 ? 36.3 : 36.7),
      );
    }
    return data.withDailyLog(
      DailyLog(
        date: DateTime(2026, 5, 24),
        flow: FlowIntensity.heavy,
        symptoms: const {Symptom.cramps},
        painLevel: 7,
      ),
    );
  }

  group('reportContent', () {
    test('says when and over what span it was made', () {
      final c = reportContent(
        HealthData.empty,
        range: ExportRange.sixMonths,
        today: today,
      );
      expect(c.generated, '2026-06-10');
      expect(c.rangeLabel, ExportRange.sixMonths.label);
      expect(c.rows, isEmpty);
      expect(c.cycles, isEmpty);
      expect(c.chart, isNull);
      expect(c.profile, isEmpty);
    });

    test('summarises the cycle history and the prediction', () {
      final c = reportContent(
        threeCycles(),
        range: ExportRange.all,
        today: today,
      );
      final summary = Map.fromEntries(
        c.summary.map((s) => MapEntry(s.$1, s.$2)),
      );
      expect(summary['Period starts recorded'], '4');
      expect(summary['Average cycle length'], '28.0 days over 3 cycles');
      expect(summary['Last period started'], '2026-05-24');
      expect(summary['Predicted next period'], contains('2026-06-'));
      expect(summary['Days in this export'], '20');
      expect(summary['Readings in this export'], '17');
    });

    test(
      'lists the cycles in the span, oldest first, the current one open',
      () {
        final c = reportContent(
          threeCycles(),
          range: ExportRange.all,
          today: today,
        );
        expect(c.cycles.map((r) => (r.start, r.length)), [
          (DateTime(2026, 3, 1), 28),
          (DateTime(2026, 3, 29), 28),
          (DateTime(2026, 4, 26), 28),
          (DateTime(2026, 5, 24), null),
        ]);
      },
    );

    test('the profile appears only when something is recorded', () {
      final c = reportContent(
        HealthData.empty.withProfile(
          HealthProfile(
            conditions: const {ReproductiveCondition.pcos},
            notes: 'Iron tablets',
          ),
        ),
        range: ExportRange.all,
        today: today,
      );
      expect(c.profile.map((p) => p.$1), ['Conditions', 'Treatments', 'Notes']);
      expect(c.profile[0].$2, ReproductiveCondition.pcos.label);
      expect(c.profile[1].$2, 'None recorded');
      expect(c.profile[2].$2, 'Iron tablets');
    });

    test('charts the readings against days with period starts marked', () {
      final c = reportContent(
        threeCycles(),
        range: ExportRange.all,
        today: today,
      );
      final chart = c.chart!;
      expect(chart.firstDay, DateTime(2026, 5, 24));
      expect(chart.points.first, (0, 36.3));
      expect(chart.points.last, (16, 36.7));
      expect(chart.periodStartDays, [0]);
      expect(chart.yTicks, [36.0, 36.5, 37.0]);
      expect(chart.xTicks.first, 0);
      expect(chart.xTicks.last, greaterThanOrEqualTo(16));
      expect(chart.xTicks.length, lessThanOrEqualTo(9));
      expect(chart.xLabel(0), '2026-05-24');
      expect(chart.xLabel(16), '2026-06-09');
      expect(chart.xLabel(17), '');
    });

    test('identical readings still get a two-tick y axis', () {
      final c = reportContent(
        HealthData.empty.withReadings([
          TemperatureReading(date: DateTime(2026, 6, 1), celsius: 36.5),
          TemperatureReading(date: DateTime(2026, 6, 2), celsius: 36.5),
        ]),
        range: ExportRange.all,
        today: today,
      );
      expect(c.chart!.yTicks, [36.5, 37.0]);
    });

    test('a single reading draws no chart', () {
      final c = reportContent(
        HealthData.empty.withReading(
          TemperatureReading(date: today, celsius: 36.5),
        ),
        range: ExportRange.all,
        today: today,
      );
      expect(c.chart, isNull);
    });

    test('a year of readings keeps the axis to a handful of labels', () {
      var data = HealthData.empty;
      for (var i = 0; i < 365; i++) {
        data = data.withReading(
          TemperatureReading(date: DateTime(2025, 6, 10 + i), celsius: 36.5),
        );
      }
      final c = reportContent(data, range: ExportRange.all, today: today);
      expect(c.chart!.xTicks.length, inInclusiveRange(4, 9));
    });
  });

  group('PdfReport', () {
    test('renders a PDF that carries the report text', () async {
      final content = reportContent(
        threeCycles().withProfile(
          HealthProfile(
            conditions: const {ReproductiveCondition.endometriosis},
          ),
        ),
        range: ExportRange.all,
        today: today,
      );
      final file = await const PdfReport(compress: false).build(content);
      expect(file.name, 'lilith-report-2026-06-10.pdf');
      expect(file.mimeType, 'application/pdf');
      final text = latin1.decode(file.bytes);
      expect(text, startsWith('%PDF-'));
      expect(text, contains(content.title));
      expect(text, contains('Endometriosis'));
      expect(text, contains('2026-05-24'));
    });

    test('an empty export still renders', () async {
      final file = await const PdfReport().build(
        reportContent(HealthData.empty, range: ExportRange.all, today: today),
      );
      expect(latin1.decode(file.bytes), startsWith('%PDF-'));
    });

    test('many logged days run over several pages', () async {
      var data = HealthData.empty;
      for (var i = 0; i < 200; i++) {
        final day = DateTime(2025, 11, 1 + i);
        data = data
            .withReading(TemperatureReading(date: day, celsius: 36.5))
            .withDailyLog(
              DailyLog(
                date: day,
                flow: FlowIntensity.light,
                symptoms: const {Symptom.cramps, Symptom.headache},
                painLevel: 3,
              ),
            );
      }
      final file = await const PdfReport(compress: false)
          .build(reportContent(data, range: ExportRange.all, today: today));
      final pages = RegExp(r'/Type/Page\b')
          .allMatches(latin1.decode(file.bytes));
      expect(pages.length, greaterThan(2));
    });

    test('the bundled font renders too', () async {
      final file = await const PdfReport(loadTheme: robotoTheme).build(
        reportContent(threeCycles(), range: ExportRange.all, today: today),
      );
      expect(latin1.decode(file.bytes), startsWith('%PDF-'));
    });
  });
}

void periodLengthRowTests() {
  test('reportContent gives the average period length when ends are known', () {
    final data = HealthData.empty
        .withPeriod(
          PeriodEvent(
            startDate: DateTime(2026, 4, 1),
            endDate: DateTime(2026, 4, 5),
          ),
        )
        .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 29)));
    final content = reportContent(
      data,
      range: ExportRange.all,
      today: DateTime(2026, 6, 10),
    );
    final summary = Map.fromEntries(
      content.summary.map((s) => MapEntry(s.$1, s.$2)),
    );
    expect(summary['Average period length'], '5.0 days over 1 period');
    final cycles = content.cycles;
    expect(cycles.first.periodLength, 5);
    expect(cycles.last.periodLength, isNull);
  });

  test('reportContent has no period length row without known ends', () {
    final content = reportContent(
      HealthData.empty.withPeriod(PeriodEvent(startDate: DateTime(2026, 6, 1))),
      range: ExportRange.all,
      today: DateTime(2026, 6, 10),
    );
    final summary = Map.fromEntries(
      content.summary.map((s) => MapEntry(s.$1, s.$2)),
    );
    expect(summary.containsKey('Average period length'), isFalse);
  });
}

void dayCellTests() {
  test('a day row carries the symptoms, the ovulation test and the note', () {
    final cells = reportDayCells(
      ExportRow(
        date: DateTime(2026, 6, 2),
        log: DailyLog(
          date: DateTime(2026, 6, 2),
          symptoms: const {Symptom.cramps},
          ovulationTest: OvulationTest.positive,
          note: 'Flew to Perth',
        ),
      ),
    );
    expect(cells, hasLength(reportDayHeaders.length));
    expect(cells[5], 'Cramps, Ovulation test positive');
    expect(cells.last, 'Flew to Perth');
  });

  test('a day with only a reading leaves the note blank', () {
    final cells = reportDayCells(
      ExportRow(
        date: DateTime(2026, 6, 2),
        reading: TemperatureReading(date: DateTime(2026, 6, 2), celsius: 36.4),
      ),
    );
    expect(cells, hasLength(reportDayHeaders.length));
    expect(cells.last, isEmpty);
  });
}

void fertileWindowReportTests() {
  final today = DateTime(2026, 6, 17);
  DateTime june(int d) => DateTime(2026, 6, d);
  final period = HealthData.empty.withPeriod(
    PeriodEvent(startDate: june(1), endDate: june(5)),
  );
  final shifted = period.withReadings([
    for (var i = 1; i <= 16; i++)
      TemperatureReading(date: june(i), celsius: i <= 8 ? 36.3 : 36.65),
  ]);
  final tested = period.withDailyLog(
    DailyLog(date: june(12), ovulationTest: OvulationTest.positive),
  );
  Map<String, String> summaryOf(ReportContent c) =>
      Map.fromEntries(c.summary.map((s) => MapEntry(s.$1, s.$2)));

  final cases = [
    (
      name: 'an estimate alone carries the estimate sentence',
      data: shifted,
      mode: FertileWindowMode.hidden,
      ovulation: true,
      window: false,
      disclaimer: estimateDisclaimer,
    ),
    (
      name: 'a window shown as information carries both sentences',
      data: tested,
      mode: FertileWindowMode.information,
      ovulation: false,
      window: true,
      disclaimer: fertileWindowDisclaimer(FertileWindowMode.information),
    ),
    (
      name: 'a window when conceiving carries the estimate sentence only',
      data: shifted,
      mode: FertileWindowMode.conceiving,
      ovulation: true,
      window: true,
      disclaimer: fertileWindowDisclaimer(FertileWindowMode.conceiving),
    ),
    (
      name: 'a hidden window leaves a positive test out',
      data: tested,
      mode: FertileWindowMode.hidden,
      ovulation: false,
      window: false,
      disclaimer: null,
    ),
  ];
  for (final c in cases) {
    test('reportContent: ${c.name}', () {
      final content = reportContent(
        c.data,
        range: ExportRange.all,
        today: today,
        fertileWindowMode: c.mode,
      );
      final summary = summaryOf(content);
      expect(summary.containsKey('Estimated ovulation'), c.ovulation);
      expect(summary.containsKey('Likely fertile'), c.window);
      expect(content.disclaimer, c.disclaimer);
    });
  }
}
