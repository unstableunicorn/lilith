// The daily reminder to log, as the user set it on this device.

import 'package:lilith/data/notifications/notification_service.dart';
import 'package:meta/meta.dart';

/// The id of the one daily reminder, apart from share reminders (1000+).
const int dailyReminderId = 1;

/// The id of the test notification sent from Reminders.
const int testReminderId = 2;

/// A notification to show at once, so the user sees reminders reach them.
Reminder testReminder(DateTime now) => Reminder(
  id: testReminderId,
  at: now,
  title: 'Lilith',
  body: 'Reminders reach you on this phone.',
);

@immutable
class ReminderSetting {
  const ReminderSetting({
    this.enabled = false,
    this.hour = defaultHour,
    this.minute = 0,
    this.beforePeriod = false,
    this.daysBefore = defaultDaysBefore,
    this.whenLate = false,
    this.contraception = false,
  });

  factory ReminderSetting.fromJson(Map<String, dynamic> json) =>
      ReminderSetting(
        enabled: json['enabled'] as bool? ?? false,
        hour: (json['hour'] as num?)?.toInt() ?? defaultHour,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
        beforePeriod: json['beforePeriod'] as bool? ?? false,
        daysBefore: (json['daysBefore'] as num?)?.toInt() ?? defaultDaysBefore,
        whenLate: json['whenLate'] as bool? ?? false,
        contraception: json['contraception'] as bool? ?? false,
      );

  /// Early morning, when a temperature is taken.
  static const int defaultHour = 7;

  static const int defaultDaysBefore = 2;
  static const int minDaysBefore = 1;
  static const int maxDaysBefore = 5;

  /// The daily reminder to log.
  final bool enabled;

  /// The time of day every reminder here is shown at.
  final int hour;
  final int minute;

  /// Reminders as the period's window nears: [daysBefore] days ahead of
  /// it, at its start, and on the predicted day.
  final bool beforePeriod;
  final int daysBefore;

  /// Reminders once the period is past its window, then a daily check-in.
  final bool whenLate;

  /// Reminders for the pill, patch or ring, at the schedule's own time.
  final bool contraception;

  ReminderSetting copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? beforePeriod,
    int? daysBefore,
    bool? whenLate,
    bool? contraception,
  }) => ReminderSetting(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    beforePeriod: beforePeriod ?? this.beforePeriod,
    daysBefore: daysBefore ?? this.daysBefore,
    whenLate: whenLate ?? this.whenLate,
    contraception: contraception ?? this.contraception,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'beforePeriod': beforePeriod,
    'daysBefore': daysBefore,
    'whenLate': whenLate,
    'contraception': contraception,
  };

  /// [day] at this setting's time of day.
  DateTime timeOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

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
    exact: true,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSetting &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute &&
      other.beforePeriod == beforePeriod &&
      other.daysBefore == daysBefore &&
      other.whenLate == whenLate &&
      other.contraception == contraception;

  @override
  int get hashCode => Object.hash(
    enabled,
    hour,
    minute,
    beforePeriod,
    daysBefore,
    whenLate,
    contraception,
  );
}
