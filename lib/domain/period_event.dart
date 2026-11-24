// A period as logged by the user: its first day, and when known its last
// day and overall flow.

import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:meta/meta.dart';

/// Bleeding days this close to a period belong to it; further apart they
/// start a new one.
const int maxGapDays = 2;

/// A period starting on [startDate], at most one per day. [endDate] is the
/// last bleeding day as far as is known; null covers both "still going" and
/// "never said". [flow] is the overall intensity, null when not said.
/// [ended] is true once the person said it was over.
@immutable
class PeriodEvent {
  PeriodEvent({
    required DateTime startDate,
    DateTime? endDate,
    FlowIntensity? flow,
    this.ended = false,
  }) : startDate = dateOnly(startDate),
       endDate =
           endDate == null || dateOnly(endDate).isBefore(dateOnly(startDate))
           ? null
           : dateOnly(endDate),
       flow = flow == FlowIntensity.none ? null : flow;

  factory PeriodEvent.fromJson(Map<String, dynamic> json) => PeriodEvent(
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: switch (json['endDate']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    flow: switch (json['flow']) {
      final String f => FlowIntensity.fromName(f),
      _ => null,
    },
    ended: json['ended'] == true,
  );

  final DateTime startDate;
  final DateTime? endDate;
  final FlowIntensity? flow;
  final bool ended;

  /// Still going on [today]: started by then, not marked ended, and
  /// bleeding known within [maxGapDays].
  bool inProgressOn(DateTime today) {
    final d = dateOnly(today);
    return !ended &&
        !startDate.isAfter(d) &&
        daysBetween(lastKnownDay, d) <= maxGapDays;
  }

  /// No end recorded: still going, or never said.
  bool get isOpen => endDate == null;

  /// The last day the period is known to cover.
  DateTime get lastKnownDay => endDate ?? startDate;

  /// Days from first to last, when the end is known.
  int? get lengthDays =>
      endDate == null ? null : daysBetween(startDate, endDate!) + 1;

  /// True for every known day of the period.
  bool contains(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(startDate) && !d.isAfter(lastKnownDay);
  }

  PeriodEvent copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool clearEnd = false,
    FlowIntensity? flow,
    bool clearFlow = false,
    bool? ended,
  }) => PeriodEvent(
    startDate: startDate ?? this.startDate,
    endDate: clearEnd ? null : endDate ?? this.endDate,
    flow: clearFlow ? null : flow ?? this.flow,
    ended: ended ?? this.ended,
  );

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    if (flow != null) 'flow': flow!.name,
    if (ended) 'ended': true,
  };

  @override
  bool operator ==(Object other) =>
      other is PeriodEvent &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.flow == flow &&
      other.ended == ended;

  @override
  int get hashCode => Object.hash(startDate, endDate, flow, ended);
}
