import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/domain/cycle_statistics.dart';
import 'package:lilith/domain/period_reminders.dart';
import 'package:lilith/domain/reminder_setting.dart';

void main() {
  final p = DateTime(2026, 6, 20);
  final early = DateTime(2026, 6, 1, 9);
  const both = ReminderSetting(hour: 8, beforePeriod: true, whenLate: true);

  DateTime at(int day) => DateTime(2026, 6, day, 8);

  List<DateTime> onceTimes(PeriodReminderPlan plan) => [
    for (final r in plan.once) r.at,
  ];

  group('the spread', () {
    CycleStatistics stats(int count, double spread) => CycleStatistics(
      cycleCount: count,
      shortestCycle: 26,
      longestCycle: 30,
      averageCycle: 28,
      cycleSpread: spread,
    );

    final cases = [
      ('no statistics', null, 2),
      ('two cycles', stats(2, 5), 2),
      ('three cycles, rounded', stats(3, 1.6), 2),
      ('regular', stats(6, 0.4), 0),
      ('capped at seven', stats(6, 11.2), 7),
    ];
    for (final (name, s, want) in cases) {
      test(name, () => expect(windowSpreadDays(s), want));
    }
  });

  test('before: N days before the window, its edge, and the day', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both.copyWith(whenLate: false),
      now: early,
    );
    expect(onceTimes(plan), [at(16), at(18), at(20)]);
    expect(plan.checkIn, isNull);
  });

  test('the days before can be changed', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both.copyWith(whenLate: false, daysBefore: 5),
      now: early,
    );
    expect(onceTimes(plan).first, at(13));
  });

  test('late: the edge, the day after, then a daily check-in', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both.copyWith(beforePeriod: false),
      now: early,
    );
    expect(onceTimes(plan), [at(22), at(23)]);
    expect(plan.checkIn!.at, at(24));
    expect(plan.checkIn!.id, checkInReminderId);
    expect(plan.checkIn!.actions, [ReminderAction.log, ReminderAction.snooze]);
  });

  test('the day and after offer to log it', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both,
      now: early,
    );
    expect(plan.once.first.actions, isEmpty);
    expect(plan.once.last.actions, [ReminderAction.log]);
  });

  test('every reminder has its own id in the period range', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both,
      now: early,
    );
    final ids = [for (final r in plan.once) r.id, plan.checkIn!.id];
    expect(ids.toSet(), hasLength(6));
    expect(periodReminderIds.toSet(), ids.toSet());
  });

  test('every reminder asks to be on the minute', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both,
      now: early,
    );
    expect([for (final r in plan.once) r.exact], everyElement(isTrue));
    expect(plan.checkIn!.exact, isTrue);
  });

  test('with no spread the edges are the day itself, shown once', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 0,
      setting: both,
      now: early,
    );
    expect(onceTimes(plan), [at(18), at(20), at(21)]);
    expect(plan.checkIn!.at, at(22));
  });

  test('times already past are left out', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both,
      now: DateTime(2026, 6, 20, 9),
    );
    expect(onceTimes(plan), [at(22), at(23)]);
  });

  test('a check-in already due starts at the next time', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both,
      now: DateTime(2026, 6, 27, 9),
    );
    expect(plan.once, isEmpty);
    expect(plan.checkIn!.at, at(28));
  });

  test('a snooze skips the check-in up to its day', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both,
      now: DateTime(2026, 6, 24, 9),
      snoozedThrough: DateTime(2026, 6, 25),
    );
    expect(plan.checkIn!.at, at(26));
  });

  test('nothing without a prediction or with both switches off', () {
    expect(
      periodRemindersFor(
        predictedStart: null,
        spread: 2,
        setting: both,
        now: early,
      ).isEmpty,
      isTrue,
    );
    expect(
      periodRemindersFor(
        predictedStart: p,
        spread: 2,
        setting: const ReminderSetting(),
        now: early,
      ).isEmpty,
      isTrue,
    );
  });

  test('a snoozed check-in starts the day after tomorrow', () {
    final r = snoozedCheckIn(both, now: DateTime(2026, 6, 24, 8, 1));
    expect(r.at, at(26));
    expect(r.id, checkInReminderId);
  });

  test('every set of buttons a reminder carries is a known one', () {
    final plan = periodRemindersFor(
      predictedStart: p,
      spread: 2,
      setting: both,
      now: early,
    );
    final reminders = [
      ...plan.once,
      plan.checkIn!,
      snoozedCheckIn(both, now: early),
    ];
    for (final r in reminders.where((r) => r.actions.isNotEmpty)) {
      expect(
        reminderActionSets.any((set) => listEquals(set, r.actions)),
        isTrue,
        reason: 'reminder ${r.id}',
      );
    }
  });
}
