import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/reminders/reminders_screen.dart';
import 'package:lilith/ui/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_notification_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late FakeSettingsStore store;
  late PageSettingsRepository pageSettings;

  setUp(() async {
    store = FakeSettingsStore();
    pageSettings = PageSettingsRepository(store);
    await pageSettings.load();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(FakePodSessionService(), store),
        pageSettings: pageSettings,
        reminders: ReminderRepository(store, FakeNotificationService()),
        child: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a switch per card, all on by default, accessibly', (
    tester,
  ) async {
    await pump(tester);
    for (final key in [
      SettingsKeys.showFact,
      SettingsKeys.showForecast,
      SettingsKeys.showCalendar,
      SettingsKeys.showTemperatureChart,
    ]) {
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
    }
    await expectAccessible(tester);
  });

  testWidgets('turning a switch off is saved on the device', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(SettingsKeys.showCalendar));
    await tester.pumpAndSettle();
    expect(pageSettings.settings.showCalendar, isFalse);
    expect((await store.readPageSettings()).showCalendar, isFalse);
    expect((await store.readPageSettings()).showFact, isTrue);
  });

  testWidgets('Reminders opens from Settings', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(SettingsKeys.reminders));
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsOneWidget);
  });
}
