import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/calendar.dart';
import 'package:lilith/ui/components/components.dart';

void main() {
  final day = DateTime(2026, 6, 12);

  final cases = [
    (name: 'a plain day', day: CalendarDay(date: day), want: '12'),
    (
      name: 'a likely fertile day',
      day: CalendarDay(date: day, fertile: true),
      want: '12, likely fertile',
    ),
    (
      name: 'a positive test on a logged fertile day',
      day: CalendarDay(
        date: day,
        fertile: true,
        positiveTest: true,
        logged: true,
      ),
      want: '12, likely fertile, positive ovulation test, logged',
    ),
  ];
  for (final c in cases) {
    test('a screen reader hears ${c.name}', () {
      expect(describeDay(c.day), c.want);
    });
  }
}
