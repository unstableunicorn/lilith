// Everything the app stores for a user, as one immutable value.
//
// Each `with…` method returns a new value with one change applied and the
// invariants kept: one reading, period or log per day, lists oldest first,
// no empty logs, one shopping item per name.

import 'package:collection/collection.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/period_linker.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';
import 'package:meta/meta.dart';

const _list = ListEquality<Object>();
const _groups = SetEquality<LogGroup>();

/// The user's cycle data, remedy verdicts, shopping list, profile and shares.
@immutable
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
    Iterable<WearableNight> wearableNights = const [],
    this.mode,
    this.following,
    Set<LogGroup>? logGroups,
  }) : logGroups = logGroups == null ? null : Set.unmodifiable(logGroups),
       readings = List.unmodifiable(readings.sortedBy((r) => r.date)),
       wearableNights = List.unmodifiable(
         wearableNights.sortedBy((d) => d.date),
       ),
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

  /// A wearable's nightly skin temperatures, oldest first.
  final List<WearableNight> wearableNights;

  /// How the person uses the app; null until they have chosen.
  final AppMode? mode;

  /// The mode in force: a tracker until something else is chosen.
  AppMode get modeInForce => mode ?? AppMode.tracker;

  /// True when a new person should be asked how they will use the app:
  /// nothing chosen and no cycle data of their own.
  bool get needsMode => mode == null && !hasData;

  HealthData withMode(AppMode mode) => copyWith(mode: mode);

  /// Whose share Today shows for someone who follows: the one chosen, else
  /// the first; null when nobody shares with them.
  ReceivedShare? get followedShare =>
      received.firstWhereOrNull((r) => r.sharerWebId == following) ??
      received.firstOrNull;

  /// The WebID of the sharer chosen for Today; null until one is chosen.
  final String? following;

  /// Chooses whose share Today shows.
  HealthData withFollowed(String sharerWebId) =>
      copyWith(following: sharerWebId);

  /// The groups the Log tab shows beyond flow, symptoms and pain: moods
  /// only until the person chooses.
  Set<LogGroup> get shownLogGroups => logGroups ?? LogGroup.defaults;

  /// The groups chosen; null until the person has chosen any.
  final Set<LogGroup>? logGroups;

  /// Shows or hides [group] on the Log tab.
  HealthData withLogGroup(LogGroup group, {required bool shown}) => copyWith(
    logGroups: {
      for (final g in LogGroup.values)
        if (g == group ? shown : shownLogGroups.contains(g)) g,
    },
  );

  /// True once any cycle data has been logged.
  bool get hasData =>
      readings.isNotEmpty ||
      periods.isNotEmpty ||
      dailyLogs.isNotEmpty ||
      wearableNights.isNotEmpty;

  HealthData copyWith({
    Iterable<TemperatureReading>? readings,
    Iterable<PeriodEvent>? periods,
    Iterable<DailyLog>? dailyLogs,
    Iterable<RemedyFeedback>? remedyFeedback,
    Iterable<ShoppingItem>? shopping,
    HealthProfile? profile,
    Iterable<Share>? shares,
    Iterable<ReceivedShare>? received,
    Iterable<WearableNight>? wearableNights,
    AppMode? mode,
    String? following,
    Set<LogGroup>? logGroups,
  }) => HealthData(
    logGroups: logGroups ?? this.logGroups,
    mode: mode ?? this.mode,
    following: following ?? this.following,
    readings: readings ?? this.readings,
    periods: periods ?? this.periods,
    dailyLogs: dailyLogs ?? this.dailyLogs,
    remedyFeedback: remedyFeedback ?? this.remedyFeedback,
    shopping: shopping ?? this.shopping,
    profile: profile ?? this.profile,
    shares: shares ?? this.shares,
    received: received ?? this.received,
    wearableNights: wearableNights ?? this.wearableNights,
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

  /// Adds or replaces the night for each day in [imported].
  HealthData withNights(Iterable<WearableNight> imported) {
    final byDay = {for (final d in wearableNights) d.date: d};
    for (final d in imported) {
      byDay[d.date] = d;
    }
    return copyWith(wearableNights: byDay.values);
  }

  HealthData withoutNight(DateTime date) {
    final day = dateOnly(date);
    return copyWith(wearableNights: wearableNights.where((d) => d.date != day));
  }

  HealthData withoutReading(DateTime date) {
    final day = dateOnly(date);
    return copyWith(readings: readings.where((r) => r.date != day));
  }

  /// Adds or replaces the period starting on [event]'s first day. Periods
  /// never overlap: a period that would start inside the new one goes, and
  /// an earlier one that reaches into it ends the day before it starts.
  HealthData withPeriod(PeriodEvent event) => copyWith(
    periods: [
      for (final p in periods)
        if (p.startDate.isBefore(event.startDate))
          if (p.lastKnownDay.isBefore(event.startDate))
            p
          else
            p.copyWith(endDate: addDays(event.startDate, -1))
        else if (p.startDate.isAfter(event.lastKnownDay))
          p,
      event,
    ],
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

  /// Records the day's log and lets its flow join, start or shorten a
  /// period (see [linkPeriods]). An empty [log] clears the day.
  HealthData withLoggedDay(DailyLog log) {
    final next = log.isEmpty ? withoutDailyLog(log.date) : withDailyLog(log);
    return next.copyWith(
      periods: linkPeriods(next.periods, next.dailyLogs, log.date),
    );
  }

  HealthData withoutDailyLog(DateTime date) {
    final day = dateOnly(date);
    return copyWith(dailyLogs: dailyLogs.where((l) => l.date != day));
  }

  DailyLog? logFor(DateTime date) {
    final day = dateOnly(date);
    return dailyLogs.firstWhereOrNull((l) => l.date == day);
  }

  /// The days a miscarriage is logged on, oldest first.
  List<DateTime> get miscarriageDays => dailyLogs
      .where((l) => l.miscarriage)
      .map((l) => l.date)
      .sorted((a, b) => a.compareTo(b));

  /// Marks a miscarriage on each of [days] and on no other day, keeping
  /// whatever else those days hold. Periods are left as they are.
  HealthData withMiscarriageDays(Iterable<DateTime> days) {
    final wanted = {for (final d in days) dateOnly(d)};
    final changed = {...wanted, ...miscarriageDays};
    return changed.fold(
      this,
      (data, day) => data.withDailyLog(
        (data.logFor(day) ?? DailyLog(date: day)).copyWith(
          miscarriage: wanted.contains(day),
        ),
      ),
    );
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
        if (s.name == name) s.copyWith(bought: !s.bought) else s,
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
      _list.equals(other.received, received) &&
      _list.equals(other.wearableNights, wearableNights) &&
      other.mode == mode &&
      other.following == following &&
      _groups.equals(other.logGroups, logGroups);

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
    _list.hash(wearableNights),
    mode,
    following,
    _groups.hash(logGroups),
  );
}
