// When a pill, patch or ring is due: a start day, days on and a break, at a
// time of day, with how late still counts as on time.

import 'package:collection/collection.dart';
import 'package:lilith/domain/day.dart';
import 'package:meta/meta.dart';

/// What is taken or worn.
enum DoseForm {
  pill,
  patch,
  ring;

  static DoseForm? fromName(String? name) =>
      DoseForm.values.firstWhereOrNull((f) => f.name == name);
}

/// What is due on a day.
enum DoseStep {
  take,
  newPatch,
  removePatch,
  insertRing,
  removeRing,
  changeRing,
}

/// The FSRH CHC guideline's regimens (Table 1), as days on and days off.
enum Regimen {
  standard(21, 7),
  shortenedBreak(21, 4),
  tricycling(63, 7),
  continuous(21, 0);

  Regimen(this.daysOn, this.daysOff);

  final int daysOn;
  final int daysOff;
}

@immutable
class ContraceptionSchedule {
  ContraceptionSchedule({
    required this.form,
    required DateTime start,
    required this.daysOn,
    required this.daysOff,
    required this.windowHours,
    this.hour = defaultHour,
    this.minute = 0,
    this.quietHours = false,
  }) : start = dateOnly(start);

  /// Days between patch changes.
  static const int patchDays = 7;

  static const int defaultHour = 9;

  /// Quiet hours run from [quietFrom] to [quietUntil], overnight.
  static const int quietFrom = 22;
  static const int quietUntil = 6;

  final DoseForm form;

  /// Day 1: the first pill, patch or ring.
  final DateTime start;
  final int daysOn;

  /// The break after [daysOn]; 0 for none.
  final int daysOff;

  /// How many hours late still counts as on time.
  final int windowHours;
  final int hour;
  final int minute;

  /// No follow-ups between [quietFrom] and [quietUntil].
  final bool quietHours;

  /// What is due on [day], or null for nothing.
  DoseStep? stepOn(DateTime day) {
    final n = daysBetween(start, day);
    if (n < 0) return null;
    final pos = n % (daysOn + daysOff);
    final breakStarts = daysOff > 0 && pos == daysOn;
    if (pos >= daysOn && !breakStarts) return null;
    return switch (form) {
      DoseForm.pill => breakStarts ? null : DoseStep.take,
      DoseForm.patch when breakStarts => DoseStep.removePatch,
      DoseForm.patch => pos % patchDays == 0 ? DoseStep.newPatch : null,
      DoseForm.ring when breakStarts => DoseStep.removeRing,
      DoseForm.ring when pos != 0 => null,
      DoseForm.ring =>
        daysOff == 0 && n > 0 ? DoseStep.changeRing : DoseStep.insertRing,
    };
  }

  /// The schedule stored as [json], or null when it is not a whole one.
  static ContraceptionSchedule? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final form = DoseForm.fromName(json['form'] as String?);
    final start = DateTime.tryParse(json['start'] as String? ?? '');
    final daysOn = (json['daysOn'] as num?)?.toInt() ?? 0;
    final daysOff = (json['daysOff'] as num?)?.toInt() ?? 0;
    final window = (json['windowHours'] as num?)?.toInt() ?? 0;
    if (form == null || start == null) return null;
    if (daysOn < 1 || daysOff < 0 || window < 1) return null;
    return ContraceptionSchedule(
      form: form,
      start: start,
      daysOn: daysOn,
      daysOff: daysOff,
      windowHours: window,
      hour: (json['hour'] as num?)?.toInt() ?? defaultHour,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      quietHours: json['quietHours'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'form': form.name,
    'start': start.toIso8601String().substring(0, 10),
    'daysOn': daysOn,
    'daysOff': daysOff,
    'windowHours': windowHours,
    'hour': hour,
    'minute': minute,
    'quietHours': quietHours,
  };

  @override
  bool operator ==(Object other) =>
      other is ContraceptionSchedule &&
      other.form == form &&
      other.start == start &&
      other.daysOn == daysOn &&
      other.daysOff == daysOff &&
      other.windowHours == windowHours &&
      other.hour == hour &&
      other.minute == minute &&
      other.quietHours == quietHours;

  @override
  int get hashCode => Object.hash(
    form,
    start,
    daysOn,
    daysOff,
    windowHours,
    hour,
    minute,
    quietHours,
  );

  /// Starts a break of [days] today, the next dose after it.
  ContraceptionSchedule startBreak(DateTime today, {int days = 4}) =>
      copyWith(start: addDays(dateOnly(today), days));

  ContraceptionSchedule copyWith({
    DoseForm? form,
    DateTime? start,
    int? daysOn,
    int? daysOff,
    int? windowHours,
    int? hour,
    int? minute,
    bool? quietHours,
  }) => ContraceptionSchedule(
    form: form ?? this.form,
    start: start ?? this.start,
    daysOn: daysOn ?? this.daysOn,
    daysOff: daysOff ?? this.daysOff,
    windowHours: windowHours ?? this.windowHours,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    quietHours: quietHours ?? this.quietHours,
  );
}

/// How a day's dose went, judged against the current schedule.
enum DoseStatus { taken, late, missed }

/// The verdict on [day]: done within the window is taken, done after it is
/// late, not done once the window has passed is missed. Null when nothing
/// was due and nothing done, before the start, or while the window is open.
/// A dose done on a day the schedule does not name counts as taken.
DoseStatus? doseStatus({
  required ContraceptionSchedule? schedule,
  required DateTime day,
  required DateTime? doneAt,
  required DateTime now,
}) {
  final d = dateOnly(day);
  if (schedule == null || schedule.stepOn(d) == null) {
    return doneAt == null ? null : DoseStatus.taken;
  }
  final windowEnd = DateTime(
    d.year,
    d.month,
    d.day,
    schedule.hour,
    schedule.minute,
  ).add(Duration(hours: schedule.windowHours));
  if (doneAt != null) {
    return doneAt.isAfter(windowEnd) ? DoseStatus.late : DoseStatus.taken;
  }
  return now.isAfter(windowEnd) ? DoseStatus.missed : null;
}
