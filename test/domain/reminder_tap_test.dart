// A tap on a reminder itself, not on one of its buttons: the ones that ask
// for something to be logged open Log.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/period_reminders.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/domain/share_reminder.dart';

void main() {
  final now = DateTime(2026, 6, 1, 9);
  const setting = ReminderSetting(
    enabled: true,
    hour: 8,
    beforePeriod: true,
    whenLate: true,
  );

  test('the daily "Time to log" reminder opens Log', () {
    final daily = setting.reminderAfter(now);
    expect(daily.title, 'Time to log');
    expect(tapOpensLog(daily.id), isTrue);
  });

  test('a period reminder opens Log exactly when it has a "Log it" button', () {
    final plan = periodRemindersFor(
      predictedStart: DateTime(2026, 6, 20),
      spread: 2,
      setting: setting,
      now: now,
    );
    final all = [...plan.once, plan.checkIn!];
    expect(all, hasLength(6));
    for (final r in all) {
      expect(
        tapOpensLog(r.id),
        r.actions.contains(ReminderAction.log),
        reason: r.title,
      );
    }
  });

  test('the others leave the app where it was', () {
    for (final id in [
      null,
      testReminderId,
      contraceptionReminderBaseId,
      contraceptionReminderBaseId + 7,
      shareReminderBaseId,
      shareReminderBaseId + 3,
    ]) {
      expect(tapOpensLog(id), isFalse, reason: '$id');
    }
  });
}
