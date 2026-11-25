// What the reminders screen decides: the switch, the time as shown, and
// what to say when the device or the user said no.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/reminder_repository.dart';

class RemindersViewModel extends ChangeNotifier {
  RemindersViewModel(this._repo) {
    _repo.addListener(notifyListeners);
  }

  final ReminderRepository _repo;

  bool get isEnabled => _repo.setting.enabled;
  bool get isAvailable => _repo.isAvailable;
  int get hour => _repo.setting.hour;
  int get minute => _repo.setting.minute;

  /// The time as shown, "07:00".
  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// True once the system refused; the switch then stays off.
  bool get wasRefused => _repo.isAllowed == false;

  Future<void> setEnabled(bool on) => _repo.setEnabled(on);

  /// Whether the period reminders are offered: not under hormonal
  /// contraception, where the bleed does not follow the prediction.
  bool get offersPeriod => _repo.periodApplies;
  bool get beforePeriod => _repo.setting.beforePeriod;
  bool get whenLate => _repo.setting.whenLate;
  int get daysBefore => _repo.setting.daysBefore;

  /// "2 days before", for the slider's label.
  String get daysBeforeText =>
      daysBefore == 1 ? '1 day before' : '$daysBefore days before';

  Future<void> setBeforePeriod(bool on) => _repo.setBeforePeriod(on);
  Future<void> setWhenLate(bool on) => _repo.setWhenLate(on);
  Future<void> setDaysBefore(int days) => _repo.setDaysBefore(days);

  Future<void> setTime({required int hour, required int minute}) =>
      _repo.setTime(hour: hour, minute: minute);

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
