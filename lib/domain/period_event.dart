// A period as logged by the user: its first day, and when known its last
// day and overall flow.

import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:meta/meta.dart';

/// A period starting on [startDate], at most one per day. [endDate] is the
/// last bleeding day as far as is known; null covers both "still going" and
/// "never said". [flow] is the overall intensity, null when not said.
@immutable
class PeriodEvent {
  PeriodEvent({
    required DateTime startDate,
    DateTime? endDate,
    FlowIntensity? flow,
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
  );

  final DateTime startDate;
  final DateTime? endDate;
  final FlowIntensity? flow;

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
  }) => PeriodEvent(
    startDate: startDate ?? this.startDate,
    endDate: clearEnd ? null : endDate ?? this.endDate,
    flow: clearFlow ? null : flow ?? this.flow,
  );

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    if (flow != null) 'flow': flow!.name,
  };

  @override
  bool operator ==(Object other) =>
      other is PeriodEvent &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.flow == flow;

  @override
  int get hashCode => Object.hash(startDate, endDate, flow);
}
