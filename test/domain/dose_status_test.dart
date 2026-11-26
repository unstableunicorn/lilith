import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/day.dart';

void main() {
  final start = DateTime(2026, 3, 2);

  // Due at 09:00, three hours' window: on time until 12:00.
  ContraceptionSchedule schedule({
    DoseForm form = DoseForm.pill,
    Regimen regimen = Regimen.standard,
  }) => ContraceptionSchedule(
    form: form,
    start: start,
    daysOn: regimen.daysOn,
    daysOff: regimen.daysOff,
    windowHours: 3,
  );

  DateTime at(int day, int hour, [int minute = 0]) {
    final d = addDays(start, day);
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  DoseStatus? status(
    int day, {
    required DateTime now,
    DateTime? doneAt,
    ContraceptionSchedule? s,
    bool noSchedule = false,
  }) => doseStatus(
    schedule: noSchedule ? null : s ?? schedule(),
    day: addDays(start, day),
    doneAt: doneAt,
    now: now,
  );

  test('done before the window ends is taken', () {
    expect(status(0, doneAt: at(0, 11, 59), now: at(1, 8)), DoseStatus.taken);
  });

  test('done right at the window end is taken', () {
    expect(status(0, doneAt: at(0, 12), now: at(1, 8)), DoseStatus.taken);
  });

  test('done early is taken', () {
    expect(status(0, doneAt: at(0, 7), now: at(1, 8)), DoseStatus.taken);
  });

  test('done after the window is late', () {
    expect(status(0, doneAt: at(0, 12, 1), now: at(1, 8)), DoseStatus.late);
  });

  test('done the next day is late', () {
    expect(status(0, doneAt: at(1, 9), now: at(1, 10)), DoseStatus.late);
  });

  test('not done once the window has passed is missed', () {
    expect(status(0, now: at(0, 12, 1)), DoseStatus.missed);
  });

  test('not done while the window is open has no verdict', () {
    expect(status(0, now: at(0, 12)), isNull);
  });

  test('a break day with nothing done has no verdict', () {
    expect(status(21, now: at(30, 8)), isNull);
  });

  test('a day before the start has no verdict', () {
    expect(status(-1, now: at(30, 8)), isNull);
  });

  test('done on a day the schedule does not name is taken', () {
    expect(status(21, doneAt: at(21, 20), now: at(30, 8)), DoseStatus.taken);
    expect(status(-3, doneAt: at(-3, 20), now: at(30, 8)), DoseStatus.taken);
  });

  test('with no schedule, done is taken and nothing is missed', () {
    expect(
      status(0, doneAt: at(0, 20), now: at(1, 8), noSchedule: true),
      DoseStatus.taken,
    );
    expect(status(0, now: at(1, 8), noSchedule: true), isNull);
  });

  test('a patch is judged on its change days only', () {
    final patch = schedule(form: DoseForm.patch);
    expect(status(0, now: at(1, 8), s: patch), DoseStatus.missed);
    expect(status(1, now: at(2, 8), s: patch), isNull);
    expect(status(7, now: at(8, 8), s: patch), DoseStatus.missed);
    expect(
      status(21, doneAt: at(21, 13), now: at(22, 8), s: patch),
      DoseStatus.late,
    );
  });

  test('a ring is judged on its insert and remove days only', () {
    final ring = schedule(form: DoseForm.ring);
    expect(status(0, now: at(1, 8), s: ring), DoseStatus.missed);
    expect(status(10, now: at(11, 8), s: ring), isNull);
    expect(
      status(21, doneAt: at(21, 9), now: at(22, 8), s: ring),
      DoseStatus.taken,
    );
  });

  test('a continuous pill is due every day', () {
    final s = schedule(regimen: Regimen.continuous);
    expect(status(21, now: at(22, 8), s: s), DoseStatus.missed);
    expect(status(27, now: at(28, 8), s: s), DoseStatus.missed);
  });
}
