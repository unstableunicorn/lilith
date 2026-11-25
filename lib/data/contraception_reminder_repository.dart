// Keeps the pill, patch or ring reminders on this phone in step with the
// schedule in the pod, and sends the marks made from a notification to it.

import 'dart:async';

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';

/// The methods that have a schedule to remind about.
const Set<Contraception> scheduledMethods = {
  Contraception.combinedPill,
  Contraception.progestogenOnlyPill,
  Contraception.patchOrRing,
};

class ContraceptionReminderRepository {
  ContraceptionReminderRepository(
    this._health,
    this._reminders,
    this._notifications,
    this._settings, {
    this.now = DateTime.now,
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

  Future<void> _last = Future.value();

  void _changed() => unawaited(refresh());

  /// Sends marks made from a notification to the pod, then cancels the
  /// reminders and schedules them again. Calls run one after another.
  Future<void> refresh() => _last = _last.then((_) => _refresh());

  Future<void> _refresh() async {
    if (!_health.isLoaded) return;
    await _sendPending();
    final data = _health.data;
    final profile = data.profile;
    _reminders.setDose(profile.contraception, profile.contraceptionSchedule);
    final applies =
        _reminders.setting.contraception &&
        _notifications.isAvailable &&
        scheduledMethods.contains(profile.contraception);
    final schedule = applies ? profile.contraceptionSchedule : null;
    final cache = DoseCache(
      schedule: schedule,
      done: {
        for (final l in data.dailyLogs)
          if (l.contraceptionDoneAt != null) l.date,
      },
      pending: (await _settings.readDoseCache()).pending,
    );
    await _settings.writeDoseCache(cache);
    await _replan(cache, _notifications, now: now());
  }

  /// Writes the marks kept on this phone to the pod; they stay on the
  /// phone until the write succeeds.
  Future<void> _sendPending() async {
    final pending = (await _settings.readDoseCache()).pending;
    if (pending.isEmpty) return;
    await _health.apply((d) => _withDone(d, pending));
    if (_health.error != null) return;
    final cache = await _settings.readDoseCache();
    await _settings.writeDoseCache(
      DoseCache(
        schedule: cache.schedule,
        done: {...cache.done, ...pending.keys},
        pending: {
          for (final e in cache.pending.entries)
            if (!pending.containsKey(e.key)) e.key: e.value,
        },
      ),
    );
  }

  /// Marks [day]'s dose done now, from the app.
  Future<void> markDone(DateTime day) =>
      _health.apply((d) => _withDone(d, {dateOnly(day): now()}));

  void dispose() {
    _health.removeListener(_changed);
    _reminders
      ..removeListener(_changed)
      ..forgetDose();
  }
}

/// What "Taken" or "Done" on a notification does, with or without the app
/// open: the mark is kept on this phone and the reminders replanned.
Future<void> markDoseDone(
  SettingsStore settings,
  NotificationService notifications, {
  required DateTime day,
  required DateTime now,
}) async {
  final cache = await settings.readDoseCache();
  final marked = DoseCache(
    schedule: cache.schedule,
    done: cache.done,
    pending: {...cache.pending, dateOnly(day): now},
  );
  await settings.writeDoseCache(marked);
  await _replan(marked, notifications, now: now);
}

/// [data] with each day in [done] marked at its time, adding days not
/// logged yet.
HealthData _withDone(HealthData data, Map<DateTime, DateTime> done) {
  final logged = {for (final l in data.dailyLogs) l.date: l};
  return data.copyWith(
    dailyLogs: [
      for (final l in data.dailyLogs)
        if (done[l.date] case final at?)
          l.copyWith(contraceptionDoneAt: at)
        else
          l,
      for (final MapEntry(key: day, value: at) in done.entries)
        if (!logged.containsKey(day))
          DailyLog(date: day, contraceptionDoneAt: at),
    ],
  );
}

Future<void> _replan(
  DoseCache cache,
  NotificationService notifications, {
  required DateTime now,
}) async {
  await cancelContraceptionReminders(notifications);
  final schedule = cache.schedule;
  if (schedule == null) return;
  for (final r in contraceptionRemindersFor(
    schedule: schedule,
    now: now,
    done: cache.allDone,
  )) {
    await notifications.schedule(r.reminder);
  }
}

/// Signing out leaves no contraception reminder behind.
Future<void> cancelContraceptionReminders(
  NotificationService notifications,
) async {
  for (final id in contraceptionReminderIds) {
    await notifications.cancel(id);
  }
}
