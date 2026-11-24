// Invented test data: a healthy year, and a pregnancy lost at nine weeks
// with retained tissue. The same seed always gives the same document.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';

/// The scenarios by the name `bin/seed.dart` takes.
const Map<String, HealthData Function({int seed})> scenarios = {
  'healthy-year': healthyYear,
  'pregnancy-loss': pregnancyLoss,
};

/// The arguments were not `<scenario> [--seed N]`.
class UsageException implements Exception {
  const UsageException(this.message);
  final String message;
  @override
  String toString() =>
      '$message\nusage: seed <${scenarios.keys.join('|')}> [--seed N]';
}

/// The Lilith document for `<scenario> [--seed N]`, as the app writes it.
String seedDocument(List<String> args) {
  final build = args.isEmpty ? null : scenarios[args.first];
  if (build == null) throw const UsageException('name a scenario');
  final rest = args.skip(1).toList();
  var seed = 1;
  if (rest.isNotEmpty) {
    final value = rest.length == 2 && rest.first == '--seed'
        ? int.tryParse(rest.last)
        : null;
    if (value == null) throw const UsageException('--seed needs a number');
    seed = value;
  }
  return const HealthDocumentCodec().encode(build(seed: seed));
}

final DateTime _lastDay = DateTime(2026, 11, 24);

const double _follicular = 36.30;
const double _luteal = 36.65;
const double _pregnant = 36.75;
const double _wristOffset = -2.7;

/// 24 Nov 2025 to 24 Nov 2026: 13 cycles of 27 to 30 days, five-day
/// periods, manual readings with a luteal rise, watch nights for the last
/// 90 days.
HealthData healthyYear({int seed = 1}) {
  final g = _Generator(seed);
  final first = addDays(_lastDay, -365);
  final lengths = g.cycleLengths(count: 13, fill: 366);
  var start = first;
  for (final length in lengths) {
    g.normalCycle(start, length, from: first, to: _lastDay);
    start = addDays(start, length);
  }
  g.nights(from: addDays(_lastDay, -89), to: _lastDay);
  return g.build(
    HealthProfile(
      usualCycleLength: 28,
      usualPeriodLength: 5,
      birthYear: 1992,
      contraception: Contraception.none,
      regularity: CycleRegularity.regular,
    ),
  );
}

/// 24 May to 24 Nov 2026: three normal cycles, a pregnancy from the 20 Aug
/// cycle, a miscarriage on 22 Oct, then 26 days of bleeding and from 3 Nov
/// a low-grade fever.
HealthData pregnancyLoss({int seed = 1}) {
  final g = _Generator(seed);
  final first = DateTime(2026, 5, 24);
  for (final start in [
    DateTime(2026, 4, 30),
    DateTime(2026, 5, 28),
    DateTime(2026, 6, 25),
    DateTime(2026, 7, 23),
  ]) {
    g.normalCycle(start, 28, from: first, to: _lastDay);
  }
  final conception = DateTime(2026, 8, 20);
  final loss = DateTime(2026, 10, 22);
  g
    ..pregnancy(conception, until: addDays(loss, -1))
    ..miscarriage(loss, bleedDays: 26, feverFrom: DateTime(2026, 11, 3));
  return g.build(
    HealthProfile(
      usualCycleLength: 28,
      usualPeriodLength: 5,
      birthYear: 1994,
      contraception: Contraception.none,
      regularity: CycleRegularity.regular,
      history: const ObstetricHistory(
        pregnancies: 1,
        births: 0,
        miscarriages: 1,
      ),
    ),
  );
}

class _Generator {
  _Generator(int seed) : _rng = Random(seed);

  final Random _rng;
  final List<TemperatureReading> _readings = [];
  final List<WearableNight> _nights = [];
  final Map<DateTime, DailyLog> _logs = {};
  final Map<DateTime, double> _levels = {};

  bool chance(double p) => _rng.nextDouble() < p;
  int between(int low, int high) => low + _rng.nextInt(high - low + 1);
  double noise(double spread) => (_rng.nextDouble() * 2 - 1) * spread;
  T pick<T>(List<T> from) => from[_rng.nextInt(from.length)];

  /// [count] lengths of 27 to 30 days whose total passes [fill] days, so the
  /// last cycle is still running, and whose last period ends inside it.
  List<int> cycleLengths({required int count, required int fill}) {
    while (true) {
      final lengths = [for (var i = 0; i < count; i++) between(27, 30)];
      if (lengths.sum > fill && lengths.take(count - 1).sum + 5 <= fill) {
        return lengths;
      }
    }
  }

  /// Ovulation [length] − 14 days in, the rise held from two days later to
  /// the day before the next period. Only days in [from]..[to] are kept.
  void normalCycle(
    DateTime start,
    int length, {
    required DateTime from,
    required DateTime to,
  }) {
    final ovulation = length - 14;
    final premenstrual = between(3, 5);
    final headaches = {between(0, length - 1), between(0, length - 1)};
    if (chance(0.5)) headaches.remove(headaches.first);
    for (var i = 0; i < length; i++) {
      final day = addDays(start, i);
      if (day.isBefore(from) || day.isAfter(to)) continue;
      final level = i >= ovulation + 2
          ? _luteal
          : i == ovulation + 1
          ? (_follicular + _luteal) / 2
          : _follicular;
      reading(day, level + noise(0.08));
      final symptoms = <Symptom>{
        if (i <= 1) Symptom.cramps,
        if (i <= 2) Symptom.fatigue,
        if (i == 0 && chance(0.4)) Symptom.backPain,
        if (headaches.contains(i)) Symptom.headache,
        if (chance(0.03)) Symptom.insomnia,
        if (i >= length - premenstrual) ...[
          for (final s in const [
            Symptom.bloating,
            Symptom.breastTenderness,
            Symptom.mood,
            Symptom.cravings,
          ])
            if (chance(0.7)) s,
        ],
      };
      log(
        day,
        flow: switch (i) {
          0 || 2 => FlowIntensity.medium,
          1 => FlowIntensity.heavy,
          3 || 4 => FlowIntensity.light,
          _ when i == length - 1 && chance(0.3) => FlowIntensity.spotting,
          _ => FlowIntensity.none,
        },
        symptoms: symptoms,
        pain: i <= 1 ? between(3, 5) : null,
      );
    }
  }

