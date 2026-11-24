import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/ui/log/log_summary.dart';

void main() {
  final day = DateTime(2026, 5, 2);

  final cases = [
    (name: 'an empty day', log: DailyLog(date: day), want: 'nothing logged'),
    (
      name: 'flow, symptoms and pain',
      log: DailyLog(
        date: day,
        flow: FlowIntensity.medium,
        symptoms: const {Symptom.fatigue, Symptom.cramps},
        painLevel: 4,
      ),
      want: 'medium flow, cramps, fatigue, pain 4/10',
    ),
    (
      name: 'a positive ovulation test',
      log: DailyLog(date: day, ovulationTest: OvulationTest.positive),
      want: 'ovulation test positive',
    ),
    (
      name: 'a negative ovulation test after pain',
      log: DailyLog(
        date: day,
        painLevel: 2,
        ovulationTest: OvulationTest.negative,
      ),
      want: 'pain 2/10, ovulation test negative',
    ),
  ];
  for (final c in cases) {
    test(c.name, () => expect(logSummary(c.log), c.want));
  }
}
