// One line saying what a day's log holds, for lists and the home screen.

import 'package:lilith/domain/daily_log.dart';

/// E.g. "medium flow, cramps, fatigue, pain 4/10"; "nothing logged" when empty.
String logSummary(DailyLog log) {
  final parts = [
    if (log.flow.isBleeding) '${log.flow.name} flow',
    for (final s in Symptom.values.where(log.symptoms.contains))
      s.label.toLowerCase(),
    if (log.painLevel case final pain?) 'pain $pain/10',
    if (log.ovulationTest case final t?) 'ovulation test ${t.name}',
    ...log.signs.summaryParts,
  ];
  return parts.isEmpty ? 'nothing logged' : parts.join(', ');
}