  /// A normal cycle to ovulation 14 days in, then the rise stays up through
  /// [until]: implantation spotting, then early-pregnancy symptoms.
  void pregnancy(DateTime start, {required DateTime until}) {
    final spotting = {addDays(start, 21), addDays(start, 22)};
    final symptomsFrom = addDays(start, 26);
    normalCycle(start, 15, from: start, to: addDays(start, 14));
    for (
      var day = addDays(start, 15);
      !day.isAfter(until);
      day = addDays(day, 1)
    ) {
      final i = daysBetween(start, day);
      reading(day, (i == 15 ? 36.5 : _pregnant) + noise(0.07));
      final early = !day.isBefore(symptomsFrom);
      log(
        day,
        flow: spotting.contains(day)
            ? FlowIntensity.spotting
            : FlowIntensity.none,
        symptoms: {
          if (early && chance(0.7)) Symptom.nausea,
          if (early && chance(0.8)) Symptom.fatigue,
          if (early && chance(0.7)) Symptom.breastTenderness,
          if (early && chance(0.4)) Symptom.cravings,
          if (early && chance(0.3)) Symptom.insomnia,
          if (early && chance(0.4)) Symptom.mood,
        },
        pain: early && chance(0.3) ? between(1, 2) : null,
      );
    }
  }

  /// Heavy bleeding with severe pain on [start], a temperature falling over
  /// three days, bleeding that keeps coming back for [bleedDays] days, and
  /// a fever from [feverFrom] to the last day.
  void miscarriage(
    DateTime start, {
    required int bleedDays,
    required DateTime feverFrom,
  }) {
    final taper = bleedDays - 7;
    var previous = FlowIntensity.heavy;
    for (var day = start; !day.isAfter(_lastDay); day = addDays(day, 1)) {
      final i = daysBetween(start, day);
      final celsius = switch (i) {
        _ when !day.isBefore(feverFrom) => 37.6 + _rng.nextDouble() * 0.4,
        0 => 36.62 + noise(0.03),
        1 => 36.5 + noise(0.03),
        _ => 36.4 + noise(0.06),
      };
      reading(day, celsius);
      final bleeding = i < bleedDays;
      final flow = switch (i) {
        _ when !bleeding => FlowIntensity.none,
        0 || 1 => FlowIntensity.heavy,
        2 => FlowIntensity.medium,
        _ when i == bleedDays - 1 => FlowIntensity.light,
        _ when previous == FlowIntensity.spotting =>
          i >= taper
              ? FlowIntensity.light
              : pick(const [
                  FlowIntensity.light,
                  FlowIntensity.medium,
                  FlowIntensity.heavy,
                ]),
        _ when i >= taper =>
          chance(0.5) ? FlowIntensity.spotting : FlowIntensity.light,
        _ when chance(0.3) => FlowIntensity.spotting,
        _ => pick(const [
          FlowIntensity.light,
          FlowIntensity.medium,
          FlowIntensity.medium,
          FlowIntensity.heavy,
          FlowIntensity.heavy,
        ]),
      };
      previous = flow;
      log(
        day,
        flow: flow,
        symptoms: {
          if (bleeding) Symptom.cramps,
          if (i == 0 || (bleeding && chance(0.3))) Symptom.backPain,
          if (bleeding ? chance(0.8) : chance(0.5)) Symptom.fatigue,
        },
        pain: i == 0 ? 8 : (bleeding ? between(4, 6) : null),
      );
    }
  }

  /// Watch nights: wrist skin runs below the mouth, by about [_wristOffset].
  void nights({required DateTime from, required DateTime to}) {
    for (var day = from; !day.isAfter(to); day = addDays(day, 1)) {
      if (!chance(0.95)) continue;
      final oral = _levels[day] ?? _follicular;
      _nights.add(
        WearableNight(
          date: day,
          celsius: _round(oral + _wristOffset + noise(0.1)),
        ),
      );
    }
  }

  /// A morning reading on about 85% of days; [celsius] is kept as the
  /// day's level either way, for the watch nights.
  void reading(DateTime day, double celsius) {
    _levels[day] = celsius;
    if (chance(0.85)) {
      _readings.add(TemperatureReading(date: day, celsius: _round(celsius)));
    }
  }

  void log(
    DateTime day, {
    required FlowIntensity flow,
    required Set<Symptom> symptoms,
    int? pain,
  }) {
    final entry = DailyLog(
      date: day,
      flow: flow,
      symptoms: symptoms,
      painLevel: pain,
    );
    if (!entry.isEmpty) _logs[entry.date] = entry;
  }

  /// The document, with periods linked from the logs as the app links them.
  HealthData build(HealthProfile profile) {
    var data = HealthData(
      readings: _readings,
      wearableNights: _nights,
      profile: profile,
    );
    for (final entry in _logs.values.sortedBy((l) => l.date)) {
      data = data.withLoggedDay(entry);
    }
    return data;
  }
}

double _round(double celsius) => (celsius * 100).round() / 100;
