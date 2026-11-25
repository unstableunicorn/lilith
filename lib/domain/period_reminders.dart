// The reminders around a predicted period: before its window, on the day,
// once it is late, and a daily check-in until a start is logged.

import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/domain/cycle_statistics.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:meta/meta.dart';

const int _comingUpId = 10;
const int _windowStartsId = 11;
const int _dueTodayId = 12;
const int _possiblyLateId = 13;
const int _lateId = 14;

/// The repeating check-in, the one a snooze moves.
const int checkInReminderId = 15;

/// Every id a period reminder may hold, apart from the daily (1) and
/// share (1000+) reminders.
const List<int> periodReminderIds = [
  _comingUpId,
  _windowStartsId,
  _dueTodayId,
  _possiblyLateId,
  _lateId,
  checkInReminderId,
];

/// Spread used until three cycles are known, and the widest allowed.
const int defaultSpreadDays = 2;
const int maxSpreadDays = 7;

/// Days either side of the predicted start that still count as on time:
/// the cycles' spread, rounded.
int windowSpreadDays(CycleStatistics? stats) {
  if (stats == null || stats.cycleCount < 3) return defaultSpreadDays;
  return stats.cycleSpread.round().clamp(0, maxSpreadDays);
}

@immutable
class PeriodReminderPlan {
  const PeriodReminderPlan({this.once = const [], this.checkIn});

  /// Shown once each, in time order.
  final List<Reminder> once;

  /// Repeats daily from its time.
  final Reminder? checkIn;

  bool get isEmpty => once.isEmpty && checkIn == null;
}

/// The reminders for a period predicted on [predictedStart], give or take
/// [spread] days, still ahead of [now]. A check-in never falls on or
/// before [snoozedThrough].
PeriodReminderPlan periodRemindersFor({
  required DateTime? predictedStart,
  required int spread,
  required ReminderSetting setting,
  required DateTime now,
  DateTime? snoozedThrough,
}) {
  final p = predictedStart;
  if (p == null) return const PeriodReminderPlan();
  final once = <Reminder>[
    if (setting.beforePeriod) ...[
      Reminder(
        id: _comingUpId,
        at: setting.timeOn(addDays(p, -spread - setting.daysBefore)),
        title: 'Your period is coming up',
        body: setting.daysBefore == 1
            ? 'Your usual window starts tomorrow.'
            : 'Your usual window starts in ${setting.daysBefore} days.',
      ),
      if (spread > 0)
        Reminder(
          id: _windowStartsId,
          at: setting.timeOn(addDays(p, -spread)),
          title: 'Your period could start any day now',
          body: 'Today is the start of your usual window.',
        ),
      Reminder(
        id: _dueTodayId,
        at: setting.timeOn(p),
        title: 'Your period is expected today',
        body: 'Log it when it starts.',
        actions: logActions,
      ),
    ],
    if (setting.whenLate) ...[
      if (spread > 0)
        Reminder(
          id: _possiblyLateId,
          at: setting.timeOn(addDays(p, spread)),
          title: 'Your period may be late',
          body: 'Today is the end of your usual window. Log it if it started.',
          actions: logActions,
        ),
      Reminder(
        id: _lateId,
        at: setting.timeOn(addDays(p, spread + 1)),
        title: 'Your period is late',
        body: 'It is past your usual window. Log it if it started.',
        actions: logActions,
      ),
    ],
  ];
  return PeriodReminderPlan(
    once: [
      for (final r in once)
        if (r.at.isAfter(now)) r,
    ],
    checkIn: setting.whenLate
        ? _checkInFrom(
            addDays(p, spread + 2),
            setting,
            now: now,
            snoozedThrough: snoozedThrough,
          )
        : null,
  );
}

/// The check-in after a snooze tapped at [now]: tomorrow is skipped.
Reminder snoozedCheckIn(ReminderSetting setting, {required DateTime now}) =>
    _checkIn(setting.timeOn(addDays(dateOnly(now), 2)));

Reminder _checkInFrom(
  DateTime first,
  ReminderSetting setting, {
  required DateTime now,
  DateTime? snoozedThrough,
}) {
  var day = first;
  final skip = snoozedThrough;
  if (skip != null && !day.isAfter(skip)) day = addDays(dateOnly(skip), 1);
  while (!setting.timeOn(day).isAfter(now)) {
    day = addDays(day, 1);
  }
  return _checkIn(setting.timeOn(day));
}

Reminder _checkIn(DateTime at) => Reminder(
  id: checkInReminderId,
  at: at,
  title: 'Checking in: your period is still late',
  body:
      'Is everything OK? Log it if it started, or snooze this for a day. '
      'A test or a word with your doctor can tell you more.',
  actions: checkInActions,
);
