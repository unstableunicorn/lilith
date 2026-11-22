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
    if (p.notes.trim().isNotEmpty) 'notes',
  ];
  final text = parts.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}
