import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/contraception_reminder_repository.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/period_reminder_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/period_reminders.dart';
import 'package:lilith/domain/reminder_setting.dart';

import '../fakes/fake_notification_service.dart';
import '../fakes/fake_pod_service.dart';
import '../fakes/fake_settings_store.dart';

/// Someone who only follows gets no reminder about a cycle of their own,
/// and gets them back on tracking again.
void main() {
  const codec = HealthDocumentCodec();
  final now = DateTime(2026, 5, 20, 9);
  final periods = [
    for (final d in [
      DateTime(2026, 2, 9),
      DateTime(2026, 3, 8),
      DateTime(2026, 4, 6),
      DateTime(2026, 5, 4),
    ])
      PeriodEvent(startDate: d, endDate: d.add(const Duration(days: 4))),
  ];
  final pill = HealthProfile(
    contraception: Contraception.progestogenOnlyPill,
    contraceptionSchedule: ContraceptionSchedule(
      form: DoseForm.pill,
      start: DateTime(2026, 5, 2),
      daysOn: 21,
      daysOff: 0,
      windowHours: 3,
    ),
  );

  late FakeSettingsStore settings;
  late FakeNotificationService notifications;
  late HealthRepository health;
  late ReminderRepository reminders;
  late PeriodReminderRepository period;
  late ContraceptionReminderRepository doses;

  Future<void> start(HealthData data) async {
    final pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.plain);
    pod.documents[health.documentPath] = codec.encode(data);
    settings = FakeSettingsStore()
      ..reminder = const ReminderSetting(
        enabled: true,
        beforePeriod: true,
        whenLate: true,
        contraception: true,
      );
    notifications = FakeNotificationService();
    reminders = ReminderRepository(settings, notifications, now: () => now);
    await reminders.load();
    period = PeriodReminderRepository(
      health,
      reminders,
      notifications,
      settings,
      now: () => now,
    );
    doses = ContraceptionReminderRepository(
      health,
      reminders,
      notifications,
      settings,
      now: () => now,
    );
    await health.load();
    await period.refresh();
    await doses.refresh();
  }

  Future<void> change(AppMode mode) async {
    await health.apply((d) => d.withMode(mode));
    await period.refresh();
    await doses.refresh();
  }

  HealthData cycles() {
    var d = HealthData.empty;
    for (final p in periods) {
      d = d.withPeriod(p);
    }
    return d;
  }

  test('a tracker has the daily, period and check-in reminders', () async {
    await start(cycles());
    expect(notifications.daily.keys, contains(dailyReminderId));
    expect(notifications.daily.keys, contains(checkInReminderId));
    expect(notifications.scheduled, isNotEmpty);
    expect(reminders.dailyApplies, isTrue);
  });

  test('changing to following only cancels all of them', () async {
    await start(cycles());
    await change(AppMode.partner);
    expect(notifications.daily, isEmpty);
    expect(notifications.scheduled, isEmpty);
    expect(reminders.dailyApplies, isFalse);
    expect(reminders.periodApplies, isFalse);
    expect(reminders.setting.enabled, isTrue, reason: 'the setting is kept');
  });

  test('tracking again brings them back', () async {
    await start(cycles());
    await change(AppMode.partner);
    await change(AppMode.tracker);
    expect(notifications.daily.keys, contains(dailyReminderId));
    expect(notifications.daily.keys, contains(checkInReminderId));
    expect(notifications.scheduled, isNotEmpty);
  });

  test('"both" keeps them', () async {
    await start(cycles());
    await change(AppMode.both);
    expect(notifications.daily.keys, contains(dailyReminderId));
    expect(notifications.scheduled, isNotEmpty);
  });

  test('a partner who signs in gets none, daily included', () async {
    await start(cycles().withMode(AppMode.partner));
    expect(notifications.daily, isEmpty);
    expect(notifications.scheduled, isEmpty);
  });

  test('pill reminders stop for following only, and return', () async {
    await start(HealthData(profile: pill));
    expect(notifications.scheduled, isNotEmpty);
    await change(AppMode.partner);
    expect(notifications.scheduled, isEmpty);
    await change(AppMode.tracker);
    expect(notifications.scheduled, isNotEmpty);
  });

  test('a time change while following only schedules nothing', () async {
    await start(cycles().withMode(AppMode.partner));
    await reminders.setTime(hour: 8, minute: 0);
    expect(notifications.daily, isEmpty);
  });
}
