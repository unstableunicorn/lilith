import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
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
        symptoms: {Symptom.cramps},
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
      expect(summary['Temperature readings in this export'], '17');
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
            conditions: {ReproductiveCondition.pcos},
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
          HealthProfile(conditions: {ReproductiveCondition.endometriosis}),
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

    test('the bundled font renders too', () async {
      final file = await const PdfReport(loadTheme: robotoTheme).build(
        reportContent(threeCycles(), range: ExportRange.all, today: today),
      );
      expect(latin1.decode(file.bytes), startsWith('%PDF-'));
    });
  });
}
