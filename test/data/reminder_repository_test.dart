import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/reminder_setting.dart';

import '../fakes/fake_notification_service.dart';
import '../fakes/fake_settings_store.dart';

void main() {
  final now = DateTime(2026, 6, 10, 9);
  late FakeSettingsStore settings;
  late FakeNotificationService notifications;
  late ReminderRepository repo;

  setUp(() {
    settings = FakeSettingsStore();
    notifications = FakeNotificationService();
    repo = ReminderRepository(settings, notifications, now: () => now);
  });

  test('starts off and unloaded; load reads the setting', () async {
    expect(repo.setting.enabled, isFalse);
    expect(repo.isLoaded, isFalse);
    settings.reminder = const ReminderSetting(enabled: true, hour: 6);
    await repo.load();
    expect(repo.isLoaded, isTrue);
    expect(repo.setting.hour, 6);
    expect(notifications.daily[dailyReminderId]!.at, DateTime(2026, 6, 11, 6));
  });

  test('turning on asks once, saves and schedules daily', () async {
    await repo.setEnabled(true);
    expect(notifications.permissionRequests, 1);
    expect(settings.reminder.enabled, isTrue);
    expect(notifications.daily.keys, [dailyReminderId]);
    expect(repo.isAllowed, isTrue);
  });

  test('a refused permission leaves it off and says so', () async {
    notifications.permission = false;
    await repo.setEnabled(true);
    expect(repo.setting.enabled, isFalse);
    expect(repo.isAllowed, isFalse);
    expect(notifications.daily, isEmpty);
    expect(settings.reminder.enabled, isFalse);
  });

  test('changing the time reschedules only when on', () async {
    await repo.setTime(hour: 21, minute: 15);
    expect(notifications.daily, isEmpty);
    expect(settings.reminder.hour, 21);
    await repo.setEnabled(true);
    await repo.setTime(hour: 22, minute: 0);
    expect(notifications.daily[dailyReminderId]!.at, DateTime(2026, 6, 10, 22));
  });

  test('allowing exact times sets the daily reminder again', () async {
    await repo.setEnabled(true);
    notifications.daily.clear();
    await repo.requestExact();
    expect(notifications.daily.keys, [dailyReminderId]);
  });

  test('a test notification is shown now', () async {
    await repo.sendTest();
    expect(notifications.shown.map((r) => r.at), [now]);
  });

  test('turning off cancels', () async {
    await repo.setEnabled(true);
    await repo.setEnabled(false);
    expect(notifications.cancelled, [dailyReminderId]);
    expect(notifications.daily, isEmpty);
    expect(settings.reminder.enabled, isFalse);
  });

  test('on a device without notifications nothing is scheduled', () async {
    notifications.available = false;
    expect(repo.isAvailable, isFalse);
    await repo.setEnabled(true);
    expect(notifications.daily, isEmpty);
  });

  test('notifies listeners', () async {
    var n = 0;
    repo.addListener(() => n++);
    await repo.setEnabled(true);
    expect(n, 1);
  });

  test('period switches ask once, then save without scheduling', () async {
    await repo.setBeforePeriod(true);
    await repo.setWhenLate(true);
    expect(notifications.permissionRequests, 2);
    expect(settings.reminder.beforePeriod, isTrue);
    expect(settings.reminder.whenLate, isTrue);
    expect(notifications.daily, isEmpty);
    await repo.setWhenLate(false);
    expect(settings.reminder.whenLate, isFalse);
  });

  test('a refused permission leaves the period switch off', () async {
    notifications.permission = false;
    await repo.setBeforePeriod(true);
    expect(repo.setting.beforePeriod, isFalse);
    expect(repo.isAllowed, isFalse);
  });

  test('the days before stay between one and five', () async {
    await repo.setDaysBefore(9);
    expect(settings.reminder.daysBefore, ReminderSetting.maxDaysBefore);
    await repo.setDaysBefore(0);
    expect(settings.reminder.daysBefore, ReminderSetting.minDaysBefore);
  });

  test('period reminders do not apply until the data says so', () {
    var n = 0;
    repo.addListener(() => n++);
    expect(repo.periodApplies, isFalse);
    repo.periodApplies = true;
    repo.periodApplies = true;
    expect(repo.periodApplies, isTrue);
    expect(n, 1);
  });

  group('pill, patch and ring', () {
    final schedule = ContraceptionSchedule(
      form: DoseForm.pill,
      start: DateTime(2026, 6, 1),
      daysOn: 21,
      daysOff: 7,
      windowHours: 24,
    );

    test('the switch asks once, then saves', () async {
      await repo.setContraception(true);
      expect(notifications.permissionRequests, 1);
      expect(settings.reminder.contraception, isTrue);
      await repo.setContraception(false);
      expect(settings.reminder.contraception, isFalse);
    });

    test('a refused permission leaves the switch off', () async {
      notifications.permission = false;
      await repo.setContraception(true);
      expect(settings.reminder.contraception, isFalse);
      expect(repo.isAllowed, isFalse);
    });

    test('exact times: read, then asked for in the system setting', () async {
      await repo.checkExact();
      expect(repo.exactAllowed, isFalse);
      await repo.requestExact();
      expect(notifications.exactRequests, 1);
      expect(repo.exactAllowed, isTrue);
    });

    test('exact times refused stay refused', () async {
      notifications.exactGrant = false;
      await repo.requestExact();
      expect(notifications.exactRequests, 1);
      expect(repo.exactAllowed, isFalse);
    });

    test('holds the method and schedule from the data, notifying once', () {
      var n = 0;
      repo.addListener(() => n++);
      repo
        ..setDose(Contraception.combinedPill, schedule)
        ..setDose(Contraception.combinedPill, schedule);
      expect(repo.doseMethod, Contraception.combinedPill);
      expect(repo.doseSchedule, schedule);
      expect(n, 1);
      repo.forgetDose();
      expect(repo.doseMethod, isNull);
      expect(repo.doseSchedule, isNull);
      expect(n, 1);
    });
  });
}
