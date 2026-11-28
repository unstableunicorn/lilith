// Keeps the period reminders on this device in step with the prediction and
// the reminder settings: rescheduled on every change, none when they do not
// apply.

import 'dart:async';

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/cycle_statistics.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_reminders.dart';

class PeriodReminderRepository {
  PeriodReminderRepository(
    this._health,
    this._reminders,
    this._notifications,
    this._settings, {
    this.now = DateTime.now,
    this.predictor = const CyclePredictor(),
  }) {
    _health.addListener(_changed);
    _reminders.addListener(_changed);
  }

  final HealthRepository _health;
  final ReminderRepository _reminders;
  final NotificationService _notifications;
  final SettingsStore _settings;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final CyclePredictor predictor;

  Future<void> _last = Future.value();

  void _changed() => unawaited(refresh());

  /// Cancels the period reminders and schedules them again from the data.
  /// Calls run one after another, so the last change wins.
  Future<void> refresh() => _last = _last.then((_) => _refresh());

  Future<void> _refresh() async {
    if (!_health.isLoaded) return;
    final data = _health.data;
    // Someone who only follows has no cycle of their own to be reminded of.
    final tracks = data.modeInForce.tracksOwnCycle;
    final applies = tracks && !data.profile.usesHormonalContraception;
    _reminders.periodApplies = applies;
    await _reminders.setDailyApplies(applies: tracks);
    await cancelPeriodReminders(_notifications);
    if (!applies || !_notifications.isAvailable) return;
    final at = now();
    final today = dateOnly(at);
    final prediction = predictor.predict(
      readings: data.readings,
      periods: data.periods,
      today: today,
      nights: data.wearableNights,
      usualCycleLength: data.profile.usualCycleLength,
      factors: data.profile.lifeFactors,
    );
    // Under a life factor nothing is predicted, so nothing is scheduled.
    final plan = periodRemindersFor(
      predictedStart: prediction.predictedNextPeriod,
      spread: windowSpreadDays(
        cycleStatisticsFor(
          data.periods,
          today: today,
          factors: data.profile.lifeFactors,
        ),
      ),
      setting: _reminders.setting,
      now: at,
      snoozedThrough: await _settings.readSnoozedThrough(),
    );
    for (final r in plan.once) {
      await _notifications.schedule(r);
    }
    if (plan.checkIn case final r?) await _notifications.scheduleDaily(r);
  }

  void dispose() {
    _health.removeListener(_changed);
    _reminders
      ..removeListener(_changed)
      ..forgetPeriod();
  }
}

/// Signing out leaves no period reminder from that account behind.
Future<void> cancelPeriodReminders(NotificationService notifications) async {
  for (final id in periodReminderIds) {
    await notifications.cancel(id);
  }
}

/// What "Snooze 1 day" on a check-in does, with or without the app open:
/// tomorrow is skipped and the daily check-in starts again after it.
Future<void> snoozeCheckIn(
  SettingsStore settings,
  NotificationService notifications, {
  required DateTime now,
}) async {
  await settings.writeSnoozedThrough(addDays(dateOnly(now), 1));
  final setting = await settings.readReminder();
  await notifications.cancel(checkInReminderId);
  await notifications.scheduleDaily(snoozedCheckIn(setting, now: now));
}
