import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/day.dart';

void main() {
  final day = DateTime(2026, 3, 10);
  final morning = DateTime(2026, 3, 10, 7);

  ContraceptionSchedule pill({
    int window = 3,
    int hour = 9,
    bool quiet = false,
    int daysOff = 0,
    DateTime? start,
  }) => ContraceptionSchedule(
    form: DoseForm.pill,
    start: start ?? DateTime(2026, 3, 2),
    daysOn: 21,
    daysOff: daysOff,
    windowHours: window,
    hour: hour,
    quietHours: quiet,
  );

  List<(DoseReminderKind, DateTime)> onDay(
    List<DoseReminder> plan,
    DateTime d,
  ) => [
    for (final r in plan)
      if (r.day == d) (r.kind, r.reminder.at),
  ];

  DateTime at(int h, [int m = 0, DateTime? d]) =>
      DateTime((d ?? day).year, (d ?? day).month, (d ?? day).day, h, m);

  test('a 3-hour window: on time, hourly twice, then the warning', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(),
      now: morning,
      done: const {},
    );
    expect(onDay(plan, day), [
      (DoseReminderKind.due, at(9)),
      (DoseReminderKind.followUp, at(10)),
      (DoseReminderKind.followUp, at(11)),
      (DoseReminderKind.warning, at(12)),
    ]);
  });

  test('a 12-hour window: follow-ups every 4 hours', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(window: 12),
      now: morning,
      done: const {},
    );
    expect(onDay(plan, day), [
      (DoseReminderKind.due, at(9)),
      (DoseReminderKind.followUp, at(13)),
      (DoseReminderKind.followUp, at(17)),
      (DoseReminderKind.warning, at(21)),
    ]);
  });

  test('quiet hours drop a follow-up and hold the warning until 06:00', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(window: 12, hour: 15, quiet: true),
      now: morning,
      done: const {},
    );
    expect(onDay(plan, day), [
      (DoseReminderKind.due, at(15)),
      (DoseReminderKind.followUp, at(19)),
      (DoseReminderKind.warning, at(6, 0, addDays(day, 1))),
    ]);
  });

  test('without quiet hours the night ones stay', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(window: 12, hour: 15),
      now: morning,
      done: const {},
    );
    expect(onDay(plan, day), [
      (DoseReminderKind.due, at(15)),
      (DoseReminderKind.followUp, at(19)),
      (DoseReminderKind.followUp, at(23)),
      (DoseReminderKind.warning, at(3, 0, addDays(day, 1))),
    ]);
  });

  test('a day marked done has none', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(),
      now: morning,
      done: {day},
    );
    expect(onDay(plan, day), isEmpty);
    expect(onDay(plan, addDays(day, 1)), isNotEmpty);
  });

  test('times already past are left out', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(),
      now: at(10, 30),
      done: const {},
    );
    expect(onDay(plan, day), [
      (DoseReminderKind.followUp, at(11)),
      (DoseReminderKind.warning, at(12)),
    ]);
  });

  test('break days have none', () {
    // Day 22 of a 21/7 pack started on 17 Feb is 10 March.
    final plan = contraceptionRemindersFor(
      schedule: pill(daysOff: 7, start: DateTime(2026, 2, 17)),
      now: morning,
      done: const {},
    );
    expect(onDay(plan, day), isEmpty);
    expect(onDay(plan, DateTime(2026, 3, 17)), isNotEmpty);
  });

  test('only the next 14 days', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(),
      now: morning,
      done: const {},
    );
    final days = {for (final r in plan) r.day};
    expect(days.length, contraceptionHorizonDays);
    expect(days.contains(addDays(day, contraceptionHorizonDays)), isFalse);
  });

  test('the due reminder asks about the last dose when it is not done', () {
    final cases = <(String, Set<DateTime>, DateTime, bool)>[
      ('yesterday not done', const {}, DateTime(2026, 3, 2), true),
      ('yesterday done', {addDays(day, -1)}, DateTime(2026, 3, 2), false),
      ('the first dose', const {}, day, false),
    ];
    for (final (name, done, start, want) in cases) {
      final plan = contraceptionRemindersFor(
        schedule: pill(start: start),
        now: morning,
        done: done,
      );
      final due = plan.firstWhere(
        (r) => r.day == day && r.kind == DoseReminderKind.due,
      );
      expect(due.asksAboutLast, want, reason: name);
    }
  });

  test('a pill is marked taken; a patch or ring, done', () {
    final ring = ContraceptionSchedule(
      form: DoseForm.ring,
      start: day,
      daysOn: 21,
      daysOff: 7,
      windowHours: 48,
    );
    final cases = [('pill', pill(), takenActions), ('ring', ring, doneActions)];
    for (final (name, schedule, want) in cases) {
      final plan = contraceptionRemindersFor(
        schedule: schedule,
        now: morning,
        done: const {},
      );
      expect(plan, isNotEmpty, reason: name);
      expect(
        plan.every((r) => listEquals(r.reminder.actions, want)),
        isTrue,
        reason: name,
      );
    }
  });

  test('every reminder asks to be on the minute', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(),
      now: morning,
      done: const {},
    );
    expect(plan, isNotEmpty);
    expect(plan.every((r) => r.reminder.exact), isTrue);
  });

  test('each reminder hands back the day it is for', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(window: 12, hour: 15),
      now: morning,
      done: const {},
    );
    expect(plan, isNotEmpty);
    for (final r in plan) {
      expect(doseDayOf(r.reminder.payload), r.day);
    }
    expect(doseDayOf(null), isNull);
    expect(doseDayOf('soon'), isNull);
  });

  group('the cache', () {
    final cache = DoseCache(
      schedule: pill(),
      done: {DateTime(2026, 3, 8)},
      pending: {day: DateTime(2026, 3, 10, 9, 5)},
    );

    test('round-trips, and reads empty from anything else', () {
      expect(DoseCache.fromJson(cache.toJson()), cache);
      expect(DoseCache.fromJson('x'), const DoseCache());
      expect(
        DoseCache.fromJson({...cache.toJson(), 'schedule': 'x'}).schedule,
        isNull,
      );
    });

    test('a day is done in the pod or marked on the phone', () {
      expect(cache.allDone, {DateTime(2026, 3, 8), day});
    });
  });

  test('ids are distinct and within the range cancelled', () {
    final plan = contraceptionRemindersFor(
      schedule: pill(),
      now: morning,
      done: const {},
    );
    final ids = [for (final r in plan) r.reminder.id];
    expect(ids, isNotEmpty);
    expect(ids.toSet().length, ids.length);
    expect(contraceptionReminderIds.toSet().containsAll(ids), isTrue);
  });
}
