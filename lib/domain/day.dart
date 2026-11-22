// Calendar-day arithmetic. Every model that means "a day" stores midnight.

/// [date] with its time of day removed, in the same time zone.
DateTime dateOnly(DateTime date) => date.isUtc
    ? DateTime.utc(date.year, date.month, date.day)
    : DateTime(date.year, date.month, date.day);

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// [date] moved by [days] calendar days, still at midnight.
DateTime addDays(DateTime date, int days) => date.isUtc
    ? DateTime.utc(date.year, date.month, date.day + days)
    : DateTime(date.year, date.month, date.day + days);
