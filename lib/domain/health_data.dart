// Everything the app stores for a user, as one immutable value.
//
// Each `with…` method returns a new value with one change applied and the
// invariants kept: one reading, period or log per day, lists oldest first,
// no empty logs, one shopping item per name.

import 'package:collection/collection.dart';
import 'package:lillith/domain/daily_log.dart';
import 'package:lillith/domain/day.dart';
import 'package:lillith/domain/health_profile.dart';
import 'package:lillith/domain/period_event.dart';
import 'package:lillith/domain/remedy_feedback.dart';
import 'package:lillith/domain/shopping_item.dart';
import 'package:lillith/domain/temperature_reading.dart';

const _list = ListEquality<Object>();

/// The user's cycle data, remedy verdicts, shopping list and profile.
class HealthData {
  HealthData({
    Iterable<TemperatureReading> readings = const [],
    Iterable<PeriodEvent> periods = const [],
    Iterable<DailyLog> dailyLogs = const [],
    Iterable<RemedyFeedback> remedyFeedback = const [],
    Iterable<ShoppingItem> shopping = const [],
    HealthProfile? profile,
  }) : readings = List.unmodifiable(readings.sortedBy((r) => r.date)),
       periods = List.unmodifiable(periods.sortedBy((p) => p.startDate)),
       dailyLogs = List.unmodifiable(dailyLogs.sortedBy((l) => l.date)),
       remedyFeedback = List.unmodifiable(remedyFeedback),
       shopping = List.unmodifiable(
         shopping.sortedBy<num>((s) => s.bought ? 1 : 0),
       ),
       profile = profile ?? HealthProfile();

  static final HealthData empty = HealthData();

  /// Oldest first.
  final List<TemperatureReading> readings;

  /// Oldest first.
  final List<PeriodEvent> periods;

  /// Oldest first, no empty logs.
  final List<DailyLog> dailyLogs;

  final List<RemedyFeedback> remedyFeedback;

  /// Unbought items first.
  final List<ShoppingItem> shopping;

  final HealthProfile profile;

  /// True once any cycle data has been logged.
  bool get hasData =>
      readings.isNotEmpty || periods.isNotEmpty || dailyLogs.isNotEmpty;

  HealthData copyWith({
    Iterable<TemperatureReading>? readings,
    Iterable<PeriodEvent>? periods,
    Iterable<DailyLog>? dailyLogs,
    Iterable<RemedyFeedback>? remedyFeedback,
    Iterable<ShoppingItem>? shopping,
    HealthProfile? profile,
  }) => HealthData(
    readings: readings ?? this.readings,
    periods: periods ?? this.periods,
    dailyLogs: dailyLogs ?? this.dailyLogs,
    remedyFeedback: remedyFeedback ?? this.remedyFeedback,
    shopping: shopping ?? this.shopping,
    profile: profile ?? this.profile,
  );

  HealthData withReading(TemperatureReading reading) => withReadings([reading]);

  /// Adds or replaces the reading for each day in [imported].
  HealthData withReadings(Iterable<TemperatureReading> imported) {
    final byDay = {for (final r in readings) r.date: r};
    for (final r in imported) {
      byDay[r.date] = r;
    }
    return copyWith(readings: byDay.values);
  }

  HealthData withoutReading(DateTime date) {
    final day = dateOnly(date);
    return copyWith(readings: readings.where((r) => r.date != day));
  }

  HealthData withPeriod(PeriodEvent event) => copyWith(
    periods: [...periods.where((p) => p.startDate != event.startDate), event],
  );

  HealthData withoutPeriod(DateTime date) {
    final day = dateOnly(date);
    return copyWith(periods: periods.where((p) => p.startDate != day));
  }

  /// Replaces the day's log; an empty [log] removes the day.
  HealthData withDailyLog(DailyLog log) => copyWith(
    dailyLogs: [
      ...dailyLogs.where((l) => l.date != log.date),
      if (!log.isEmpty) log,
    ],
  );

  DailyLog? logFor(DateTime date) {
    final day = dateOnly(date);
    return dailyLogs.firstWhereOrNull((l) => l.date == day);
  }

  RemedyRating ratingFor(String symptomKey, String remedyTitle) {
    final id = RemedyFeedback.idFor(symptomKey, remedyTitle);
    return remedyFeedback.firstWhereOrNull((f) => f.id == id)?.rating ??
        RemedyRating.untried;
  }

  /// Records [rating]; [RemedyRating.untried] clears the verdict.
  HealthData withRating(
    String symptomKey,
    String remedyTitle,
    RemedyRating rating,
  ) {
    final id = RemedyFeedback.idFor(symptomKey, remedyTitle);
    return copyWith(
      remedyFeedback: [
        ...remedyFeedback.where((f) => f.id != id),
        if (rating != RemedyRating.untried)
          RemedyFeedback(
            symptomKey: symptomKey,
            remedyTitle: remedyTitle,
            rating: rating,
          ),
      ],
    );
  }

  /// Adds [item] unless an item of that name, in any case, is already listed.
  HealthData withShoppingItem(ShoppingItem item) {
    final name = item.name.toLowerCase();
    if (shopping.any((s) => s.name.toLowerCase() == name)) return this;
    return copyWith(shopping: [...shopping, item]);
  }

  HealthData toggleBought(String name) => copyWith(
    shopping: [
      for (final s in shopping)
        s.name == name ? s.copyWith(bought: !s.bought) : s,
    ],
  );

  HealthData withoutShoppingItem(String name) =>
      copyWith(shopping: shopping.where((s) => s.name != name));

  HealthData withProfile(HealthProfile profile) => copyWith(profile: profile);

  @override
  bool operator ==(Object other) =>
      other is HealthData &&
      _list.equals(other.readings, readings) &&
      _list.equals(other.periods, periods) &&
      _list.equals(other.dailyLogs, dailyLogs) &&
      _list.equals(other.remedyFeedback, remedyFeedback) &&
      _list.equals(other.shopping, shopping) &&
      other.profile == profile;

  @override
  int get hashCode => Object.hash(
    _list.hash(readings),
    _list.hash(periods),
    _list.hash(dailyLogs),
    _list.hash(remedyFeedback),
    _list.hash(shopping),
    profile,
  );
}
