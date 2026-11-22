// The user's verdict on a relief suggestion, so what worked for them ranks first.

/// Whether a remedy helped. [untried] is never stored: it is the absence of a
/// verdict.
enum RemedyRating {
  untried,
  helped,
  didNotHelp;

  /// Sort weight: helped first, untried next, unhelpful last.
  int get rank => switch (this) {
    RemedyRating.helped => 2,
    RemedyRating.untried => 1,
    RemedyRating.didNotHelp => 0,
  };

  /// The stored name's value, or [untried] when unknown or missing.
  static RemedyRating fromName(String? name) => RemedyRating.values.firstWhere(
    (r) => r.name == name,
    orElse: () => RemedyRating.untried,
  );
}

/// One verdict on one remedy for one symptom.
class RemedyFeedback {
  const RemedyFeedback({
    required this.symptomKey,
    required this.remedyTitle,
    required this.rating,
  });

  factory RemedyFeedback.fromJson(Map<String, dynamic> json) => RemedyFeedback(
    symptomKey: json['symptom'] as String,
    remedyTitle: json['remedy'] as String,
    rating: RemedyRating.fromName(json['rating'] as String?),
  );

  /// The [Symptom.name] the remedy belongs to.
  final String symptomKey;

  /// The remedy's title, its identity within a symptom.
  final String remedyTitle;

  final RemedyRating rating;

  /// The key this verdict is stored under.
  String get id => idFor(symptomKey, remedyTitle);

  static String idFor(String symptomKey, String remedyTitle) =>
      '$symptomKey::$remedyTitle';

  Map<String, dynamic> toJson() => {
    'symptom': symptomKey,
    'remedy': remedyTitle,
    'rating': rating.name,
  };

  @override
  bool operator ==(Object other) =>
      other is RemedyFeedback &&
      other.symptomKey == symptomKey &&
      other.remedyTitle == remedyTitle &&
      other.rating == rating;

  @override
  int get hashCode => Object.hash(symptomKey, remedyTitle, rating);
}
