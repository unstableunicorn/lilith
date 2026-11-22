import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/export/export_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_file_sharer.dart';
import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10, 9);
  late HealthRepository health;
  late RecordingFileSharer sharer;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    sharer = RecordingFileSharer();
  });

  Future<void> logSome() => health.apply(
    (d) => d
        .withPeriod(PeriodEvent(startDate: DateTime(2025, 11, 2)))
        .withReading(
          TemperatureReading(date: DateTime(2026, 6, 1), celsius: 36.4),
        ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        health: health,
        shareFile: sharer.call,
        child: ExportScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<FilledButton>(find.byKey(key)).enabled;

  testWidgets('with nothing logged both buttons are off', (tester) async {
    await pump(tester);
    expect(find.byKey(ExportKeys.empty), findsOneWidget);
    expect(enabled(tester, ExportKeys.sharePdf), isFalse);
    expect(enabled(tester, ExportKeys.shareCsv), isFalse);
    for (final r in ExportRange.values) {
      expect(find.byKey(ExportKeys.range(r)), findsOneWidget);
    }
    await expectAccessible(tester);
  });

  testWidgets('the range changes the day count', (tester) async {
    await logSome();
    await pump(tester);
    expect(find.byKey(ExportKeys.empty), findsNothing);
    expect(find.byKey(ExportKeys.dayCount), findsOneWidget);
    expect(find.textContaining('1 day'), findsOneWidget);
    await tester.tap(find.byKey(ExportKeys.range(ExportRange.all)));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 days'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('sharing hands the file over and says so', (tester) async {
    await logSome();
    await pump(tester);
    await tester.tap(find.byKey(ExportKeys.shareCsv));
    await tester.pumpAndSettle();
    expect(sharer.shared.single.mimeType, 'text/csv');
    expect(find.byKey(ExportKeys.shared), findsOneWidget);
    await tester.tap(find.byKey(ExportKeys.sharePdf));
    await tester.pumpAndSettle();
    expect(sharer.shared.last.mimeType, 'application/pdf');
  });

  testWidgets('a failed share shows a notice that can be dismissed', (
    tester,
  ) async {
    await logSome();
    sharer.failWith = Exception('no target');
    await pump(tester);
    await tester.tap(find.byKey(ExportKeys.sharePdf));
    await tester.pumpAndSettle();
    expect(find.byKey(ExportKeys.error), findsOneWidget);
    expect(find.byKey(ExportKeys.shared), findsNothing);
    await expectAccessible(tester);
    await tester.tap(find.byKey(ExportKeys.dismissError));
    await tester.pumpAndSettle();
    expect(find.byKey(ExportKeys.error), findsNothing);
  });

  testWidgets('while sharing both buttons are off', (tester) async {
    await logSome();
    sharer.hold = true;
    await pump(tester);
    await tester.tap(find.byKey(ExportKeys.shareCsv));
    await tester.pump();
    expect(enabled(tester, ExportKeys.sharePdf), isFalse);
    expect(enabled(tester, ExportKeys.shareCsv), isFalse);
    sharer.release();
    await tester.pumpAndSettle();
    expect(enabled(tester, ExportKeys.shareCsv), isTrue);
  });
}
