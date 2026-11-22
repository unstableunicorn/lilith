// Everything the app stores for a user, as one immutable value.
//
// Each `with…` method returns a new value with one change applied and the
// invariants kept: one reading, period or log per day, lists oldest first,
// no empty logs, one shopping item per name.

import 'package:collection/collection.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/domain/temperature_reading.dart';

const _list = ListEquality<Object>();

/// The user's cycle data, remedy verdicts, shopping list, profile and shares.
class HealthData {
  HealthData({
    Iterable<TemperatureReading> readings = const [],
    Iterable<PeriodEvent> periods = const [],
    Iterable<DailyLog> dailyLogs = const [],
    Iterable<RemedyFeedback> remedyFeedback = const [],
    Iterable<ShoppingItem> shopping = const [],
    HealthProfile? profile,
    Iterable<Share> shares = const [],
    Iterable<ReceivedShare> received = const [],
  }) : readings = List.unmodifiable(readings.sortedBy((r) => r.date)),
       periods = List.unmodifiable(periods.sortedBy((p) => p.startDate)),
       dailyLogs = List.unmodifiable(dailyLogs.sortedBy((l) => l.date)),
       remedyFeedback = List.unmodifiable(remedyFeedback),
       shopping = List.unmodifiable(
         shopping.sortedBy<num>((s) => s.bought ? 1 : 0),
       ),
       profile = profile ?? HealthProfile(),
       shares = List.unmodifiable(shares),
       received = List.unmodifiable(received);

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

  /// Who the cycle data is shared with, one share per recipient.
  final List<Share> shares;

  /// Who shares their cycle data with this user.
  final List<ReceivedShare> received;

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
    Iterable<Share>? shares,
    Iterable<ReceivedShare>? received,
  }) => HealthData(
    readings: readings ?? this.readings,
    periods: periods ?? this.periods,
    dailyLogs: dailyLogs ?? this.dailyLogs,
    remedyFeedback: remedyFeedback ?? this.remedyFeedback,
    shopping: shopping ?? this.shopping,
    profile: profile ?? this.profile,
    shares: shares ?? this.shares,
    received: received ?? this.received,
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

  HealthData withoutDailyLog(DateTime date) {
    final day = dateOnly(date);
    return copyWith(dailyLogs: dailyLogs.where((l) => l.date != day));
  }

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

  /// Adds [share], replacing any earlier share with the same recipient.
  HealthData withShare(Share share) => copyWith(
    shares: [
      ...shares.where((s) => s.recipientWebId != share.recipientWebId),
      share,
    ],
  );

  HealthData withoutShare(String recipientWebId) =>
      copyWith(shares: shares.where((s) => s.recipientWebId != recipientWebId));

  /// Adds [share], replacing any earlier one from the same sharer.
  HealthData withReceived(ReceivedShare share) => copyWith(
    received: [
      ...received.where((r) => r.sharerWebId != share.sharerWebId),
      share,
    ],
  );

  HealthData withoutReceived(String sharerWebId) =>
      copyWith(received: received.where((r) => r.sharerWebId != sharerWebId));

  @override
  bool operator ==(Object other) =>
      other is HealthData &&
      _list.equals(other.readings, readings) &&
      _list.equals(other.periods, periods) &&
      _list.equals(other.dailyLogs, dailyLogs) &&
      _list.equals(other.remedyFeedback, remedyFeedback) &&
      _list.equals(other.shopping, shopping) &&
      other.profile == profile &&
      _list.equals(other.shares, shares) &&
      _list.equals(other.received, received);

  @override
  int get hashCode => Object.hash(
    _list.hash(readings),
    _list.hash(periods),
    _list.hash(dailyLogs),
    _list.hash(remedyFeedback),
    _list.hash(shopping),
    profile,
    _list.hash(shares),
    _list.hash(received),
  );
}
