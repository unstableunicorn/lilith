// What a forecast card says: its sentence and its badges, for the person
// tracking and for someone following them.

import 'package:lilith/domain/symptom_predictor.dart';

/// The most symptom badges a forecast card shows.
const int maxForecastSymptoms = 5;

/// The most mood badges a forecast card shows.
const int maxForecastMoods = 3;

/// E.g. "From 6 logged days at this point of past cycles. Pain around 6/10
/// has been typical."; of [theirs] when a follower reads it.
String forecastSummary(SymptomForecast f, {bool theirs = false}) {
  final pain = f.typicalPain;
  return 'From ${f.loggedDays} logged days at this point of '
      '${theirs ? 'their ' : ''}past cycles.'
      '${pain == null ? '' : ' Pain around ${pain.round()}/10 '
                'has been typical.'}';
}

/// "Cramps 60%", most likely first.
List<String> forecastSymptomBadges(SymptomForecast f) => [
  for (final l in f.likely.take(maxForecastSymptoms))
    '${l.symptom.label} ${l.percent}%',
];

/// "Irritable 55%", most likely first.
List<String> forecastMoodBadges(SymptomForecast f) => [
  for (final l in f.likelyMoods.take(maxForecastMoods))
    '${l.mood.label} ${l.percent}%',
];
