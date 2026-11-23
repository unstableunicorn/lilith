// What the period form decides: which fields apply, whether they make sense
// together, and the one save that records the period and the usual lengths.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';

/// Why the form is open.
enum PeriodFormMode {
  /// "I'm in the middle of my period": a start, no end yet.
  midPeriod,

  /// "Not bleeding now": the last known period, start and end.
  pastPeriod,

  /// Changing a period already recorded.
  edit,
}

enum PeriodFormProblem { noFirstDay, endBeforeStart, cycleLength, periodLength }

class PeriodFormViewModel extends ChangeNotifier {
  PeriodFormViewModel(
    this._repo, {
    required this.mode,
    required this.now,
    PeriodEvent? editing,
  }) : _editing = editing,
       _firstDay = editing?.startDate,
       _lastDay = editing?.endDate,
       _flow = editing?.flow,
       _usualCycleLength = _repo.data.profile.usualCycleLength,
       _usualPeriodLength = _repo.data.profile.usualPeriodLength,
       _hormonalContraception = _repo.data.profile.treatments.contains(
         FertilityTreatment.contraceptive,
       );

  final HealthRepository _repo;
  final PeriodFormMode mode;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;
  final PeriodEvent? _editing;

  DateTime? _firstDay;
  DateTime? _lastDay;
  FlowIntensity? _flow;
  int? _usualCycleLength;
  int? _usualPeriodLength;
  bool _hormonalContraception;
  bool _saving = false;

  DateTime get today => dateOnly(now());
  DateTime? get firstDay => _firstDay;
  DateTime? get lastDay => _lastDay;
  FlowIntensity? get flow => _flow;
  int? get usualCycleLength => _usualCycleLength;
  int? get usualPeriodLength => _usualPeriodLength;
  bool get hormonalContraception => _hormonalContraception;
  bool get isSaving => _saving;
  RepositoryError? get error => _repo.error;

  /// A period still going has no last day to ask for.
  bool get asksLastDay => mode != PeriodFormMode.midPeriod;

  /// The usual lengths and contraception are first-time questions.
  bool get asksAboutYou => mode != PeriodFormMode.edit;

  /// The choices a period's flow can take: never "none".
  List<FlowIntensity> get flows =>
      FlowIntensity.values.where((f) => f != FlowIntensity.none).toList();

  List<PeriodFormProblem> get problems => [
    if (_firstDay == null) PeriodFormProblem.noFirstDay,
    if (_firstDay != null && _lastDay != null && _lastDay!.isBefore(_firstDay!))
      PeriodFormProblem.endBeforeStart,
    if (_usualCycleLength case final n?
        when n < HealthProfile.minCycleLength ||
            n > HealthProfile.maxCycleLength)
      PeriodFormProblem.cycleLength,
    if (_usualPeriodLength case final n?
        when n < HealthProfile.minPeriodLength ||
            n > HealthProfile.maxPeriodLength)
      PeriodFormProblem.periodLength,
  ];

  bool get canSave => problems.isEmpty && !_saving;

  void setFirstDay(DateTime day) => _edit(() => _firstDay = dateOnly(day));
  void setLastDay(DateTime? day) =>
      _edit(() => _lastDay = day == null ? null : dateOnly(day));
  void setFlow(FlowIntensity? f) => _edit(() => _flow = f);
  void setHormonalContraception(bool on) =>
      _edit(() => _hormonalContraception = on);

  /// Blank or not a number means not said.
  void setUsualCycleLength(String text) =>
      _edit(() => _usualCycleLength = int.tryParse(text.trim()));
  void setUsualPeriodLength(String text) =>
      _edit(() => _usualPeriodLength = int.tryParse(text.trim()));

  /// Records the period and, when asked, the usual lengths and contraception
  /// in one save. False when the form is not ready or the save failed.
  Future<bool> save() async {
    if (!canSave) return false;
    final period = PeriodEvent(
      startDate: _firstDay!,
      endDate: asksLastDay ? _lastDay : null,
      flow: _flow,
    );
    _saving = true;
    notifyListeners();
    try {
      await _repo.apply((d) {
        var next = d;
        if (_editing case final old? when old.startDate != period.startDate) {
          next = next.withoutPeriod(old.startDate);
        }
        next = next.withPeriod(period);
        if (asksAboutYou) {
          final profile = next.profile;
          final treatments = {...profile.treatments};
          if (_hormonalContraception) {
            treatments.add(FertilityTreatment.contraceptive);
          } else {
            treatments.remove(FertilityTreatment.contraceptive);
          }
          next = next.withProfile(
            profile.copyWith(
              treatments: treatments,
              usualCycleLength: _usualCycleLength,
              clearUsualCycleLength: _usualCycleLength == null,
              usualPeriodLength: _usualPeriodLength,
              clearUsualPeriodLength: _usualPeriodLength == null,
            ),
          );
        }
        return next;
      });
      return _repo.error == null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void clearError() => _repo.clearError();

  void _edit(void Function() change) {
    change();
    notifyListeners();
  }
}
