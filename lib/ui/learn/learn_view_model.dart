// What the learn screen decides: the answer to the question asked, if the
// knowledge base has one, the cycle's phases and the facts.

import 'package:flutter/foundation.dart';
import 'package:lilith/content/cycle_phases.dart';
import 'package:lilith/content/period_facts.dart';

class LearnViewModel extends ChangeNotifier {
  LearnViewModel({
    this.entries = knowledgeBase,
    this.facts = periodFacts,
    this.phases = cyclePhaseEntries,
  });

  final List<KnowledgeEntry> entries;
  final List<PeriodFact> facts;
  final List<CyclePhaseEntry> phases;

  bool _asked = false;
  KnowledgeEntry? _answer;

  /// True once a non-blank question has been asked.
  bool get asked => _asked;

  /// The best entry for the last question, or null when nothing matched.
  KnowledgeEntry? get answer => _answer;

  void ask(String question) {
    if (question.trim().isEmpty) {
      _asked = false;
      _answer = null;
    } else {
      _asked = true;
      _answer = bestEntryFor(question, entries);
    }
    notifyListeners();
  }
}

/// The entry scoring highest for [question], or null when none scores.
KnowledgeEntry? bestEntryFor(String question, List<KnowledgeEntry> entries) {
  KnowledgeEntry? best;
  var bestScore = 0;
  for (final entry in entries) {
    final score = entry.scoreFor(question);
    if (score > bestScore) {
      bestScore = score;
      best = entry;
    }
  }
  return best;
}

/// The fact for [day], turning daily through the list.
PeriodFact factOfTheDay(DateTime day) {
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return periodFacts[dayOfYear % periodFacts.length];
}
