// What the profile screen decides: the draft profile and whether it differs
// from the one on the pod.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/health_profile.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._repo) {
    _repo.addListener(notifyListeners);
    _draft = _repo.data.profile;
  }

  final HealthRepository _repo;
  late HealthProfile _draft;
  bool _saving = false;

  Set<ReproductiveCondition> get conditions => _draft.conditions;
  Set<FertilityTreatment> get treatments => _draft.treatments;
  String get notes => _draft.notes;
  bool get isSaving => _saving;
  RepositoryError? get error => _repo.error;

  HealthProfile get _trimmed => _draft.copyWith(notes: _draft.notes.trim());

  /// True when saving would change what the pod holds.
  bool get isDirty => _trimmed != _repo.data.profile;

  void toggleCondition(ReproductiveCondition c) => _edit(
    _draft.copyWith(
      conditions: conditions.contains(c)
          ? conditions.difference({c})
          : conditions.union({c}),
    ),
  );

  void toggleTreatment(FertilityTreatment t) => _edit(
    _draft.copyWith(
      treatments: treatments.contains(t)
          ? treatments.difference({t})
          : treatments.union({t}),
    ),
  );

  void setNotes(String text) => _edit(_draft.copyWith(notes: text));

  Contraception? get contraception => _draft.contraception;
  CycleRegularity? get regularity => _draft.regularity;
  int? get birthYear => _draft.birthYear;
  ObstetricHistory get history => _draft.history;

  /// Choosing the chosen one again clears it.
  void setContraception(Contraception? c) => _edit(
    c == null || c == _draft.contraception
        ? _draft.copyWith(unset: const {'contraception'})
        : _draft.copyWith(contraception: c),
  );

  void setRegularity(CycleRegularity? r) => _edit(
    r == null || r == _draft.regularity
        ? _draft.copyWith(unset: const {'regularity'})
        : _draft.copyWith(regularity: r),
  );

  /// Blank or not a number means not said.
  void setBirthYear(String text) {
    final year = int.tryParse(text.trim());
    _edit(
      year == null
          ? _draft.copyWith(unset: const {'birthYear'})
          : _draft.copyWith(birthYear: year),
    );
  }

  void setHistory(String field, String text) {
    final n = int.tryParse(text.trim());
    final h = _draft.history;
    _edit(
      _draft.copyWith(
        history: n == null
            ? h.copyWith(unset: {field})
            : switch (field) {
                'pregnancies' => h.copyWith(pregnancies: n),
                'births' => h.copyWith(births: n),
                'miscarriages' => h.copyWith(miscarriages: n),
                _ => h.copyWith(lastPregnancyYear: n),
              },
      ),
    );
  }

  Future<void> save() async {
    final profile = _trimmed;
    _saving = true;
    notifyListeners();
    try {
      await _repo.apply((d) => d.withProfile(profile));
      _draft = profile;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void clearError() => _repo.clearError();

  void _edit(HealthProfile draft) {
    _draft = draft;
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}

/// E.g. "2 conditions, no treatments, notes"; "Nothing recorded yet" if empty.
String profileSummary(HealthProfile p) {
  if (p.isEmpty) return 'Nothing recorded yet';
  String count(int n, String word) => switch (n) {
    0 => 'no ${word}s',
    1 => '1 $word',
    _ => '$n ${word}s',
  };
  final parts = [
    count(p.conditions.length, 'condition'),
    count(p.treatments.length, 'treatment'),
    if (p.contraception != null ||
        p.regularity != null ||
        p.birthYear != null ||
        !p.history.isEmpty)
      'history',
    if (p.notes.trim().isNotEmpty) 'notes',
  ];
  final text = parts.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}
