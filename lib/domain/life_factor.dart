// Times of life kept on the profile with their dates. A pregnancy pauses
// predictions, since cycles stop; breastfeeding is a record and pauses
// nothing. A miscarriage is logged on its day (`DailyLog.miscarriage`).

import 'package:collection/collection.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:meta/meta.dart';

enum LifeFactorKind {
  pregnant('Pregnant', pausesPredictions: true),
  breastfeeding('Breastfeeding', pausesPredictions: false);

  LifeFactorKind(this.label, {required this.pausesPredictions});

  final String label;

  /// Whether predictions, statistics and period reminders stop while it is
  /// in force.
  final bool pausesPredictions;
}

/// The start days of the miscarriages in a profile's stored life factors,
/// from when a miscarriage was kept as one. They load as day entries.
List<DateTime> legacyMiscarriageDays(Object? lifeFactorsJson) => [
  if (lifeFactorsJson is List)
    for (final f in lifeFactorsJson)
      if (f is Map && f['kind'] == 'miscarriage')
        if (f['start'] case final String iso)
          if (DateTime.tryParse(iso) case final start?) dateOnly(start),
];

/// One factor from [start], in force until [end] when one is set. Days are
/// midnight.
@immutable
class LifeFactor {
  LifeFactor({
    required this.kind,
    required DateTime start,
    DateTime? end,
    DateTime? dueDate,
  }) : start = dateOnly(start),
       end = end == null || dateOnly(end).isBefore(dateOnly(start))
           ? null
           : dateOnly(end),
       dueDate = kind == LifeFactorKind.pregnant && dueDate != null
           ? dateOnly(dueDate)
           : null;

  /// The factor stored as [json], or null when it cannot be read.
  static LifeFactor? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final kind = LifeFactorKind.values.firstWhereOrNull(
      (k) => k.name == json['kind'],
    );
    final start = _day(json['start']);
    if (kind == null || start == null) return null;
    return LifeFactor(
      kind: kind,
      start: start,
      end: _day(json['end']),
      dueDate: _day(json['dueDate']),
    );
  }

  static DateTime? _day(Object? iso) =>
      iso is String ? DateTime.tryParse(iso) : null;

  static String _iso(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  final LifeFactorKind kind;
  final DateTime start;

  /// The last day it is in force, when the person has ended it.
  final DateTime? end;

  /// When the baby is due; a pregnancy only.
  final DateTime? dueDate;

  /// The same factor ended on [day].
  LifeFactor endedOn(DateTime day) =>
      LifeFactor(kind: kind, start: start, end: day, dueDate: dueDate);

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'start': _iso(start),
    if (end case final e?) 'end': _iso(e),
    if (dueDate case final d?) 'dueDate': _iso(d),
  };

  @override
  bool operator ==(Object other) =>
      other is LifeFactor &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(kind, start, end, dueDate);
}

Iterable<LifeFactor> _pausing(List<LifeFactor> factors) =>
    factors.where((f) => f.kind.pausesPredictions);

/// The factor pausing predictions on [today], or null; of several, the one
/// that began last. It is in force from its start to the end that was set.
LifeFactor? activeFactor(List<LifeFactor> factors, {required DateTime today}) {
  final day = dateOnly(today);
  return _pausing(factors)
      .where(
        (f) =>
            !f.start.isAfter(day) && (f.end == null || !f.end!.isBefore(day)),
      )
      .sorted((a, b) => a.start.compareTo(b.start))
      .lastOrNull;
}

/// Whether the cycle from the period start [from] to the next one, [to],
/// overlaps a pausing factor, so its length says nothing about a usual
/// cycle.
bool cycleOverlapsFactor(
  DateTime from,
  DateTime to,
  List<LifeFactor> factors,
) => _pausing(
  factors,
).any((f) => f.start.isBefore(to) && (f.end == null || !f.end!.isBefore(from)));

/// Whether a pausing factor has begun, by [today], on or after the latest
/// period start: there is then no period to predict from until one is
/// logged.
bool factorSinceLastPeriod(
  List<LifeFactor> factors,
  List<PeriodEvent> periods, {
  required DateTime today,
}) {
  final day = dateOnly(today);
  final lastStart = periods
      .map((p) => p.startDate)
      .sorted((a, b) => a.compareTo(b))
      .lastOrNull;
  return _pausing(factors).any(
    (f) =>
        !f.start.isAfter(day) &&
        (lastStart == null || !f.start.isBefore(lastStart)),
  );
}
