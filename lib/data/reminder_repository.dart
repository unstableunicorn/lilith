// The daily reminder for this device: what is set, whether the device can
// show it, and keeping the schedule in step with the setting.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/reminder_setting.dart';

class ReminderRepository extends ChangeNotifier {
  ReminderRepository(
    this._settings,
    this._notifications, {
    this.now = DateTime.now,
  });

  final SettingsStore _settings;
  final NotificationService _notifications;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  ReminderSetting _setting = const ReminderSetting();
  bool? _allowed;
  bool _loaded = false;

  bool _periodApplies = false;

  ReminderSetting get setting => _setting;
  bool get isLoaded => _loaded;

  /// Whether period reminders make sense for the data signed in: false
  /// until it loads, and under hormonal contraception.
  bool get periodApplies => _periodApplies;

  set periodApplies(bool value) {
    if (value == _periodApplies) return;
    _periodApplies = value;
    notifyListeners();
  }

  /// [periodApplies] off without notifying, for the signed-in scope to call
  /// while it unmounts and nothing that shows it can be on screen.
  void forgetPeriod() => _periodApplies = false;

  Contraception? _doseMethod;
  ContraceptionSchedule? _doseSchedule;

  /// The contraception in the profile signed in, and its schedule, for the
  /// reminders screen; null until the data loads.
  Contraception? get doseMethod => _doseMethod;
  ContraceptionSchedule? get doseSchedule => _doseSchedule;

  void setDose(Contraception? method, ContraceptionSchedule? schedule) {
    if (method == _doseMethod && schedule == _doseSchedule) return;
    _doseMethod = method;
    _doseSchedule = schedule;
    notifyListeners();
  }

  /// [setDose] cleared without notifying, as [forgetPeriod].
  void forgetDose() {
    _doseMethod = null;
    _doseSchedule = null;
  }

  /// Turns the pill, patch or ring reminders on, asking the system first,
  /// or off.
  Future<void> setContraception(bool on) =>
      _setFromData(on, (s, v) => s.copyWith(contraception: v));

  bool? _exactAllowed;

  /// Whether reminders can be shown on the minute; null until asked.
  bool? get exactAllowed => _exactAllowed;

  /// Reads [exactAllowed] from the system.
  Future<void> checkExact() async {
    _exactAllowed = await _notifications.canScheduleExact();
    notifyListeners();
  }

  /// Opens the system setting for exact alarms, then reads it again.
  Future<void> requestExact() async {
    _exactAllowed = await _notifications.requestExact();
    notifyListeners();
  }

  /// Whether this device can show reminders at all (not on the web).
  bool get isAvailable => _notifications.isAvailable;

  /// What the system answered when asked; null until asked.
  bool? get isAllowed => _allowed;

  /// Reads the setting and, when on, schedules the reminder again so a
  /// reinstall or a reboot that lost it gets it back.
  Future<void> load() async {
    _setting = await _settings.readReminder();
    _loaded = true;
    if (_setting.enabled) await _apply();
    notifyListeners();
  }

  /// [load] with nothing to wait for, for a provider's create.
  void loadLater() => unawaited(load());

  /// Turns the reminder on, asking the system the first time, or off.
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      _allowed = await _notifications.requestPermission();
      if (_allowed == false) {
        _setting = _setting.copyWith(enabled: false);
        await _settings.writeReminder(_setting);
        notifyListeners();
        return;
      }
    }
    _setting = _setting.copyWith(enabled: enabled);
    await _settings.writeReminder(_setting);
    await _apply();
    notifyListeners();
  }

  /// Turns the reminders before a period on, asking the system first, or off.
  Future<void> setBeforePeriod(bool on) =>
      _setFromData(on, (s, v) => s.copyWith(beforePeriod: v));

  /// Turns the reminders for a late period on, asking first, or off.
  Future<void> setWhenLate(bool on) =>
      _setFromData(on, (s, v) => s.copyWith(whenLate: v));

  Future<void> setDaysBefore(int days) async {
    _setting = _setting.copyWith(
      daysBefore: days.clamp(
        ReminderSetting.minDaysBefore,
        ReminderSetting.maxDaysBefore,
      ),
    );
    await _settings.writeReminder(_setting);
    notifyListeners();
  }

  // These are scheduled from the data, by the period and contraception
  // reminder repositories, which listen here.
  Future<void> _setFromData(
    bool on,
    ReminderSetting Function(ReminderSetting s, bool on) change,
  ) async {
    if (on) _allowed = await _notifications.requestPermission();
    _setting = change(_setting, on && _allowed != false);
    await _settings.writeReminder(_setting);
    notifyListeners();
  }

  Future<void> setTime({required int hour, required int minute}) async {
    _setting = _setting.copyWith(hour: hour, minute: minute);
    await _settings.writeReminder(_setting);
    if (_setting.enabled) await _apply();
    notifyListeners();
  }

  Future<void> _apply() async {
    if (_setting.enabled && isAvailable) {
      await _notifications.scheduleDaily(_setting.reminderAfter(now()));
    } else {
      await _notifications.cancel(dailyReminderId);
    }
  }
}
