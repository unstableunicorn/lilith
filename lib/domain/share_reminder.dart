// The reminder a share with an end day gets: the morning after it ends, so
// the sharer opens the app and the share is actually ended.

import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/share.dart';

/// The hour, local time, reminders are shown at.
const int reminderHour = 9;

/// A stable id for [share]'s reminder, apart from other kinds of reminder.
int shareReminderId(Share share) => 1000 + (share.id.hashCode & 0x3fffff);

/// The reminder for [share], or null when it has no end day.
Reminder? shareReminder(Share share) {
  final end = share.expiresOn;
  if (end == null) return null;
  final morningAfter = addDays(end, 1);
  return Reminder(
    id: shareReminderId(share),
    at: DateTime(
      morningAfter.year,
      morningAfter.month,
      morningAfter.day,
      reminderHour,
    ),
    title: 'You are still sharing with ${share.label}',
    body: 'That share was due to end. Open Lilith to end it.',
  );
}
