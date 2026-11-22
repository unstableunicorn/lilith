// What the export screen decides: the span, how many days it holds, and the
// building and handing over of the PDF or CSV.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/export/csv_export.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/export_file.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/ui/core/file_sharer.dart';

enum ExportFormat { pdf, csv }

enum ExportError { shareFailed }

class ExportViewModel extends ChangeNotifier {
  ExportViewModel(
    this._repo, {
    required this.now,
    required this._share,
    this._pdf = const PdfReport(),
    this._csv = const CsvExport(),
  }) {
    _repo.addListener(notifyListeners);
  }

  final HealthRepository _repo;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final FileSharer _share;
  final PdfReport _pdf;
  final CsvExport _csv;

  ExportRange _range = ExportRange.sixMonths;
  ExportFormat? _busyWith;
  ExportFormat? _lastShared;
  ExportError? _error;

  DateTime get today => dateOnly(now());
  ExportRange get range => _range;

  /// Days with anything logged in [range].
  int get dayCount => _rows.length;
  bool get canExport => dayCount > 0;
  bool get isBusy => _busyWith != null;
  ExportFormat? get busyWith => _busyWith;

  /// The last format handed over successfully, for the screen to confirm.
  ExportFormat? get lastShared => _lastShared;
  ExportError? get error => _error;

  List<ExportRow> get _rows =>
      exportRows(_repo.data, range: _range, today: today);

  void setRange(ExportRange range) {
    if (range == _range) return;
    _range = range;
    notifyListeners();
  }

  /// Builds the file for [format] and hands it over. Does nothing while a
  /// share is in flight or when there is nothing to export.
  Future<void> share(ExportFormat format) async {
    if (isBusy || !canExport) return;
    _busyWith = format;
    _error = null;
    _lastShared = null;
    notifyListeners();
    try {
      await _share(await _build(format));
      _lastShared = format;
    } catch (_) {
      _error = ExportError.shareFailed;
    } finally {
      _busyWith = null;
      notifyListeners();
    }
  }

  Future<ExportFile> _build(ExportFormat format) => switch (format) {
    ExportFormat.csv => Future.value(_csv.build(_rows, today: today)),
    ExportFormat.pdf => _pdf.build(
      reportContent(_repo.data, range: _range, today: today),
    ),
  };

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
