// A report for a doctor: summary, profile, cycles, a temperature chart and
// every logged day. reportContent decides what it says; PdfReport draws it.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:lilith/data/export/csv_export.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/export_file.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One cycle: its first day and its length, null while it is current.
class CycleRow {
  const CycleRow({required this.start, this.length});

  final DateTime start;
  final int? length;
}

/// The readings as a chart: x is days since [firstDay], y is °C.
class ReportChart {
  const ReportChart({
    required this.firstDay,
    required this.points,
    required this.periodStartDays,
    required this.xTicks,
    required this.yTicks,
  });

  final DateTime firstDay;
  final List<(int, double)> points;

  /// x of each period start in the span.
  final List<int> periodStartDays;
  final List<int> xTicks;
  final List<double> yTicks;

  /// The date at [x], or nothing past the last reading.
  String xLabel(num x) =>
      x > points.last.$1 ? '' : isoDay(addDays(firstDay, x.toInt()));
}

/// Everything the report says, in order.
class ReportContent {
  const ReportContent({
    required this.generated,
    required this.rangeLabel,
    required this.summary,
    required this.profile,
    required this.cycles,
    required this.chart,
    required this.rows,
  });

  String get title => 'Lilith cycle report';

  /// The day it was made, ISO.
  final String generated;
  final String rangeLabel;
  final List<(String, String)> summary;

  /// Empty when nothing is recorded, and then no section is shown.
  final List<(String, String)> profile;
  final List<CycleRow> cycles;

  /// Null with fewer than two readings in the span.
  final ReportChart? chart;
  final List<ExportRow> rows;
}

/// What the report says for [data] over [range], as of [today].
ReportContent reportContent(
  HealthData data, {
  required ExportRange range,
  required DateTime today,
  CyclePredictor predictor = const CyclePredictor(),
}) {
  final rows = exportRows(data, range: range, today: today);
  final prediction = predictor.predict(
    readings: data.readings,
    periods: data.periods,
    today: today,
  );
  return ReportContent(
    generated: isoDay(dateOnly(today)),
    rangeLabel: range.label,
    summary: _summary(data, prediction, rows),
    profile: _profile(data.profile),
    cycles: _cycles(data, rows),
    chart: _chart(rows),
    rows: rows,
  );
}

List<(String, String)> _summary(
  HealthData data,
  CyclePrediction p,
  List<ExportRow> rows,
) {
  final average = p.averageCycleLength;
  final next = p.predictedNextPeriod;
  return [
    ('Period starts recorded', '${data.periods.length}'),
    (
      'Average cycle length',
      average == null
          ? 'Not enough cycles yet'
          : '${average.toStringAsFixed(1)} days over ${p.cycleCount} '
                '${p.cycleCount == 1 ? 'cycle' : 'cycles'}',
    ),
    if (p.lutealLength case final luteal?)
      ('Luteal phase', '$luteal days, from the temperature shift'),
    if (p.lastPeriodStart case final last?)
      ('Last period started', isoDay(last)),
    if (next != null)
      (
        'Predicted next period',
        '${isoDay(next)} (${switch (p.method) {
          PredictionMethod.temperatureShift => 'from the temperature shift',
          PredictionMethod.cycleAverage => 'from the average cycle length',
          PredictionMethod.insufficientData => 'no basis',
        }})',
      ),
    ('Days in this export', '${rows.length}'),
    (
      'Readings in this export',
      '${rows.where((r) => r.reading != null).length}',
    ),
  ];
}

List<(String, String)> _profile(HealthProfile profile) {
  if (profile.isEmpty) return const [];
  String list(Iterable<String> labels) =>
      labels.isEmpty ? 'None recorded' : labels.join(', ');
  return [
    (
      'Conditions',
      list(
        ReproductiveCondition.values
            .where(profile.conditions.contains)
            .map((c) => c.label),
      ),
    ),
    (
      'Treatments',
      list(
        FertilityTreatment.values
            .where(profile.treatments.contains)
            .map((t) => t.label),
      ),
    ),
    if (profile.notes.trim().isNotEmpty) ('Notes', profile.notes.trim()),
  ];
}

List<CycleRow> _cycles(HealthData data, List<ExportRow> rows) {
  final starts = data.periods.map((p) => p.startDate).toList();
  final inSpan = rows.where((r) => r.periodStart).map((r) => r.date).toSet();
  return [
    for (var i = 0; i < starts.length; i++)
      if (inSpan.contains(starts[i]))
        CycleRow(
          start: starts[i],
          length: i + 1 < starts.length
              ? daysBetween(starts[i], starts[i + 1])
              : null,
        ),
  ];
}

