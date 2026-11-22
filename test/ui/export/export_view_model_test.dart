import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/export/export_view_model.dart';

import '../../fakes/fake_file_sharer.dart';
import '../../fakes/fake_pod_service.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9);
  late HealthRepository repo;
  late RecordingFileSharer sharer;
  late ExportViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    sharer = RecordingFileSharer();
    vm = ExportViewModel(repo, now: () => today, share: sharer.call);
  });

  Future<void> logSome() async {
    await repo.apply(
      (d) => d
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 24)))
          .withPeriod(PeriodEvent(startDate: DateTime(2025, 11, 2)))
          .withReading(
            TemperatureReading(date: DateTime(2026, 6, 1), celsius: 36.4),
          ),
    );
  }

  test('starts on six months with nothing to export', () {
    expect(vm.range, ExportRange.sixMonths);
    expect(vm.dayCount, 0);
    expect(vm.canExport, isFalse);
    expect(vm.isBusy, isFalse);
    expect(vm.error, isNull);
  });

  test('the range changes what is counted', () async {
    await logSome();
    expect(vm.dayCount, 2);
    vm.setRange(ExportRange.all);
    expect(vm.range, ExportRange.all);
    expect(vm.dayCount, 3);
    expect(vm.canExport, isTrue);
  });

  test('sharing as CSV hands over a CSV of the range', () async {
    await logSome();
    await vm.share(ExportFormat.csv);
    final file = sharer.shared.single;
    expect(file.mimeType, 'text/csv');
    expect(file.name, endsWith('2026-06-10.csv'));
    expect(String.fromCharCodes(file.bytes).split('\r\n').length, 4);
    expect(vm.isBusy, isFalse);
    expect(vm.lastShared, ExportFormat.csv);
  });

  test('sharing as PDF hands over a PDF', () async {
    await logSome();
    await vm.share(ExportFormat.pdf);
    final file = sharer.shared.single;
    expect(file.mimeType, 'application/pdf');
    expect(String.fromCharCodes(file.bytes.take(5)), '%PDF-');
    expect(vm.lastShared, ExportFormat.pdf);
  });

  test('is busy while a share is in flight and only one runs', () async {
    await logSome();
    sharer.hold = true;
    final first = vm.share(ExportFormat.csv);
    expect(vm.isBusy, isTrue);
    expect(vm.busyWith, ExportFormat.csv);
    await vm.share(ExportFormat.pdf);
    expect(sharer.shared, hasLength(1));
    sharer.release();
    await first;
    expect(vm.isBusy, isFalse);
  });

  test('nothing to export shares nothing', () async {
    await vm.share(ExportFormat.csv);
    expect(sharer.shared, isEmpty);
    expect(vm.lastShared, isNull);
  });

  test('a share that fails is reported and can be dismissed', () async {
    await logSome();
    sharer.failWith = Exception('no share target');
    await vm.share(ExportFormat.pdf);
    expect(vm.error, ExportError.shareFailed);
    expect(vm.lastShared, isNull);
    expect(vm.isBusy, isFalse);
    vm.clearError();
    expect(vm.error, isNull);
  });

  test('a new share clears the old error', () async {
    await logSome();
    sharer.failWith = Exception('x');
    await vm.share(ExportFormat.csv);
    sharer.failWith = null;
    await vm.share(ExportFormat.csv);
    expect(vm.error, isNull);
    expect(vm.lastShared, ExportFormat.csv);
  });

  test('notifies on range, busy and outcome changes', () async {
    await logSome();
    var notified = 0;
    vm.addListener(() => notified++);
    vm.setRange(ExportRange.all);
    await vm.share(ExportFormat.csv);
    expect(notified, greaterThanOrEqualTo(3));
  });
}
