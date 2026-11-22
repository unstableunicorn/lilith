import 'package:flutter_test/flutter_test.dart';
import 'package:lillith/domain/day.dart';

void main() {
  group('dateOnly', () {
    final cases = <({String name, DateTime input, DateTime want})>[
      (
        name: 'strips the time of day',
        input: DateTime(2026, 3, 14, 23, 59, 59, 999),
        want: DateTime(2026, 3, 14),
      ),
      (
        name: 'leaves midnight alone',
        input: DateTime(2026, 3, 14),
        want: DateTime(2026, 3, 14),
      ),
      (
        name: 'keeps a UTC instant on its own calendar day',
        input: DateTime.utc(2026, 3, 14, 1),
        want: DateTime.utc(2026, 3, 14),
      ),
    ];
    for (final c in cases) {
      test(c.name, () {
        final got = dateOnly(c.input);
        expect(got, c.want);
        expect(got.isUtc, c.input.isUtc);
      });
    }
  });

  group('addDays', () {
    final cases = <({String name, DateTime from, int days, DateTime want})>[
      (
        name: 'adds forwards',
        from: DateTime(2026, 3, 14),
        days: 20,
        want: DateTime(2026, 4, 3),
      ),
      (
        name: 'subtracts with a negative count',
        from: DateTime(2026, 3, 1),
        days: -1,
        want: DateTime(2026, 2, 28),
      ),
      (
        name: 'stays at midnight across a daylight-saving change',
        from: DateTime(2026, 3, 28),
        days: 10,
        want: DateTime(2026, 4, 7),
      ),
    ];
    for (final c in cases) {
      test(c.name, () => expect(addDays(c.from, c.days), c.want));
    }
  });

  group('daysBetween', () {
    final cases = <({String name, DateTime from, DateTime to, int want})>[
      (
        name: 'same day is zero',
        from: DateTime(2026, 3, 14, 8),
        to: DateTime(2026, 3, 14, 22),
        want: 0,
      ),
      (
        name: 'counts whole calendar days, not 24-hour spans',
        from: DateTime(2026, 3, 14, 23),
        to: DateTime(2026, 3, 15, 1),
        want: 1,
      ),
      (
        name: 'is negative when to precedes from',
        from: DateTime(2026, 3, 20),
        to: DateTime(2026, 3, 14),
        want: -6,
      ),
      (
        name: 'crosses a daylight-saving change as calendar days',
        from: DateTime(2026, 3, 28),
        to: DateTime(2026, 4, 2),
        want: 5,
      ),
    ];
    for (final c in cases) {
      test(c.name, () => expect(daysBetween(c.from, c.to), c.want));
    }
  });
}
