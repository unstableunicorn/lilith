import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/reminders/reminders_screen.dart';
import 'package:lilith/ui/settings/security_key_screen.dart';
import 'package:lilith/ui/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_notification_service.dart';
import '../../fakes/fake_pod_service.dart';
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

  Future<void> pump(WidgetTester tester, {HealthRepository? health}) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(FakePodSessionService(), store),
        setup: setup,
        health: health,
        pageSettings: pageSettings,
        reminders: ReminderRepository(store, FakeNotificationService()),
        child: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('how you use Lilith', () {
    late HealthRepository health;

    setUp(() async {
      health = HealthRepository(
        FakePodService(),
        protection: DataProtection.plain,
      );
      await health.load();
    });

    bool chosen(WidgetTester tester, AppMode mode) =>
        tester
            .widget<RadioGroup<AppMode>>(find.byType(RadioGroup<AppMode>))
            .groupValue ==
        mode;

    testWidgets('offers the three ways, a tracker until changed', (
      tester,
    ) async {
      await pump(tester, health: health);
      for (final mode in AppMode.values) {
        expect(find.byKey(SettingsKeys.mode(mode)), findsOneWidget);
      }
      expect(chosen(tester, AppMode.tracker), isTrue);
      await expectAccessible(tester);
    });

    testWidgets('choosing one is saved to the pod', (tester) async {
      await pump(tester, health: health);
      await tester.tap(find.byKey(SettingsKeys.mode(AppMode.both)));
      await tester.pumpAndSettle();
      expect(health.data.mode, AppMode.both);
      expect(chosen(tester, AppMode.both), isTrue);
    });

    testWidgets('a partner sees no settings for tracker screens', (
      tester,
    ) async {
      await health.apply((d) => d.withMode(AppMode.partner));
      await pump(tester, health: health);
      expect(chosen(tester, AppMode.partner), isTrue);
      for (final key in [
        SettingsKeys.reminders,
        SettingsKeys.showFact,
        SettingsKeys.showForecast,
        SettingsKeys.showCalendar,
        SettingsKeys.showTemperatureChart,
        SettingsKeys.tryingToConceive,
        SettingsKeys.showFertileWindow,
      ]) {
        expect(find.byKey(key), findsNothing);
      }
      expect(find.byKey(SettingsKeys.securityKey), findsOneWidget);
      await expectAccessible(tester);
    });

    testWidgets('without the data there is no choice to make', (tester) async {
      await pump(tester);
      expect(find.byKey(SettingsKeys.mode(AppMode.tracker)), findsNothing);
      expect(find.byKey(SettingsKeys.reminders), findsOneWidget);
    });

    bool on(WidgetTester tester, LogGroup g) => tester
        .widget<SwitchListTile>(find.byKey(SettingsKeys.logGroup(g)))
        .value;

    testWidgets('Log shows: a switch per group, moods and tags on at first', (
      tester,
    ) async {
      await pump(tester, health: health);
      for (final g in LogGroup.values) {
        expect(on(tester, g), LogGroup.defaults.contains(g), reason: g.name);
      }
      await expectAccessible(tester);
    });

    testWidgets('turning a group on or off is saved to the pod', (
      tester,
    ) async {
      await pump(tester, health: health);
      await tester.ensureVisible(
        find.byKey(SettingsKeys.logGroup(LogGroup.sleep)),
      );
      await tester.tap(find.byKey(SettingsKeys.logGroup(LogGroup.sleep)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsKeys.logGroup(LogGroup.moods)));
      await tester.pumpAndSettle();
      expect(health.data.shownLogGroups, {LogGroup.sleep, LogGroup.tags});
      expect(on(tester, LogGroup.sleep), isTrue);
      expect(on(tester, LogGroup.moods), isFalse);
    });

    testWidgets('someone who only follows has no Log to set up', (
      tester,
    ) async {
      await health.apply((d) => d.withMode(AppMode.partner));
      await pump(tester, health: health);
      expect(find.byKey(SettingsKeys.logGroup(LogGroup.moods)), findsNothing);
    });

    testWidgets('without the data there are no Log switches', (tester) async {
      await pump(tester);
      expect(find.byKey(SettingsKeys.logGroup(LogGroup.moods)), findsNothing);
    });
  });

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
