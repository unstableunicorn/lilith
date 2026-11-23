// The user's days as a spreadsheet: one CSV line per logged day.

import 'dart:convert';

import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_file.dart';
import 'package:lilith/domain/export_rows.dart';

/// [value] as one CSV field: quoted when it holds a comma, quote or newline.
String csvField(String value) {
  if (!value.contains(RegExp(r'[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// "2026-06-10".
String isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// "36.4", "37.0": the same on every platform, unlike double.toString().
String formatCelsius(double celsius) {
  final text = celsius.toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

class CsvExport {
  const CsvExport();

  static const List<String> header = [
    'date',
    'temperature_c',
    'temperature_source',
    'period_start',
    'period_end',
    'flow',
    'pain_0_10',
    'symptoms',
  ];

  ExportFile build(List<ExportRow> rows, {required DateTime today}) =>
      ExportFile(
        name: 'lilith-export-${isoDay(today)}.csv',
        mimeType: 'text/csv',
        bytes: utf8.encode(text(rows)),
      );

  /// The whole file, RFC 4180 line ends, a header line first.
  String text(List<ExportRow> rows) {
    final lines = [header, for (final r in rows) _fields(r)];
    return lines.map((f) => '${f.map(csvField).join(',')}\r\n').join();
  }

  List<String> _fields(ExportRow row) {
    final log = row.log;
    return [
      isoDay(row.date),
      if (row.reading case final r?) ...[
        formatCelsius(r.celsius),
        r.source.name,
      ] else ...[
        '',
        '',
      ],
      if (row.periodStart) 'yes' else '',
      if (row.periodEnd) 'yes' else '',
      if (log == null || !log.flow.isBleeding) '' else log.flow.name,
      log?.painLevel?.toString() ?? '',
      if (log == null)
        ''
      else
        Symptom.values
            .where(log.symptoms.contains)
            .map((s) => s.name)
            .join('; '),
    ];
  }
}
