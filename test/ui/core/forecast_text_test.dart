import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/symptom_predictor.dart';
import 'package:lilith/ui/core/forecast_text.dart';

SymptomLikelihood symptom(Symptom s, double p) => SymptomLikelihood(
  symptom: s,
  probability: p,
  occurrences: 1,
  sampleDays: 2,
);

MoodLikelihood mood(Mood m, double p) =>
    MoodLikelihood(mood: m, probability: p, occurrences: 1, sampleDays: 2);

void main() {
  group('the sentence', () {
    test('counts the logged days and gives the typical pain', () {
      expect(
        forecastSummary(
          const SymptomForecast(likely: [], loggedDays: 6, typicalPain: 5.6),
        ),
        'From 6 logged days at this point of past cycles. '
        'Pain around 6/10 has been typical.',
      );
    });

    test('says nothing of pain when none was rated', () {
      expect(
        forecastSummary(const SymptomForecast(likely: [], loggedDays: 4)),
        'From 4 logged days at this point of past cycles.',
      );
    });

    test('for a follower the cycles are theirs', () {
      expect(
        forecastSummary(
          const SymptomForecast(likely: [], loggedDays: 6, typicalPain: 3),
          theirs: true,
        ),
        'From 6 logged days at this point of their past cycles. '
        'Pain around 3/10 has been typical.',
      );
    });
  });

  group('the badges', () {
    test('name each symptom with its chance, five at most', () {
      final f = SymptomForecast(
        loggedDays: 9,
        likely: [
          symptom(Symptom.cramps, 1),
          symptom(Symptom.backPain, 0.8),
          symptom(Symptom.fatigue, 0.7),
          symptom(Symptom.headache, 0.6),
          symptom(Symptom.nausea, 0.5),
          symptom(Symptom.cravings, 0.4),
        ],
      );
      expect(forecastSymptomBadges(f), [
        'Cramps 100%',
        'Back pain 80%',
        'Fatigue 70%',
        'Headache 60%',
        'Nausea 50%',
      ]);
      expect(maxForecastSymptoms, 5);
    });

    test('name each mood with its chance, three at most', () {
      final f = SymptomForecast(
        loggedDays: 9,
        likely: const [],
        likelyMoods: [
          mood(Mood.irritable, 0.55),
          mood(Mood.low, 0.5),
          mood(Mood.happy, 0.45),
          mood(Mood.calm, 0.4),
        ],
      );
      expect(forecastMoodBadges(f), ['Irritable 55%', 'Low 50%', 'Happy 45%']);
      expect(maxForecastMoods, 3);
    });

    test('none when nothing is likely', () {
      const f = SymptomForecast(likely: [], loggedDays: 2);
      expect(forecastSymptomBadges(f), isEmpty);
      expect(forecastMoodBadges(f), isEmpty);
    });
  });
}
