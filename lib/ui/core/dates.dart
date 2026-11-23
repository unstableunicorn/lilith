// Dates as the app shows them, without pulling in a locale library.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Wed 10 Jun 2026".
String formatDay(DateTime day) =>
    '${_weekdays[day.weekday - 1]} ${day.day} '
    '${_months[day.month - 1]} ${day.year}';

/// "10 Jun", with the year added only when it is not [today]'s.
String formatShortDate(DateTime day, {required DateTime today}) =>
    '${day.day} ${_months[day.month - 1]}'
    '${day.year == today.year ? '' : ' ${day.year}'}';
