import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/period_reminder_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/period_reminders.dart';
import 'package:lilith/domain/reminder_setting.dart';

import '../fakes/fake_notification_service.dart';
import '../fakes/fake_pod_service.dart';
import '../fakes/fake_settings_store.dart';

void main() {
  const codec = HealthDocumentCodec();
  final now = DateTime(2026, 5, 20, 9);
  // Cycles of 27, 29 and 28 days: the next start is 1 June, give or take 1.
  final history = [
    for (final d in [
      DateTime(2026, 2, 9),
      DateTime(2026, 3, 8),
      DateTime(2026, 4, 6),
      DateTime(2026, 5, 4),
    ])
      PeriodEvent(startDate: d, endDate: d.add(const Duration(days: 4))),
  ];

  late FakeSettingsStore settings;
  late FakeNotificationService notifications;
  late HealthRepository health;
  late ReminderRepository reminders;
  late PeriodReminderRepository repo;

  Future<void> start(
    HealthData data, {
    ReminderSetting setting = const ReminderSetting(
      beforePeriod: true,
      whenLate: true,
    ),
  }) async {
    final pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.plain);
    pod.documents[health.documentPath] = codec.encode(data);
    settings = FakeSettingsStore()..reminder = setting;
    notifications = FakeNotificationService();
    reminders = ReminderRepository(settings, notifications, now: () => now);
    await reminders.load();
    repo = PeriodReminderRepository(
      health,
      reminders,
      notifications,
      settings,
      now: () => now,
    );
    await health.load();
    await repo.refresh();
  }

  HealthData withHistory() {
    var d = HealthData.empty;
    for (final p in history) {
      d = d.withPeriod(p);
    }
    return d;
  }

  List<DateTime> scheduledTimes() =>
      [for (final r in notifications.scheduled.values) r.at]..sort();

  test('schedules around the predicted start, at the reminder time', () async {
    await start(withHistory());
    expect(reminders.periodApplies, isTrue);
    expect(scheduledTimes(), [
      DateTime(2026, 5, 29, 7),
      DateTime(2026, 5, 31, 7),
      DateTime(2026, 6, 1, 7),
      DateTime(2026, 6, 2, 7),
      DateTime(2026, 6, 3, 7),
    ]);
    expect(notifications.daily[checkInReminderId]!.at, DateTime(2026, 6, 4, 7));
  });

  test('logging a period start moves every reminder on', () async {
    await start(withHistory());
    await health.apply(
      (d) => d.withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 20))),
    );
    await repo.refresh();
    final oldCheckIn = DateTime(2026, 6, 4, 7);
    expect(scheduledTimes(), isNotEmpty);
    expect(scheduledTimes().every((t) => t.isAfter(oldCheckIn)), isTrue);
    expect(
      notifications.daily[checkInReminderId]!.at.isAfter(oldCheckIn),
      isTrue,
    );
  });

  test('a changed setting reschedules', () async {
    await start(withHistory());
    await reminders.setWhenLate(false);
    await repo.refresh();
    expect(notifications.daily, isEmpty);
    expect(scheduledTimes(), hasLength(3));
    await reminders.setBeforePeriod(false);
    await repo.refresh();
    expect(notifications.scheduled, isEmpty);
  });

  test('nothing under hormonal contraception, and it says so', () async {
    await start(
      withHistory().withProfile(
        HealthProfile(contraception: Contraception.combinedPill),
      ),
    );
    expect(reminders.periodApplies, isFalse);
    expect(notifications.scheduled, isEmpty);
    expect(notifications.daily, isEmpty);
    expect(notifications.cancelled, containsAll(periodReminderIds));
  });

  test('nothing without a period logged', () async {
    await start(HealthData.empty);
    expect(notifications.scheduled, isEmpty);
    expect(reminders.periodApplies, isTrue);
  });

  test('nothing on a device without notifications', () async {
    final pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.plain);
    pod.documents[health.documentPath] = codec.encode(withHistory());
    settings = FakeSettingsStore()
      ..reminder = const ReminderSetting(beforePeriod: true);
    notifications = FakeNotificationService()..available = false;
    reminders = ReminderRepository(settings, notifications);
    await reminders.load();
    repo = PeriodReminderRepository(
      health,
      reminders,
      notifications,
      settings,
      now: () => now,
    );
    await health.load();
    await repo.refresh();
    expect(notifications.scheduled, isEmpty);
  });

  test('a stored snooze holds the check-in back', () async {
    final pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.plain);
    pod.documents[health.documentPath] = codec.encode(withHistory());
    settings = FakeSettingsStore()
      ..reminder = const ReminderSetting(whenLate: true)
      ..snoozedThrough = DateTime(2026, 6, 5);
    notifications = FakeNotificationService();
    reminders = ReminderRepository(settings, notifications);
    await reminders.load();
    repo = PeriodReminderRepository(
      health,
      reminders,
      notifications,
      settings,
      now: () => now,
    );
    await health.load();
    await repo.refresh();
    expect(notifications.daily[checkInReminderId]!.at, DateTime(2026, 6, 6, 7));
  });

  test('a snooze saves tomorrow and moves the check-in past it', () async {
    settings = FakeSettingsStore()
      ..reminder = const ReminderSetting(whenLate: true, hour: 8);
    notifications = FakeNotificationService();
    await snoozeCheckIn(settings, notifications, now: DateTime(2026, 6, 4, 8));
    expect(settings.snoozedThrough, DateTime(2026, 6, 5));
    expect(notifications.cancelled, [checkInReminderId]);
    expect(notifications.daily[checkInReminderId]!.at, DateTime(2026, 6, 6, 8));
  });

  test('signing out cancels every period reminder', () async {
    notifications = FakeNotificationService();
    await cancelPeriodReminders(notifications);
    expect(notifications.cancelled, periodReminderIds);
  });

  test('once disposed, period reminders no longer apply', () async {
    await start(withHistory());
    repo.dispose();
    expect(reminders.periodApplies, isFalse);
  });
}
