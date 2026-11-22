import 'package:flutter_test/flutter_test.dart';
import 'package:lillith/domain/remedy_feedback.dart';

void main() {
  group('RemedyRating', () {
    test('ranks helped above untried above did-not-help', () {
      expect(RemedyRating.helped.rank, greaterThan(RemedyRating.untried.rank));
      expect(
        RemedyRating.untried.rank,
        greaterThan(RemedyRating.didNotHelp.rank),
      );
    });

    final cases = <({String name, String? input, RemedyRating want})>[
      (name: 'known name', input: 'didNotHelp', want: RemedyRating.didNotHelp),
      (
        name: 'unknown falls back to untried',
        input: 'meh',
        want: RemedyRating.untried,
      ),
      (
        name: 'missing falls back to untried',
        input: null,
        want: RemedyRating.untried,
      ),
    ];
    for (final c in cases) {
      test(
        'fromName: ${c.name}',
        () => expect(RemedyRating.fromName(c.input), c.want),
      );
    }
  });

  group('RemedyFeedback', () {
    const fb = RemedyFeedback(
      symptomKey: 'cramps',
      remedyTitle: 'Heat pack',
      rating: RemedyRating.helped,
    );

    test('its id pairs symptom and remedy', () {
      expect(fb.id, RemedyFeedback.idFor('cramps', 'Heat pack'));
      expect(fb.id, isNot(RemedyFeedback.idFor('bloating', 'Heat pack')));
    });

    test('is equal by value', () {
      const same = RemedyFeedback(
        symptomKey: 'cramps',
        remedyTitle: 'Heat pack',
        rating: RemedyRating.helped,
      );
      const other = RemedyFeedback(
        symptomKey: 'cramps',
        remedyTitle: 'Heat pack',
        rating: RemedyRating.didNotHelp,
      );
      expect(fb, same);
      expect(fb.hashCode, same.hashCode);
      expect(fb, isNot(other));
    });

    test('round-trips through JSON', () {
      expect(RemedyFeedback.fromJson(fb.toJson()), fb);
    });

    test('reads the document shape the original app wrote', () {
      final got = RemedyFeedback.fromJson({
        'symptom': 'cramps',
        'remedy': 'Heat pack',
        'rating': 'helped',
      });
      expect(got, fb);
    });
  });
}
