// The reminders for a pill, patch or ring: on time, follow-ups through its
// window, and a warning once the window has passed.

import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/day.dart';
import 'package:meta/meta.dart';

/// The first of the ids these reminders hold, apart from the daily (1),
/// period (10–15) and share (1000+) reminders.
const int contraceptionReminderBaseId = 2000;

/// Days ahead that are scheduled; opening the app moves them on.
const int contraceptionHorizonDays = 14;

/// Every id a contraception reminder may hold.
final List<int> contraceptionReminderIds = [
  for (var i = 0; i < contraceptionHorizonDays * 4; i++)
    contraceptionReminderBaseId + i,
];

enum DoseReminderKind { due, followUp, warning }

@immutable
class DoseReminder {
  const DoseReminder({
    required this.kind,
    required this.day,
    required this.reminder,
    this.asksAboutLast = false,
  });

  final DoseReminderKind kind;

  /// The day the dose belongs to.
  final DateTime day;
  final Reminder reminder;

  /// On a due reminder: the dose before it is not marked done.
  final bool asksAboutLast;
}

/// The reminders still ahead of [now] for the next
/// [contraceptionHorizonDays] days. Nothing for a day in [done].
List<DoseReminder> contraceptionRemindersFor({
  required ContraceptionSchedule schedule,
  required DateTime now,
  required Set<DateTime> done,
}) {
  final today = dateOnly(now);
  final step = Duration(minutes: schedule.windowHours * 60 ~/ 3);
  final plan = <DoseReminder>[];
  for (var i = 0; i < contraceptionHorizonDays; i++) {
    final d = addDays(today, i);
    if (schedule.stepOn(d) == null || done.contains(d)) continue;
    final due = DateTime(
      d.year,
      d.month,
      d.day,
      schedule.hour,
      schedule.minute,
    );
    final id = contraceptionReminderBaseId + i * 4;
    final last = _lastDueBefore(schedule, d);
    final asks = last != null && !done.contains(last);
    DoseReminder make(DoseReminderKind kind, int k, DateTime at) =>
        DoseReminder(
          kind: kind,
          day: d,
          asksAboutLast: kind == DoseReminderKind.due && asks,
          reminder: Reminder(
            id: id + k,
            at: at,
            title: 'Lilith',
            body: kind == DoseReminderKind.due && asks
                ? '${_bodies[kind]} The last one is not marked done.'
                : _bodies[kind]!,
            actions: schedule.form == DoseForm.pill
                ? takenActions
                : doneActions,
          ),
        );
    final warnAt = due.add(step * 3);
    final day = [
      make(DoseReminderKind.due, 0, due),
      for (final k in [1, 2])
        if (!(schedule.quietHours && _isQuiet(due.add(step * k))))
          make(DoseReminderKind.followUp, k, due.add(step * k)),
      make(
        DoseReminderKind.warning,
        3,
        schedule.quietHours && _isQuiet(warnAt) ? _quietEnd(warnAt) : warnAt,
      ),
    ];
    plan.addAll(day.where((r) => r.reminder.at.isAfter(now)));
  }
  return plan;
}

const Map<DoseReminderKind, String> _bodies = {
  DoseReminderKind.due: 'Your daily reminder.',
  DoseReminderKind.followUp: 'Your daily reminder, again.',
  DoseReminderKind.warning:
      'The time for your reminder has passed. Check your leaflet or ask a '
      'pharmacist what to do.',
};

/// The last day before [day] something was due, or null before the start.
DateTime? _lastDueBefore(ContraceptionSchedule s, DateTime day) {
  for (var d = addDays(day, -1); !d.isBefore(s.start); d = addDays(d, -1)) {
    if (s.stepOn(d) != null) return d;
  }
  return null;
}

bool _isQuiet(DateTime t) =>
    t.hour >= ContraceptionSchedule.quietFrom ||
    t.hour < ContraceptionSchedule.quietUntil;

/// The end of the quiet hours [t] falls in.
DateTime _quietEnd(DateTime t) {
  final day = t.hour >= ContraceptionSchedule.quietFrom
      ? addDays(dateOnly(t), 1)
      : dateOnly(t);
  return DateTime(
    day.year,
    day.month,
    day.day,
    ContraceptionSchedule.quietUntil,
  );
}
