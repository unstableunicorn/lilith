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

  Future<void> setTime({required int hour, required int minute}) =>
      _repo.setTime(hour: hour, minute: minute);

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
