// The reminders for a pill, patch or ring: on time, follow-ups through its
// window, and a warning once the window has passed.

import 'package:collection/collection.dart';
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

/// The day a reminder's payload names, or null when it names none.
DateTime? doseDayOf(String? payload) {
  final day = DateTime.tryParse(payload ?? '');
  return day == null ? null : dateOnly(day);
}

String _dayText(DateTime day) => dateOnly(day).toIso8601String();

/// What this phone keeps so a button can replan without the pod: the
/// schedule, the days the pod has marked done, and marks still to send.
@immutable
class DoseCache {
  const DoseCache({
    this.schedule,
    this.done = const {},
    this.pending = const {},
  });

  /// The cache stored as [json]; empty when it is not one.
  factory DoseCache.fromJson(Object? json) {
    if (json is! Map) return const DoseCache();
    return DoseCache(
      schedule: ContraceptionSchedule.tryFromJson(json['schedule']),
      done: {
        for (final d in json['done'] as List? ?? const [])
          ?doseDayOf(d as String?),
      },
      pending: {
        for (final MapEntry(:key, :value)
            in (json['pending'] as Map? ?? const {}).entries)
          if ((doseDayOf(key as String?), DateTime.tryParse('$value')) case (
            final day?,
            final at?,
          ))
            day: at,
      },
    );
  }

  final ContraceptionSchedule? schedule;
  final Set<DateTime> done;

  /// Day to the time it was marked, not yet written to the pod.
  final Map<DateTime, DateTime> pending;

  /// Every day known to be done, here or in the pod.
  Set<DateTime> get allDone => {...done, ...pending.keys};

  Map<String, dynamic> toJson() => {
    if (schedule case final s?) 'schedule': s.toJson(),
    'done': [for (final d in done) _dayText(d)],
    'pending': {
      for (final MapEntry(:key, :value) in pending.entries)
        _dayText(key): value.toIso8601String(),
    },
  };

  @override
  bool operator ==(Object other) =>
      other is DoseCache &&
      other.schedule == schedule &&
      const SetEquality<DateTime>().equals(other.done, done) &&
      const MapEquality<DateTime, DateTime>().equals(other.pending, pending);

  @override
  int get hashCode => Object.hash(
    schedule,
    const SetEquality<DateTime>().hash(done),
    const MapEquality<DateTime, DateTime>().hash(pending),
  );
}

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
            payload: _dayText(d),
            exact: true,
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
