import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/period_event.dart';

void main() {
  group('PeriodEvent', () {
    test('normalises its start to midnight', () {
      final p = PeriodEvent(startDate: DateTime(2026, 5, 2, 18));
      expect(p.startDate, DateTime(2026, 5, 2));
    });

    test('is equal by value', () {
      expect(
        PeriodEvent(startDate: DateTime(2026, 5, 2, 1)),
        PeriodEvent(startDate: DateTime(2026, 5, 2)),
      );
      expect(
        PeriodEvent(startDate: DateTime(2026, 5, 2)),
        isNot(PeriodEvent(startDate: DateTime(2026, 5, 3))),
      );
    });

    test('round-trips through JSON', () {
      final p = PeriodEvent(startDate: DateTime(2026, 5, 2));
      expect(PeriodEvent.fromJson(p.toJson()), p);
    });

    test('reads the document shape the original app wrote', () {
      final p = PeriodEvent.fromJson(const {
        'startDate': '2026-05-02T00:00:00.000',
      });
      expect(p.startDate, DateTime(2026, 5, 2));
    });
  });
}
