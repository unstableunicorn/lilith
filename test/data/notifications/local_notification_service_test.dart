import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/notifications/local_notification_service.dart';
import 'package:lilith/data/notifications/notification_service.dart';

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
      [for (final a in details.android?.actions ?? const []) a.id],
      [for (final a in both) a.name],
    );
  });

  test('a reminder without buttons has no category', () {
    final details = LocalNotificationService.detailsFor(reminder(const []));
    expect(details.iOS?.categoryIdentifier, isNull);
    expect(details.android?.actions, isEmpty);
  });
}
