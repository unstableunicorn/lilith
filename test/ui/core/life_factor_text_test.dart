import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/ui/core/life_factor_text.dart';

void main() {
  final today = DateTime(2026, 4, 10);
  final start = DateTime(2026, 3, 20);

  CyclePrediction paused(LifeFactor f) => CyclePrediction(
    method: PredictionMethod.paused,
    confidence: PredictionConfidence.none,
    pausedBy: f,
  );
  LifeFactor of(LifeFactorKind kind, {DateTime? due, DateTime? end}) =>
      LifeFactor(kind: kind, start: start, dueDate: due, end: end);
  String? mine(CyclePrediction p) => pauseText(p, today: today);
  String? theirs(CyclePrediction p) => pauseText(p, today: today, theirs: true);

  group('pauseText', () {
    test('a prediction that is not on hold has none', () {
      const p = CyclePrediction(
        method: PredictionMethod.cycleAverage,
        confidence: PredictionConfidence.low,
      );
      expect(mine(p), isNull);
      expect(theirs(p), isNull);
      expect(
        mine(
          const CyclePrediction(
            method: PredictionMethod.insufficientData,
            confidence: PredictionConfidence.none,
          ),
        ),
        isNull,
      );
    });

    test('pregnant, with the due date when there is one', () {
      expect(
        mine(paused(of(LifeFactorKind.pregnant))),
        'Predictions are paused while you are pregnant.',
      );
      final due = paused(
        of(LifeFactorKind.pregnant, due: DateTime(2026, 12, 20)),
      );
      expect(
        mine(due),
        'Predictions are paused while you are pregnant. Your due date is '
        '20 Dec.',
      );
      expect(
        theirs(due),
        'Predictions are paused while they are pregnant. Their due date is '
        '20 Dec.',
      );
    });

    test('after a factor has ended, waits for a period', () {
      const p = CyclePrediction(
        method: PredictionMethod.awaitingPeriod,
        confidence: PredictionConfidence.none,
      );
      expect(mine(p), 'Predictions start again when you log your next period.');
      expect(theirs(p), 'Predictions start again with their next period.');
    });

    test('a follower of phases only is not told why', () {
      expect(phasesPausedText, 'Predictions are paused.');
    });
  });

  group('factorLine', () {
    String line(LifeFactor f) => factorLine(f, today: today);

    test('an open one says since when, and when the baby is due', () {
      expect(line(of(LifeFactorKind.pregnant)), 'Pregnant since 20 Mar');
      expect(
        line(of(LifeFactorKind.pregnant, due: DateTime(2026, 12, 20))),
        'Pregnant since 20 Mar, due 20 Dec',
      );
      expect(
        line(of(LifeFactorKind.breastfeeding)),
        'Breastfeeding since 20 Mar',
      );
    });

    test('an ended one gives both days, and no due date', () {
      expect(
        line(
          of(
            LifeFactorKind.pregnant,
            due: DateTime(2026, 12, 20),
            end: DateTime(2026, 4, 2),
          ),
        ),
        'Pregnant, 20 Mar to 2 Apr',
      );
    });

    test('breastfeeding that has ended gives both days', () {
      expect(
        line(of(LifeFactorKind.breastfeeding, end: DateTime(2026, 9, 2))),
        'Breastfeeding, 20 Mar to 2 Sep',
      );
    });

    test('another year is named', () {
      expect(
        factorLine(of(LifeFactorKind.pregnant), today: DateTime(2027, 1, 5)),
        'Pregnant since 20 Mar 2026',
      );
    });
  });
}
