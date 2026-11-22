import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  final may1 = DateTime(2026, 5, 1);
  final may2 = DateTime(2026, 5, 2);
  TemperatureReading reading(DateTime d, double c) =>
      TemperatureReading(date: d, celsius: c);

  test('empty has nothing and is not data', () {
    expect(HealthData.empty.hasData, isFalse);
    expect(HealthData.empty.readings, isEmpty);
    expect(HealthData.empty.profile, HealthProfile());
  });

  test('a profile alone is not cycle data', () {
    final d = HealthData.empty.withProfile(
      HealthProfile(conditions: {ReproductiveCondition.pcos}),
    );
    expect(d.hasData, isFalse);
    expect(d.profile.conditions, {ReproductiveCondition.pcos});
  });

  test('collections cannot be changed from outside', () {
    final d = HealthData.empty.withReading(reading(may1, 36.4));
    expect(() => d.readings.clear(), throwsUnsupportedError);
    expect(
      () => d.shopping.add(const ShoppingItem(name: 'x')),
      throwsUnsupportedError,
    );
  });

  test('is equal by value', () {
    final a = HealthData.empty
        .withReading(reading(may1, 36.4))
        .withPeriod(PeriodEvent(startDate: may1));
    final b = HealthData.empty
        .withPeriod(PeriodEvent(startDate: may1))
        .withReading(reading(may1, 36.4));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(a.withReading(reading(may2, 36.5))));
  });

  group('readings', () {
    test('one per day: a second reading replaces the first', () {
      final d = HealthData.empty
          .withReading(reading(may1, 36.4))
          .withReading(reading(DateTime(2026, 5, 1, 8), 36.6));
      expect(d.readings, [reading(may1, 36.6)]);
      expect(d.hasData, isTrue);
    });

    test('are kept oldest first', () {
      final d = HealthData.empty
          .withReading(reading(may2, 36.5))
          .withReading(reading(may1, 36.4));
      expect(d.readings.map((r) => r.date), [may1, may2]);
    });

    test('can be removed by day', () {
      final d = HealthData.empty
          .withReading(reading(may1, 36.4))
          .withoutReading(DateTime(2026, 5, 1, 23));
      expect(d.readings, isEmpty);
    });

    test('merge imports many at once, replacing same-day values', () {
      final d = HealthData.empty.withReading(reading(may1, 36.4)).withReadings([
        reading(may1, 36.7),
        reading(may2, 36.5),
      ]);
      expect(d.readings, [reading(may1, 36.7), reading(may2, 36.5)]);
    });
  });

  group('periods', () {
    test('one per day, oldest first, removable', () {
      final d = HealthData.empty
          .withPeriod(PeriodEvent(startDate: may2))
          .withPeriod(PeriodEvent(startDate: may1))
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 1, 6)));
      expect(d.periods.map((p) => p.startDate), [may1, may2]);
      expect(d.withoutPeriod(may1).periods.map((p) => p.startDate), [may2]);
    });
  });

  group('daily logs', () {
    test('one per day, oldest first', () {
      final d = HealthData.empty
          .withDailyLog(DailyLog(date: may2, flow: FlowIntensity.light))
          .withDailyLog(DailyLog(date: may1, flow: FlowIntensity.heavy))
          .withDailyLog(DailyLog(date: may1, flow: FlowIntensity.medium));
      expect(d.dailyLogs.map((l) => l.flow), [
        FlowIntensity.medium,
        FlowIntensity.light,
      ]);
    });

    test('an empty log removes the day', () {
      final d = HealthData.empty
          .withDailyLog(DailyLog(date: may1, flow: FlowIntensity.heavy))
          .withDailyLog(DailyLog(date: may1));
      expect(d.dailyLogs, isEmpty);
    });

    test('logFor finds the day or nothing', () {
      final d = HealthData.empty.withDailyLog(
        DailyLog(date: may1, painLevel: 4),
      );
      expect(d.logFor(DateTime(2026, 5, 1, 12))?.painLevel, 4);
      expect(d.logFor(may2), isNull);
    });
  });

  group('remedy ratings', () {
    test('unrated remedies are untried', () {
      expect(
        HealthData.empty.ratingFor('cramps', 'Heat pack'),
        RemedyRating.untried,
      );
    });

    test('a rating is stored per symptom and remedy', () {
      final d = HealthData.empty.withRating(
        'cramps',
        'Heat pack',
        RemedyRating.helped,
      );
      expect(d.ratingFor('cramps', 'Heat pack'), RemedyRating.helped);
      expect(d.ratingFor('bloating', 'Heat pack'), RemedyRating.untried);
      expect(d.remedyFeedback.single.rating, RemedyRating.helped);
    });

    test('rating untried clears the verdict', () {
      final d = HealthData.empty
          .withRating('cramps', 'Heat pack', RemedyRating.didNotHelp)
          .withRating('cramps', 'Heat pack', RemedyRating.untried);
      expect(d.remedyFeedback, isEmpty);
    });
  });

  group('shopping', () {
    const heat = ShoppingItem(name: 'Heat pack');

    test('adding the same name again, in any case, changes nothing', () {
      final d = HealthData.empty
          .withShoppingItem(heat)
          .withShoppingItem(
            const ShoppingItem(name: 'heat PACK', note: 'again'),
          );
      expect(d.shopping, [heat]);
    });

    test('bought toggles by name and unknown names are ignored', () {
      final d = HealthData.empty
          .withShoppingItem(heat)
          .toggleBought('Heat pack');
      expect(d.shopping.single.bought, isTrue);
      expect(d.toggleBought('Heat pack').shopping.single.bought, isFalse);
      expect(d.toggleBought('Tea'), d);
    });

    test('unbought items come first', () {
      final d = HealthData.empty
          .withShoppingItem(heat)
          .withShoppingItem(const ShoppingItem(name: 'Tea'))
          .toggleBought('Heat pack');
      expect(d.shopping.map((s) => s.name), ['Tea', 'Heat pack']);
    });

    test('items are removed by name', () {
      expect(
        HealthData.empty
            .withShoppingItem(heat)
            .withoutShoppingItem('Heat pack')
            .shopping,
        isEmpty,
      );
    });
  });
}
