import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/notifications/local_notification_service.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/period_reminders.dart';
import 'package:lilith/domain/reminder_setting.dart';

void main() {
  Reminder reminder(List<ReminderAction> actions) => Reminder(
    id: 15,
    at: DateTime(2026, 6, 24, 8),
    title: 'Title',
    body: 'Body',
    actions: actions,
  );

  test('iOS registers a category for each set of buttons, with them', () {
    final categories = LocalNotificationService.darwinCategories;
    expect(categories, isNotEmpty);
    expect(categories, hasLength(reminderActionSets.length));
    for (final set in reminderActionSets) {
      final id = LocalNotificationService.categoryFor(set);
      final category = categories.singleWhere((c) => c.identifier == id);
      expect(
        [for (final a in category.actions) a.identifier],
        [for (final a in set) a.name],
      );
    }
  });

  test('on iOS only "Log it" opens the app', () {
    final actions = {
      for (final c in LocalNotificationService.darwinCategories)
        for (final a in c.actions) a.identifier: a.options,
    };
    expect(
      actions[ReminderAction.log.name],
      contains(DarwinNotificationActionOption.foreground),
    );
    expect(
      actions[ReminderAction.snooze.name],
      isNot(contains(DarwinNotificationActionOption.foreground)),
    );
  });

  test("a reminder's buttons reach both platforms", () {
    const both = [ReminderAction.log, ReminderAction.snooze];
    final details = LocalNotificationService.detailsFor(reminder(both));
    expect(
      details.iOS?.categoryIdentifier,
      LocalNotificationService.categoryFor(both),
    );
    expect(
      [
        for (final a
            in details.android?.actions ?? const <AndroidNotificationAction>[])
          a.id,
      ],
      [for (final a in both) a.name],
    );
  });

  test('a reminder without buttons has no category', () {
    final details = LocalNotificationService.detailsFor(reminder(const []));
    expect(details.iOS?.categoryIdentifier, isNull);
    expect(details.android?.actions, isEmpty);
  });

  group('what a tap asks of the open app', () {
    NotificationResponse body(int id) => NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      id: id,
    );
    NotificationResponse button(int id, ReminderAction a) =>
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: id,
          actionId: a.name,
        );

    test('the daily reminder itself opens Log', () {
      expect(
        LocalNotificationService.opens(body(dailyReminderId)),
        ReminderAction.log,
      );
    });

    test('a pill, patch or ring reminder itself opens Log, and its Taken '
        'button still works without the app', () {
      expect(
        LocalNotificationService.opens(body(contraceptionReminderBaseId)),
        ReminderAction.log,
      );
      expect(
        LocalNotificationService.opens(
          button(contraceptionReminderBaseId, ReminderAction.taken),
        ),
        isNull,
      );
    });

    test('the "Log it" button opens Log, whatever the reminder', () {
      expect(
        LocalNotificationService.opens(
          button(checkInReminderId, ReminderAction.log),
        ),
        ReminderAction.log,
      );
      expect(
        LocalNotificationService.opens(button(999, ReminderAction.log)),
        ReminderAction.log,
      );
    });

    test('a reminder that asks for nothing to be logged opens nothing', () {
      expect(LocalNotificationService.opens(body(testReminderId)), isNull);
    });

    test('a button that works without the app opens nothing, even on a '
        'reminder whose body would', () {
      expect(
        LocalNotificationService.opens(
          button(checkInReminderId, ReminderAction.snooze),
        ),
        isNull,
      );
      expect(
        LocalNotificationService.opens(
          button(dailyReminderId, ReminderAction.taken),
        ),
        isNull,
      );
    });
  });
}
