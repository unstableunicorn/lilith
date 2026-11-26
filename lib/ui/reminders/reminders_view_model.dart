// What the reminders screen decides: the switch, the time as shown, and
// what to say when the device or the user said no.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lilith/content/dose_presets.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/health_profile.dart';

class RemindersViewModel extends ChangeNotifier {
  RemindersViewModel(this._repo, {this.health, this.now = DateTime.now}) {
    _repo.addListener(notifyListeners);
    // The user may have changed it in the system settings meanwhile.
    if (_repo.isAvailable) unawaited(_repo.checkExact());
  }

  final ReminderRepository _repo;

  /// Where a break is saved; null where no data is signed in.
  final HealthRepository? health;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  bool get isEnabled => _repo.setting.enabled;
  bool get isAvailable => _repo.isAvailable;
  int get hour => _repo.setting.hour;
  int get minute => _repo.setting.minute;

  /// The time as shown, "07:00".
  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// True once the system refused; the switch then stays off.
  bool get wasRefused => _repo.isAllowed == false;

  Future<void> setEnabled(bool on) async {
    await _repo.setEnabled(on);
    await _repo.checkExact();
  }

  /// Whether the period reminders are offered: not under hormonal
  /// contraception, where the bleed does not follow the prediction.
  bool get offersPeriod => _repo.periodApplies;
  bool get beforePeriod => _repo.setting.beforePeriod;
  bool get whenLate => _repo.setting.whenLate;
  int get daysBefore => _repo.setting.daysBefore;

  /// "2 days before", for the slider's label.
  String get daysBeforeText =>
      daysBefore == 1 ? '1 day before' : '$daysBefore days before';

  Future<void> setBeforePeriod(bool on) async {
    await _repo.setBeforePeriod(on);
    await _repo.checkExact();
  }

  Future<void> setWhenLate(bool on) async {
    await _repo.setWhenLate(on);
    await _repo.checkExact();
  }

  Future<void> setDaysBefore(int days) => _repo.setDaysBefore(days);

  Future<void> setTime({required int hour, required int minute}) =>
      _repo.setTime(hour: hour, minute: minute);

  /// Whether the pill, patch or ring card shows: the profile has one.
  bool get offersDose => dosePresetsFor(_repo.doseMethod).isNotEmpty;
  bool get doseOn => _repo.setting.contraception;

  /// "Your pill" or "Your patch or ring", for the card.
  String get doseTitle => _repo.doseMethod == Contraception.patchOrRing
      ? 'Your patch or ring'
      : 'Your pill';

  Future<void> setDoseOn(bool on) async {
    await _repo.setContraception(on);
    await _repo.checkExact();
  }

  /// The schedule set in the profile, if any.
  ContraceptionSchedule? get doseSchedule => _repo.doseSchedule;

  /// Whether "Start a 4-day break today" is offered: a schedule with no
  /// break, as flexible extended use needs.
  bool get offersBreak => doseSchedule?.daysOff == 0 && health != null;

  Future<void> startBreak() async {
    final today = now();
    await health?.apply((d) {
      final s = d.profile.contraceptionSchedule;
      if (s == null) return d;
      return d.copyWith(
        profile: d.profile.copyWith(contraceptionSchedule: s.startBreak(today)),
      );
    });
  }

  /// Whether to offer exact times: a reminder is on, and the system has not
  /// allowed them. Without them Android may show a reminder an hour or more
  /// late.
  bool get offersExact => _anyOn && _repo.exactAllowed == false;
  Future<void> requestExact() => _repo.requestExact();

  bool get _anyOn =>
      isEnabled || doseOn || (offersPeriod && (beforePeriod || whenLate));

  /// Shows a notification now, to see that they arrive.
  Future<void> sendTest() => _repo.sendTest();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