ReportChart? _chart(List<ExportRow> rows) {
  final readings = rows.where((r) => r.reading != null).toList();
  if (readings.length < 2) return null;
  final first = readings.first.date;
  final points = [
    for (final r in readings) (daysBetween(first, r.date), r.reading!.celsius),
  ];
  final temps = points.map((p) => p.$2);
  final low = (temps.reduce((a, b) => a < b ? a : b) * 2).floor() / 2;
  var high = (temps.reduce((a, b) => a > b ? a : b) * 2).ceil() / 2;
  if (high == low) high += 0.5;
  final span = points.last.$1;
  final step = [
    1,
    7,
    14,
    30,
    60,
    90,
    180,
  ].firstWhere((s) => span ~/ s <= 8, orElse: () => 365);
  return ReportChart(
    firstDay: first,
    points: points,
    periodStartDays: [
      for (final r in rows)
        if (r.periodStart && !r.date.isBefore(first))
          daysBetween(first, r.date),
    ],
    xTicks: [for (var x = 0; x <= span + step - 1; x += step) x],
    yTicks: [
      for (var t = low; t <= high + 0.001; t += 0.5) (t * 2).round() / 2,
    ],
  );
}

/// The PDF fonts the app ships, so every reading renders the same everywhere.
Future<pw.ThemeData> robotoTheme() async {
  Future<pw.Font> font(String file) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));
  return pw.ThemeData.withFont(
    base: await font('Roboto-Regular.ttf'),
    bold: await font('Roboto-Bold.ttf'),
    italic: await font('Roboto-Italic.ttf'),
  );
}

class PdfReport {
  const PdfReport({this.loadTheme, this.compress = true});

  /// The fonts to use; the PDF standard fonts when null.
  final Future<pw.ThemeData> Function()? loadTheme;

  /// Off only in tests, so the text can be read back from the bytes.
  final bool compress;

  Future<ExportFile> build(ReportContent content) async {
    final doc = pw.Document(
      title: content.title,
      compress: compress,
      theme: await loadTheme?.call(),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        maxPages: 200,
        build: (context) => [
          pw.Header(level: 0, text: content.title),
          pw.Text(
            'Generated ${content.generated}. Covers: ${content.rangeLabel}. '
            'Skin temperature, period starts and symptoms logged by the '
            "patient; the prediction is the app's, not a diagnosis.",
          ),
          pw.Header(level: 1, text: 'Summary'),
          _pairs(content.summary),
          if (content.profile.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Health profile'),
            _pairs(content.profile),
          ],
          if (content.cycles.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Cycles'),
            _table(
              ['Started', 'Length (days)'],
              [
                for (final c in content.cycles)
                  [isoDay(c.start), c.length?.toString() ?? 'current'],
              ],
            ),
          ],
          if (content.chart case final chart?) _chartWidget(chart),
          if (content.rows.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Logged days'),
            _table(
              ['Date', '°C', 'Period', 'Flow', 'Pain', 'Symptoms'],
              [for (final r in content.rows) _dayCells(r)],
            ),
          ],
        ],
      ),
    );
    return ExportFile(
      name: 'lilith-report-${content.generated}.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList(await doc.save()),
    );
  }

  pw.Widget _pairs(List<(String, String)> pairs) => pw.Table(
    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
    children: [
      for (final (label, value) in pairs)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                label,
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(value),
          ],
        ),
    ],
  );

  pw.Widget _table(List<String> headers, List<List<String>> data) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: const pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignment: pw.Alignment.centerLeft,
      );

  List<String> _dayCells(ExportRow r) {
    final log = r.log;
    return [
      isoDay(r.date),
      if (r.reading == null) '' else formatCelsius(r.reading!.celsius),
      if (r.periodStart) 'start' else '',
      if (log == null || !log.flow.isBleeding) '' else log.flow.name,
      log?.painLevel?.toString() ?? '',
      if (log == null)
        ''
      else
        Symptom.values
            .where(log.symptoms.contains)
            .map((s) => s.label)
            .join(', '),
    ];
  }

  // The heading is the chart's own title, so a page break never parts them.
  pw.Widget _chartWidget(ReportChart chart) => pw.SizedBox(
    height: 240,
    child: pw.Chart(
      title: pw.Header(level: 1, text: 'Temperature (°C)'),
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis<int>(
          chart.xTicks,
          format: chart.xLabel,
          textStyle: const pw.TextStyle(fontSize: 7),
          angle: 0.5,
          marginEnd: 10,
        ),
        yAxis: pw.FixedAxis<double>(
          chart.yTicks,
          format: (v) => v.toStringAsFixed(1),
          textStyle: const pw.TextStyle(fontSize: 8),
          divisions: true,
        ),
      ),
      datasets: [
        pw.LineDataSet(
          legend: 'Skin temperature',
          data: [
            for (final (x, y) in chart.points)
              pw.PointChartValue(x.toDouble(), y),
          ],
          color: PdfColors.purple,
          pointSize: 2,
          lineWidth: 1,
        ),
        if (chart.periodStartDays.isNotEmpty)
          pw.LineDataSet(
            legend: 'Period start',
            data: [
              for (final x in chart.periodStartDays)
                pw.PointChartValue(x.toDouble(), chart.yTicks.first),
            ],
            color: PdfColors.red,
            drawLine: false,
            pointSize: 4,
          ),
      ],
    ),
  );
}
