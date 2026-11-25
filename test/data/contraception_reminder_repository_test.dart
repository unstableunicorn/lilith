import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/contraception_reminder_repository.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/reminder_setting.dart';

import '../fakes/fake_notification_service.dart';
import '../fakes/fake_pod_service.dart';
import '../fakes/fake_settings_store.dart';

void main() {
  const codec = HealthDocumentCodec();
  final today = DateTime(2026, 3, 10);
  final now = DateTime(2026, 3, 10, 7);
  final tomorrow = addDays(today, 1);
  final schedule = ContraceptionSchedule(
    form: DoseForm.pill,
    start: DateTime(2026, 3, 2),
    daysOn: 21,
    daysOff: 0,
    windowHours: 3,
  );
  final profile = HealthProfile(
    contraception: Contraception.progestogenOnlyPill,
    contraceptionSchedule: schedule,
  );

  late FakePodService pod;
  late FakeSettingsStore settings;
  late FakeNotificationService notifications;
  late HealthRepository health;
  late ReminderRepository reminders;
  late ContraceptionReminderRepository repo;

  Future<void> start(
    HealthData data, {
    bool on = true,
    bool available = true,
    DoseCache cache = const DoseCache(),
  }) async {
    pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.plain);
    pod.documents[health.documentPath] = codec.encode(data);
    settings = FakeSettingsStore()
      ..reminder = ReminderSetting(contraception: on)
      ..doseCache = cache;
    notifications = FakeNotificationService()..available = available;
    reminders = ReminderRepository(settings, notifications, now: () => now);
    await reminders.load();
    repo = ContraceptionReminderRepository(
      health,
      reminders,
      notifications,
      settings,
      now: () => now,
    );
    await health.load();
    await repo.refresh();
  }

  /// The reminders scheduled for [day], in time order.
  List<DateTime> timesOn(DateTime day) => [
    for (final r in notifications.scheduled.values)
      if (doseDayOf(r.payload) == day) r.at,
  ]..sort();

  test('schedules the plan from the profile', () async {
    await start(HealthData(profile: profile));
    final want = contraceptionRemindersFor(
      schedule: schedule,
      now: now,
      done: const {},
    );
    expect(notifications.scheduled.values.toSet(), {
      for (final r in want) r.reminder,
    });
    expect(timesOn(today), [
      DateTime(2026, 3, 10, 9),
      DateTime(2026, 3, 10, 10),
      DateTime(2026, 3, 10, 11),
      DateTime(2026, 3, 10, 12),
    ]);
  });

  final none = <(String, HealthData, bool, bool)>[
    ('off on this phone', HealthData(profile: profile), false, true),
    (
      'no schedule',
      HealthData(
        profile: HealthProfile(contraception: Contraception.combinedPill),
      ),
      true,
      true,
    ),
    (
      'a method without one',
      HealthData(
        profile: profile.copyWith(contraception: Contraception.implant),
      ),
      true,
      true,
    ),
    ('no notifications here', HealthData(profile: profile), true, false),
  ];
  for (final (name, data, on, available) in none) {
    test('none when $name', () async {
      await start(data, on: on, available: available);
      expect(notifications.scheduled, isEmpty);
    });
  }

  test('a change cancels what was scheduled', () async {
    await start(HealthData(profile: profile));
    expect(notifications.scheduled, isNotEmpty);
    await health.apply(
      (d) => d.copyWith(
        profile: d.profile.copyWith(unset: const {'contraceptionSchedule'}),
      ),
    );
    await repo.refresh();
    expect(notifications.scheduled, isEmpty);
    expect(notifications.cancelled, containsAll(contraceptionReminderIds));
  });

  test('a day done in the pod has none', () async {
    await start(
      HealthData(
        profile: profile,
        dailyLogs: [
          DailyLog(date: today, contraceptionDoneAt: DateTime(2026, 3, 10, 6)),
        ],
      ),
    );
    expect(timesOn(today), isEmpty);
    expect(timesOn(tomorrow), isNotEmpty);
  });

  test('marks made on the phone go to the pod, keeping the day', () async {
    final at = DateTime(2026, 3, 9, 9, 10);
    await start(
      HealthData(
        profile: profile,
        dailyLogs: [DailyLog(date: DateTime(2026, 3, 9), painLevel: 2)],
      ),
      cache: DoseCache(pending: {DateTime(2026, 3, 9): at}),
    );
    final stored = codec.decode(pod.documents[health.documentPath]!);
    expect(stored.dailyLogs, [
      DailyLog(
        date: DateTime(2026, 3, 9),
        painLevel: 2,
        contraceptionDoneAt: at,
      ),
    ]);
    expect(settings.doseCache.pending, isEmpty);
  });

  test('a mark kept on the phone survives a failed pod write', () async {
    final at = DateTime(2026, 3, 9, 9, 10);
    await start(
      HealthData(profile: profile),
      cache: DoseCache(pending: {DateTime(2026, 3, 9): at}),
    );
    expect(settings.doseCache.pending, isEmpty);
    pod.failWrites = const PodAccessException('403');
    settings.doseCache = DoseCache(
      schedule: schedule,
      pending: {today: DateTime(2026, 3, 10, 9, 2)},
    );
    await repo.refresh();
    expect(settings.doseCache.pending.keys, [today]);
  });

  test('keeps the schedule and the done days for a button to use', () async {
    await start(
      HealthData(
        profile: profile,
        dailyLogs: [
          DailyLog(
            date: DateTime(2026, 3, 9),
            contraceptionDoneAt: DateTime(2026, 3, 9, 9),
          ),
        ],
      ),
    );
    expect(settings.doseCache.schedule, schedule);
    expect(settings.doseCache.done, {DateTime(2026, 3, 9)});
  });

  test('marked done in the app: saved now, and that day has none', () async {
    await start(HealthData(profile: profile));
    await repo.markDone(today);
    await repo.refresh();
    expect(
      [for (final l in health.data.dailyLogs) l.contraceptionDoneAt],
      [now],
    );
    expect(timesOn(today), isEmpty);
  });

  test('a button tap keeps the mark and replans without that day', () async {
    await start(HealthData(profile: profile));
    final tapped = DateTime(2026, 3, 10, 9, 5);
    await markDoseDone(settings, notifications, day: today, now: tapped);
    expect(settings.doseCache.pending, {today: tapped});
    expect(timesOn(today), isEmpty);
    final want = contraceptionRemindersFor(
      schedule: schedule,
      now: tapped,
      done: {today},
    );
    expect(notifications.scheduled.values.toSet(), {
      for (final r in want) r.reminder,
    });
  });

  test('a button tap with no schedule kept does nothing else', () async {
    await start(HealthData(profile: profile), on: false);
    await markDoseDone(settings, notifications, day: today, now: now);
    expect(settings.doseCache.pending, {today: now});
    expect(notifications.scheduled, isEmpty);
  });

  test('signing out cancels them all', () async {
    await start(HealthData(profile: profile));
    expect(notifications.scheduled, isNotEmpty);
    await cancelContraceptionReminders(notifications);
    expect(notifications.scheduled, isEmpty);
  });
}
