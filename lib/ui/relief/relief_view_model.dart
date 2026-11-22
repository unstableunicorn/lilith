// What the relief screen decides: which symptom is in view, its remedies in
// the order the user's own verdicts suggest, and what is on the list.

import 'package:flutter/foundation.dart';
import 'package:lilith/content/symptom_advice.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/shopping_item.dart';

class ReliefViewModel extends ChangeNotifier {
  ReliefViewModel(
    this._repo, {
    required this.now,
    this.content = symptomAdvice,
  }) {
    _repo.addListener(notifyListeners);
  }

  /// How far back a logged symptom counts as recent.
  static const int recentDays = 14;

  final HealthRepository _repo;
  final DateTime Function() now;
  final Map<Symptom, SymptomAdvice> content;

  Symptom? _chosen;

  bool get isLoaded => _repo.isLoaded;
  RepositoryError? get error => _repo.error;

  /// Symptoms logged in the last fortnight, the latest first.
  List<Symptom> get recent {
    final cutoff = addDays(dateOnly(now()), -recentDays);
    final seen = <Symptom>[];
    for (final log in _repo.data.dailyLogs.reversed) {
      if (log.date.isBefore(cutoff)) break;
      for (final s in log.symptoms) {
        if (!seen.contains(s)) seen.add(s);
      }
    }
    return seen;
  }

  /// Every symptom, the recent ones first.
  List<Symptom> get ordered => [
    ...recent,
    ...Symptom.values.where((s) => !recent.contains(s)),
  ];

  /// The symptom in view: the user's pick, else the latest logged, else cramps.
  Symptom get selected => _chosen ?? recent.firstOrNull ?? Symptom.cramps;

  SymptomAdvice get advice => content[selected]!;

  /// The remedies, those that helped first and those that did not last.
  List<Remedy> get remedies =>
      [...advice.remedies]
        ..sort((a, b) => ratingFor(b).rank.compareTo(ratingFor(a).rank));

  void select(Symptom symptom) {
    _chosen = symptom;
    notifyListeners();
  }

  RemedyRating ratingFor(Remedy r) =>
      _repo.data.ratingFor(selected.name, r.title);

  Future<void> toggleHelped(Remedy r) => _rate(r, RemedyRating.helped);

  Future<void> toggleDidNotHelp(Remedy r) => _rate(r, RemedyRating.didNotHelp);

  /// Sets [rating], or clears it when it is already set.
  Future<void> _rate(Remedy r, RemedyRating rating) {
    final symptom = selected;
    final next = ratingFor(r) == rating ? RemedyRating.untried : rating;
    return _repo.apply((d) => d.withRating(symptom.name, r.title, next));
  }

  /// Items still to buy, for the link to the list.
  int get toBuy => _repo.data.shopping.where((i) => !i.bought).length;

  bool isOnList(Remedy r) {
    final name = r.shopItem?.toLowerCase();
    return name != null &&
        _repo.data.shopping.any((s) => s.name.toLowerCase() == name);
  }

  Future<void> addToList(Remedy r) {
    final item = r.shopItem;
    if (item == null) return Future.value();
    final symptom = selected;
    return _repo.apply(
      (d) => d.withShoppingItem(
        ShoppingItem(
          name: item,
          note: 'For ${symptom.label}',
          symptomKey: symptom.name,
        ),
      ),
    );
  }

  void clearError() => _repo.clearError();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
