import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/ui/reminders/reminders_screen.dart';
import 'package:lilith/ui/reminders/reminders_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_notification_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final now = DateTime(2026, 6, 10, 9);
  late FakeSettingsStore settings;
  late FakeNotificationService notifications;
  late ReminderRepository repo;

  setUp(() {
    settings = FakeSettingsStore();
    notifications = FakeNotificationService();
    repo = ReminderRepository(settings, notifications, now: () => now);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        reminders: repo,
        child: const RemindersScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('turns the daily reminder on and off', (tester) async {
    await pump(tester);
    expect(find.byKey(RemindersKeys.unavailable), findsNothing);
    await tester.tap(find.byKey(RemindersKeys.toggle));
    await tester.pumpAndSettle();
    expect(settings.reminder.enabled, isTrue);
    expect(notifications.daily.keys, [dailyReminderId]);
    await expectAccessible(tester);
    await tester.tap(find.byKey(RemindersKeys.toggle));
    await tester.pumpAndSettle();
    expect(settings.reminder.enabled, isFalse);
  });

  testWidgets('a refusal is explained and the switch stays off', (
    tester,
  ) async {
    notifications.permission = false;
    await pump(tester);
    await tester.tap(find.byKey(RemindersKeys.toggle));
    await tester.pumpAndSettle();
    expect(find.byKey(RemindersKeys.refused), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byKey(RemindersKeys.toggle)).value,
      isFalse,
    );
    await expectAccessible(tester);
  });

  testWidgets('the time can be changed', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(RemindersKeys.time));
    await tester.pumpAndSettle();
    expect(find.text('When to remind you'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(settings.reminder.hour, ReminderSetting.defaultHour);
  });

  testWidgets('on the web it says reminders are not available', (tester) async {
    notifications.available = false;
    await pump(tester);
    expect(find.byKey(RemindersKeys.unavailable), findsOneWidget);
    expect(find.byKey(RemindersKeys.toggle), findsNothing);
    await expectAccessible(tester);
  });

  test('the view model shows the time with two digits', () {
    final vm = RemindersViewModel(repo);
    expect(vm.timeText, '07:00');
    expect(vm.wasRefused, isFalse);
  });
}
