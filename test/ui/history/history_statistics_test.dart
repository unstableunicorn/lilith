import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/cycle_statistics.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/history/history_screen.dart';
import 'package:lilith/ui/history/history_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 30);
  late HealthRepository health;
  late PageSettingsRepository pageSettings;
  late RecordingUrlOpener urls;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    pageSettings = PageSettingsRepository(FakeSettingsStore());
    await pageSettings.update(
      const PageSettings(showCalendar: false, showTemperatureChart: false),
    );
    urls = RecordingUrlOpener();
  });

  Future<void> logPeriods(List<(DateTime, DateTime)> spans) => health.apply(
    (data) => spans.fold(
      data,
      (d, s) => d.withPeriod(PeriodEvent(startDate: s.$1, endDate: s.$2)),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        health: health,
        pageSettings: pageSettings,
        openUrl: urls.call,
        child: HistoryScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with one finished cycle there is no statistics card', (
    tester,
  ) async {
    await logPeriods([
      (DateTime(2026, 5, 1), DateTime(2026, 5, 5)),
      (DateTime(2026, 5, 29), DateTime(2026, 6, 2)),
    ]);
    await pump(tester);
    expect(find.byKey(HistoryKeys.statistics), findsNothing);
  });

  testWidgets('with two cycles in the usual ranges it shows no flags', (
    tester,
  ) async {
    await logPeriods([
      (DateTime(2026, 4, 3), DateTime(2026, 4, 7)),
      (DateTime(2026, 5, 1), DateTime(2026, 5, 5)),
      (DateTime(2026, 5, 29), DateTime(2026, 6, 2)),
    ]);
    await pump(tester);
    expect(find.byKey(HistoryKeys.statistics), findsOneWidget);
    for (final f in StatisticFlag.values) {
      expect(find.byKey(HistoryKeys.statisticFlag(f)), findsNothing);
    }
    expect(find.byKey(HistoryKeys.statisticsSource), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('a long period and a long cycle are flagged with the source', (
    tester,
  ) async {
    await logPeriods([
      (DateTime(2026, 3, 20), DateTime(2026, 4, 14)),
      (DateTime(2026, 5, 1), DateTime(2026, 5, 5)),
      (DateTime(2026, 5, 29), DateTime(2026, 6, 2)),
    ]);
    await pump(tester);
    expect(
      find.byKey(HistoryKeys.statisticFlag(StatisticFlag.longPeriod)),
      findsOneWidget,
    );
    expect(
      find.byKey(HistoryKeys.statisticFlag(StatisticFlag.longCycle)),
      findsOneWidget,
    );
    expect(
      find.byKey(HistoryKeys.statisticFlag(StatisticFlag.shortCycle)),
      findsNothing,
    );
    await tester.tap(find.byKey(HistoryKeys.statisticsSource));
    expect(urls.opened, [Uri.parse(statisticsSource.url)]);
    await expectAccessible(tester);
  });
}
