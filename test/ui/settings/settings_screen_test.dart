import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/ui/reminders/reminders_screen.dart';
import 'package:lilith/ui/settings/security_key_screen.dart';
import 'package:lilith/ui/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_notification_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_pod_setup_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late FakeSettingsStore store;
  late PageSettingsRepository pageSettings;
  late SetupRepository setup;

  setUp(() async {
    store = FakeSettingsStore();
    pageSettings = PageSettingsRepository(store);
    await pageSettings.load();
    setup = SetupRepository(FakePodSetupService());
    await setup.inspect();
    await setup.chooseEncrypted('old key 1');
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(FakePodSessionService(), store),
        setup: setup,
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

  testWidgets('the fertile window switches start off and save when turned '
      'on', (tester) async {
    await pump(tester);
    for (final key in [
      SettingsKeys.tryingToConceive,
      SettingsKeys.showFertileWindow,
    ]) {
      await tester.scrollUntilVisible(find.byKey(key), 100);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }
    final saved = await store.readPageSettings();
    expect(saved.tryingToConceive, isTrue);
    expect(saved.showFertileWindow, isTrue);
  });

  testWidgets('Reminders opens from Settings', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(SettingsKeys.reminders));
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsOneWidget);
  });

  testWidgets('Security key opens from Settings on an encrypted pod', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(SettingsKeys.securityKey));
    await tester.pumpAndSettle();
    expect(find.byType(SecurityKeyScreen), findsOneWidget);
  });

  testWidgets('a plain pod has no security key to change', (tester) async {
    setup = SetupRepository(FakePodSetupService());
    await setup.inspect();
    await setup.choosePlain();
    await pump(tester);
    expect(find.byKey(SettingsKeys.securityKey), findsNothing);
  });
}
