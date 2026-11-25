// What the schedule setup decides: the method, the regimen or custom days,
// the start, the time, the window and quiet hours, and saving them.

import 'package:flutter/foundation.dart';
import 'package:lilith/content/dose_presets.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/day.dart';

class DoseScheduleViewModel extends ChangeNotifier {
  DoseScheduleViewModel(this._health, {this.now = DateTime.now}) {
    final existing = _health.data.profile.contraceptionSchedule;
    final index = existing == null
        ? 0
        : presets.indexWhere(
            (p) =>
                p.form == existing.form &&
                (presets.length == 1 ||
                    p.form != DoseForm.pill ||
                    p.windowHours == existing.windowHours),
          );
    _presetIndex = index < 0 ? 0 : index;
    final p = preset;
    _windowHours = existing?.windowHours ?? p?.windowHours ?? 24;
    _start = existing?.start ?? dateOnly(now());
    _hour = existing?.hour ?? ContraceptionSchedule.defaultHour;
    _minute = existing?.minute ?? 0;
    _quietHours = existing?.quietHours ?? false;
    if (existing != null) {
      _daysOn = existing.daysOn;
      _daysOff = existing.daysOff;
      _regimen = Regimen.values.firstWhereOrNullBy(existing);
    } else if (p != null) {
      chooseRegimen(p.regimens.first);
    }
  }

  final HealthRepository _health;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  late int _presetIndex;
  Regimen? _regimen;
  int _daysOn = 21;
  int _daysOff = 0;
  late DateTime _start;
  late int _hour;
  late int _minute;
  late int _windowHours;
  late bool _quietHours;
  bool _isSaving = false;

  /// The presets for the profile's method.
  List<DosePreset> get presets =>
      dosePresetsFor(_health.data.profile.contraception);
  DosePreset? get preset => presets.isEmpty ? null : presets[_presetIndex];
  int get presetIndex => _presetIndex;

  /// The chosen regimen; null for custom days.
  Regimen? get regimen => _regimen;
  int get daysOn => _daysOn;
  int get daysOff => _daysOff;
  DateTime get start => _start;
  int get hour => _hour;
  int get minute => _minute;
  int get windowHours => _windowHours;
  bool get quietHours => _quietHours;
  bool get isSaving => _isSaving;

  /// The longest window offered, in hours.
  static const int maxWindowHours = 72;

  void choosePreset(int index) {
    if (index < 0 || index >= presets.length) return;
    _presetIndex = index;
    _windowHours = presets[index].windowHours;
    chooseRegimen(presets[index].regimens.first);
  }

  void chooseRegimen(Regimen? regimen) {
    _regimen = regimen;
    if (regimen != null) {
      _daysOn = regimen.daysOn;
      _daysOff = regimen.daysOff;
    }
    notifyListeners();
  }

  void setDaysOn(int days) {
    _daysOn = days < 1 ? 1 : days;
    notifyListeners();
  }

  void setDaysOff(int days) {
    _daysOff = days < 0 ? 0 : days;
    notifyListeners();
  }

  void setStart(DateTime day) {
    _start = dateOnly(day);
    notifyListeners();
  }

  void setTime({required int hour, required int minute}) {
    _hour = hour;
    _minute = minute;
    notifyListeners();
  }

  void setWindowHours(int hours) {
    _windowHours = hours.clamp(1, maxWindowHours);
    notifyListeners();
  }

  void setQuietHours(bool on) {
    _quietHours = on;
    notifyListeners();
  }

  /// Writes the schedule to the profile; true when it was saved.
  Future<bool> save() async {
    final p = preset;
    if (p == null) return false;
    _isSaving = true;
    notifyListeners();
    final schedule = ContraceptionSchedule(
      form: p.form,
      start: _start,
      daysOn: _daysOn,
      daysOff: _daysOff,
      windowHours: _windowHours,
      hour: _hour,
      minute: _minute,
      quietHours: _quietHours,
    );
    await _health.apply(
      (d) => d.copyWith(
        profile: d.profile.copyWith(contraceptionSchedule: schedule),
      ),
    );
    _isSaving = false;
    notifyListeners();
    return _health.error == null;
  }
}

extension on List<Regimen> {
  /// The regimen whose days match [s], or null for custom days.
  Regimen? firstWhereOrNullBy(ContraceptionSchedule s) {
    for (final r in this) {
      if (r.daysOn == s.daysOn && r.daysOff == s.daysOff) return r;
    }
    return null;
  }
}
