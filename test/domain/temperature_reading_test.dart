import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  group('TemperatureReading', () {
    test('normalises its date to midnight', () {
      final r = TemperatureReading(
        date: DateTime(2026, 5, 2, 7, 30),
        celsius: 36.4,
      );
      expect(r.date, DateTime(2026, 5, 2));
    });

    test('defaults the source to manual', () {
      final r = TemperatureReading(date: DateTime(2026, 5, 2), celsius: 36.4);
      expect(r.source, ReadingSource.manual);
    });

    test('is equal by value', () {
      final a = TemperatureReading(
        date: DateTime(2026, 5, 2, 9),
        celsius: 36.4,
        source: ReadingSource.ring,
      );
      final b = TemperatureReading(
        date: DateTime(2026, 5, 2),
        celsius: 36.4,
        source: ReadingSource.ring,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(celsius: 36.5)));
    });

    test('round-trips through JSON', () {
      final r = TemperatureReading(
        date: DateTime(2026, 5, 2),
        celsius: 36.45,
        source: ReadingSource.watch,
      );
      expect(TemperatureReading.fromJson(r.toJson()), r);
    });

    test('reads the document shape the original app wrote', () {
      final r = TemperatureReading.fromJson({
        'date': '2026-05-02T00:00:00.000',
        'celsius': 36,
        'source': 'ring',
      });
      expect(r.date, DateTime(2026, 5, 2));
      expect(r.celsius, 36.0);
      expect(r.source, ReadingSource.ring);
    });
  });

  group('ReadingSource.fromName', () {
    final cases = <({String name, String? input, ReadingSource want})>[
      (name: 'known name', input: 'watch', want: ReadingSource.watch),
      (
        name: 'unknown name falls back to manual',
        input: 'thermometer',
        want: ReadingSource.manual,
      ),
      (
        name: 'missing falls back to manual',
        input: null,
        want: ReadingSource.manual,
      ),
    ];
    for (final c in cases) {
      test(c.name, () => expect(ReadingSource.fromName(c.input), c.want));
    }
  });
}
