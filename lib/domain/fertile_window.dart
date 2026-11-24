// The likely fertile days of the current cycle, shown only when a
// temperature shift or a positive ovulation test supports the estimate.

import 'package:collection/collection.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/day.dart';
import 'package:meta/meta.dart';

/// What dated the ovulation the window is built around.
enum FertileWindowBasis { shift, test }

/// Six days ending the day after ovulation.
@immutable
class FertileWindow {
  const FertileWindow({
    required this.start,
    required this.end,
    required this.basis,
  });

  final DateTime start;
  final DateTime end;
  final FertileWindowBasis basis;

  /// Days in the window before ovulation.
  static const int daysBefore = 4;

  bool contains(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

/// The window around the shift's ovulation, else around the day after the
/// cycle's first positive test; null without either, or under hormonal
/// contraception. A test never moves [prediction] itself.
FertileWindow? fertileWindowFor(
  CyclePrediction prediction,
  List<DailyLog> logs, {
  bool hormonalContraception = false,
}) {
  final cycleStart = prediction.lastPeriodStart;
  if (hormonalContraception || cycleStart == null) return null;
  final fromShift = prediction.estimatedOvulation;
  final positive = logs
      .where(
        (l) =>
            l.ovulationTest == OvulationTest.positive &&
            !l.date.isBefore(cycleStart),
      )
      .map((l) => l.date)
      .sorted((a, b) => a.compareTo(b))
      .firstOrNull;
  final (ovulation, basis) = fromShift != null
      ? (dateOnly(fromShift), FertileWindowBasis.shift)
      : positive != null
      ? (addDays(positive, 1), FertileWindowBasis.test)
      : (null, null);
  if (ovulation == null || basis == null) return null;
  return FertileWindow(
    start: addDays(ovulation, -FertileWindow.daysBefore),
    end: addDays(ovulation, 1),
    basis: basis,
  );
}
