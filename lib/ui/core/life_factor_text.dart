// How a life factor and the pause it causes are worded.

import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/ui/core/dates.dart';

/// Said to a follower who only sees phases, where the reason is not shared.
const String phasesPausedText = 'Predictions are paused.';

/// Why [prediction] gives no dates, or null when it is not on hold. With
/// [theirs], worded for someone following the person it is about.
String? pauseText(
  CyclePrediction prediction, {
  required DateTime today,
  bool theirs = false,
}) {
  if (!prediction.isOnHold) return null;
  final who = theirs ? 'they are' : 'you are';
  // Only a pregnancy pauses predictions, so that is what a pause names.
  return switch (prediction.pausedBy) {
    null when theirs => 'Predictions start again with their next period.',
    null => 'Predictions start again when you log your next period.',
    LifeFactor(:final dueDate) =>
      'Predictions are paused while $who pregnant.'
          '${dueDate == null ? '' : ' ${theirs ? 'Their' : 'Your'} due date '
                    'is ${formatShortDate(dueDate, today: today)}.'}',
  };
}

/// One line for [factor]: "Pregnant since 20 Mar, due 20 Dec",
/// "Breastfeeding, 20 Mar to 2 Sep".
String factorLine(LifeFactor factor, {required DateTime today}) {
  String day(DateTime d) => formatShortDate(d, today: today);
  final label = factor.kind.label;
  if (factor.end case final end?) {
    return '$label, ${day(factor.start)} to ${day(end)}';
  }
  final due = factor.dueDate;
  return '$label since ${day(factor.start)}'
      '${due == null ? '' : ', due ${day(due)}'}';
}
