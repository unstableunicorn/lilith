// The first day of a period, as logged by the user.

import 'package:lillith/domain/day.dart';

/// A period start on [startDate], at most one per day.
class PeriodEvent {
  PeriodEvent({required DateTime startDate}) : startDate = dateOnly(startDate);

  factory PeriodEvent.fromJson(Map<String, dynamic> json) =>
      PeriodEvent(startDate: DateTime.parse(json['startDate'] as String));

  final DateTime startDate;

  Map<String, dynamic> toJson() => {'startDate': startDate.toIso8601String()};

  @override
  bool operator ==(Object other) =>
      other is PeriodEvent && other.startDate == startDate;

  @override
  int get hashCode => startDate.hashCode;
}
