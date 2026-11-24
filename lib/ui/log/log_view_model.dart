// What the log screen decides: which day, the draft for it, and whether the
// draft differs from what the pod holds.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
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
