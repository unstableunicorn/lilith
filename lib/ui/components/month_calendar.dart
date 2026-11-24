// A month grid: period days filled, the predicted period outlined, the
// estimated ovulation marked, a dot on any logged day. Tapping a day hands
// it back to the caller.

import 'package:lilith/domain/calendar.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    required this.title,
    required this.days,
    required this.leadingBlanks,
    required this.onPrevious,
    required this.onNext,
    required this.onDay,
    required this.dayKey,
    this.previousKey,
    this.nextKey,
    this.today,
    super.key,
  });

  final String title;

  /// One per day of the month, oldest first.
  final List<CalendarDay> days;
  final int leadingBlanks;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final void Function(DateTime day) onDay;
  final Key Function(DateTime day) dayKey;
  final Key? previousKey;
  final Key? nextKey;
  final DateTime? today;

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: previousKey,
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: onPrevious,
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: style.titleMedium,
              ),
            ),
            IconButton(
              key: nextKey,
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: onNext,
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final w in _weekdays)
              ExcludeSemantics(
                child: Center(child: Text(w, style: style.labelSmall)),
              ),
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (final day in days)
              CalendarDayCell(
                key: dayKey(day.date),
                day: day,
                isToday: today != null && _sameDay(today!, day.date),
                onTap: () => onDay(day.date),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        _Legend(
          fertile: days.any((d) => d.fertile),
          positiveTest: days.any((d) => d.positiveTest),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// One day. Public so a test can read which marks it carries.
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    required this.day,
    required this.onTap,
    this.isToday = false,
    super.key,
  });

  final CalendarDay day;
  final VoidCallback onTap;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium;
    final fill = day.inPeriod
        ? scheme.primaryContainer
        : day.fertile
        ? scheme.tertiaryContainer
        : null;
    final border = day.predictedPeriod
        ? Border.all(color: scheme.primary, width: 2)
        : isToday
        ? Border.all(color: scheme.outline)
        : null;
    return Semantics(
      button: true,
      label: describeDay(day, isToday: isToday),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Space.sm),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                border: border,
                borderRadius: BorderRadius.circular(Space.sm),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text('${day.date.day}', style: style),
                  if (day.ovulation)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(
                        Icons.change_history_rounded,
                        size: 10,
                        color: scheme.tertiary,
                      ),
                    ),
                  if (day.positiveTest)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Icon(
                        Icons.add_circle_rounded,
                        size: 10,
                        color: scheme.tertiary,
                      ),
                    ),
                  if (day.logged)
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a screen reader says for a day.
String describeDay(CalendarDay day, {bool isToday = false}) {
  final parts = <String>[
    '${day.date.day}',
    if (isToday) 'today',
    if (day.inPeriod) 'period',
    if (day.predictedPeriod) 'period expected',
    if (day.ovulation) 'estimated ovulation',
    if (day.fertile) 'likely fertile',
    if (day.positiveTest) 'positive ovulation test',
    if (day.logged) 'logged',
  ];
  return parts.join(', ');
}

/// The marks' meanings; the fertile and test marks only when the month has
/// them.
class _Legend extends StatelessWidget {
  const _Legend({required this.fertile, required this.positiveTest});

  final bool fertile;
  final bool positiveTest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    Widget item(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: Space.xs),
        Text(text, style: style),
      ],
    );
    Widget box({Color? fill, Color? border}) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: fill,
        border: border == null ? null : Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.xs,
      children: [
        item(box(fill: scheme.primaryContainer), 'Period'),
        item(box(border: scheme.primary), 'Expected'),
        item(
          Icon(Icons.change_history_rounded, size: 14, color: scheme.tertiary),
          'Ovulation',
        ),
        if (fertile)
          item(box(fill: scheme.tertiaryContainer), 'Likely fertile'),
        if (positiveTest)
          item(
            Icon(Icons.add_circle_rounded, size: 14, color: scheme.tertiary),
            'Positive test',
          ),
        item(
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
          'Logged',
        ),
      ],
    );
  }
}
