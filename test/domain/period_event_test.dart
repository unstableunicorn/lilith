import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/period_event.dart';

void main() {
  final may1 = DateTime(2026, 5, 1);
  final may5 = DateTime(2026, 5, 5);

  test('a start alone is an open period of one known day', () {
    final p = PeriodEvent(startDate: DateTime(2026, 5, 1, 14));
    expect(p.startDate, may1);
    expect(p.isOpen, isTrue);
    expect(p.lastKnownDay, may1);
    expect(p.lengthDays, isNull);
    expect(p.flow, isNull);
    expect(p.contains(may1), isTrue);
    expect(p.contains(DateTime(2026, 5, 2)), isFalse);
  });

  test('an end before the start is dropped; none means no bleeding', () {
    expect(PeriodEvent(startDate: may5, endDate: may1).endDate, isNull);
    expect(PeriodEvent(startDate: may1, flow: FlowIntensity.none).flow, isNull);
  });

  test('a span knows its days and length', () {
    final p = PeriodEvent(
      startDate: may1,
      endDate: DateTime(2026, 5, 5, 9),
      flow: FlowIntensity.medium,
    );
    expect(p.endDate, may5);
    expect(p.lengthDays, 5);
    expect(p.contains(DateTime(2026, 5, 3)), isTrue);
    expect(p.contains(DateTime(2026, 5, 6)), isFalse);
    expect(p.isOpen, isFalse);
  });

  test('copyWith changes or clears the end and flow', () {
    final p = PeriodEvent(
      startDate: may1,
      endDate: may5,
      flow: FlowIntensity.heavy,
    );
    expect(p.copyWith(clearEnd: true).endDate, isNull);
    expect(p.copyWith(clearFlow: true).flow, isNull);
    expect(p.copyWith(endDate: DateTime(2026, 5, 7)).lengthDays, 7);
    expect(
      p.copyWith(startDate: DateTime(2026, 5, 2)).startDate,
      DateTime(2026, 5, 2),
    );
  });

  test('round-trips through JSON, omitting what is not known', () {
    final open = PeriodEvent(startDate: may1);
    expect(open.toJson(), {'startDate': may1.toIso8601String()});
    expect(PeriodEvent.fromJson(open.toJson()), open);
    final full = PeriodEvent(
      startDate: may1,
      endDate: may5,
      flow: FlowIntensity.light,
    );
    expect(PeriodEvent.fromJson(full.toJson()), full);
    expect(full.toJson()['flow'], 'light');
  });

  test('equality covers every field', () {
    expect(PeriodEvent(startDate: may1), PeriodEvent(startDate: may1));
    expect(
      PeriodEvent(startDate: may1),
      isNot(PeriodEvent(startDate: may1, endDate: may5)),
    );
    expect(
      PeriodEvent(startDate: may1, flow: FlowIntensity.light),
      isNot(PeriodEvent(startDate: may1, flow: FlowIntensity.heavy)),
    );
    expect(
      PeriodEvent(startDate: may1, endDate: may5),
      isNot(PeriodEvent(startDate: may1, endDate: may5, ended: true)),
    );
  });

  test('a period marked ended round-trips; without the key it is not', () {
    final ended = PeriodEvent(startDate: may1, endDate: may5, ended: true);
    expect(PeriodEvent.fromJson(ended.toJson()), ended);
    final unmarked = PeriodEvent(startDate: may1, endDate: may5);
    expect(unmarked.toJson(), isNot(contains('ended')));
    expect(PeriodEvent.fromJson(unmarked.toJson()).ended, isFalse);
    expect(ended.copyWith().ended, isTrue);
    expect(ended.copyWith(ended: false).ended, isFalse);
  });

  group('inProgressOn', () {
    final cases = [
      (name: 'started today', period: PeriodEvent(startDate: may5), want: true),
      (
        name: 'bleeding logged two days ago',
        period: PeriodEvent(startDate: may1, endDate: DateTime(2026, 5, 3)),
        want: true,
      ),
      (
        name: 'nothing logged for three days',
        period: PeriodEvent(startDate: may1, endDate: DateTime(2026, 5, 2)),
        want: false,
      ),
      (
        name: 'marked ended today',
        period: PeriodEvent(startDate: may1, endDate: may5, ended: true),
        want: false,
      ),
      (
        name: 'starting after today',
        period: PeriodEvent(startDate: DateTime(2026, 5, 6)),
        want: false,
      ),
    ];
    for (final c in cases) {
      test(c.name, () => expect(c.period.inProgressOn(may5), c.want));
    }
  });
}
