// What the log screen decides: which day, the draft for it, and whether the
// draft differs from what the pod holds.

import 'package:flutter/foundation.dart';
import 'package:lilith/content/dose_presets.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/core/dates.dart';

class LogViewModel extends ChangeNotifier {
  LogViewModel(this._repo, {required this.now, DateTime? date}) {
    _repo.addListener(notifyListeners);
    _date = _clamp(date ?? today);
    _draft = _stored;
  }

  final HealthRepository _repo;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  late DateTime _date;
  late DailyLog _draft;
  bool _saving = false;

  DateTime get today => dateOnly(now());
  DateTime get date => _date;
  FlowIntensity get flow => _draft.flow;
  Set<Symptom> get symptoms => _draft.symptoms;
  int? get pain => _draft.painLevel;
  OvulationTest? get ovulationTest => _draft.ovulationTest;
  String? get note => _draft.note;
  bool get isEmpty => _draft.isEmpty;
  bool get isSaving => _saving;
  RepositoryError? get error => _repo.error;
  bool get canGoForward => _date.isBefore(today);

  DailyLog get _stored => _repo.data.logFor(_date) ?? DailyLog(date: _date);

  /// True when saving would change what the pod holds.
  bool get isDirty => _draft != _stored;

  /// True when the pod holds exactly this non-empty draft.
  bool get isSavedAsIs => !isDirty && !isEmpty;

  /// E.g. "Wed 10 Jun 2026".
  String get dateLabel => formatDay(_date);

  void goBack() => pickDate(addDays(_date, -1));
  void goForward() => pickDate(addDays(_date, 1));

  /// Moves to [day], no later than today, and starts from what is logged there.
  void pickDate(DateTime day) {
    _date = _clamp(day);
    _draft = _stored;
    notifyListeners();
  }

  void setFlow(FlowIntensity flow) => _edit(_draft.copyWith(flow: flow));

  void toggleSymptom(Symptom symptom) => _edit(
    _draft.copyWith(
      symptoms: _draft.symptoms.contains(symptom)
          ? _draft.symptoms.difference({symptom})
          : _draft.symptoms.union({symptom}),
    ),
  );

  /// Rates pain 0–10, or unrates it with null.
  void setPain(int? level) => _edit(
    level == null
        ? _draft.copyWith(clearPain: true)
        : _draft.copyWith(painLevel: level),
  );

  /// Records the day's ovulation test, or none with null.
  void setOvulationTest(OvulationTest? result) => _edit(
    result == null
        ? _draft.copyWith(clearOvulationTest: true)
        : _draft.copyWith(ovulationTest: result),
  );

  /// The day's moods and body signs.
  BodySigns get signs => _draft.signs;

  /// Whether [group] has a section: it is switched on, or the day already
  /// holds something in it, so nothing logged is ever out of reach.
  bool shows(LogGroup group) =>
      _repo.data.shownLogGroups.contains(group) ||
      _holds(_draft.signs, group) ||
      _holds(_stored.signs, group);

  bool _holds(BodySigns signs, LogGroup group) => switch (group) {
    LogGroup.moods => signs.moods.isNotEmpty,
    LogGroup.sleep => signs.sleep != null,
    LogGroup.digestion => signs.digestion.isNotEmpty,
    LogGroup.skin => signs.skin.isNotEmpty,
    LogGroup.discharge => signs.discharge != null,
    LogGroup.pregnancyTest => signs.pregnancyTest != null,
  };

  void _sign(BodySigns signs) => _edit(_draft.copyWith(signs: signs));

  Set<T> _toggled<T>(Set<T> all, T one) =>
      all.contains(one) ? all.difference({one}) : all.union({one});

  void toggleMood(Mood mood) =>
      _sign(signs.copyWith(moods: _toggled(signs.moods, mood)));
  void toggleDigestion(Digestion sign) =>
      _sign(signs.copyWith(digestion: _toggled(signs.digestion, sign)));
  void toggleSkin(SkinSign sign) =>
      _sign(signs.copyWith(skin: _toggled(signs.skin, sign)));

  /// Each records the day's one value, or none with null.
  void setSleep(SleepQuality? sleep) =>
      _sign(signs.copyWith(sleep: sleep, clearSleep: sleep == null));
  void setDischarge(Discharge? discharge) => _sign(
    signs.copyWith(discharge: discharge, clearDischarge: discharge == null),
  );
  void setPregnancyTest(PregnancyTest? result) => _sign(
    signs.copyWith(pregnancyTest: result, clearPregnancyTest: result == null),
  );

  /// The day's note as typed; blank removes it.
  void setNote(String text) => _edit(
    text.trim().isEmpty
        ? _draft.copyWith(clearNote: true)
        : _draft.copyWith(note: text),
  );

  /// Whether the day asks about the pill, patch or ring: the profile has
  /// one, and its schedule, if set, has something due that day.
  bool get offersDose {
    final profile = _repo.data.profile;
    if (dosePresetsFor(profile.contraception).isEmpty) return false;
    final schedule = profile.contraceptionSchedule;
    return schedule == null || schedule.stepOn(_date) != null;
  }

  /// True for a patch or ring, which are "done" rather than "taken".
  bool get doseIsPatchOrRing =>
      _repo.data.profile.contraception == Contraception.patchOrRing;

  bool get doseDone => _draft.contraceptionDoneAt != null;

  /// Marks the day's dose done, today at this moment and an earlier day at
  /// the schedule's time, or not.
  void setDoseDone(bool done) {
    if (!done) return _edit(_draft.copyWith(clearContraceptionDone: true));
    final s = _repo.data.profile.contraceptionSchedule;
    final at = _date == today
        ? now()
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            s?.hour ?? ContraceptionSchedule.defaultHour,
            s?.minute ?? 0,
          );
    _edit(_draft.copyWith(contraceptionDoneAt: at));
  }

  void clear() => _edit(DailyLog(date: _date));

  /// Writes the draft; an empty draft removes the day.
  Future<void> save() async {
    final draft = _draft;
    _saving = true;
    notifyListeners();
    try {
      await _repo.apply((d) => d.withLoggedDay(draft));
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void clearError() => _repo.clearError();

  void _edit(DailyLog draft) {
    _draft = draft;
    notifyListeners();
  }

  DateTime _clamp(DateTime day) {
    final d = dateOnly(day);
    return d.isAfter(today) ? today : d;
  }

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
