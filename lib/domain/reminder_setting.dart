// The daily reminder to log, as the user set it on this device.

import 'package:lilith/data/notifications/notification_service.dart';
import 'package:meta/meta.dart';

/// The id of the one daily reminder, apart from share reminders (1000+).
const int dailyReminderId = 1;

@immutable
class ReminderSetting {
  const ReminderSetting({
    this.enabled = false,
    this.hour = defaultHour,
    this.minute = 0,
  });

  factory ReminderSetting.fromJson(Map<String, dynamic> json) =>
      ReminderSetting(
        enabled: json['enabled'] as bool? ?? false,
        hour: (json['hour'] as num?)?.toInt() ?? defaultHour,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
      );

  /// Early morning, when a temperature is taken.
  static const int defaultHour = 7;

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSetting copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSetting(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
  };

  /// The next time this reminder is due after [now], today or tomorrow.
  DateTime nextAfter(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// The reminder to schedule, repeating daily from its first time.
  Reminder reminderAfter(DateTime now) => Reminder(
    id: dailyReminderId,
    at: nextAfter(now),
    title: 'Time to log',
    body: 'Your temperature and how today feels, before the day gets going.',
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSetting &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}
