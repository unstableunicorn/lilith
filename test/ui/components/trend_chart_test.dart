import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/ui/components/trend_chart.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);
  ChartPoint p(int d, double v) => ChartPoint(date: june(d), value: v);

  group('chartLayout', () {
    test('places points by date, not by index', () {
      final layout = chartLayout([p(1, 36.2), p(2, 36.3), p(11, 36.9)]);
      expect(layout.first, june(1));
      expect(layout.last, june(11));
      expect(layout.dayCount, 11);
      expect(layout.xOf(june(1)), 0);
      expect(layout.xOf(june(2)), closeTo(0.1, 1e-9));
      expect(layout.xOf(june(11)), 1);
    });

    test('a single day sits in the middle and has one tick', () {
      final layout = chartLayout([p(5, 36.4)]);
      expect(layout.xOf(june(5)), 0.5);
      expect(layout.ticks, [june(5)]);
    });

    test('ticks are the first, middle and last day', () {
      final layout = chartLayout([p(1, 36.2), p(21, 36.9)]);
      expect(layout.ticks, [june(1), june(11), june(21)]);
    });

    test('the value range is padded to at least half a degree', () {
      final layout = chartLayout([p(1, 36.4), p(2, 36.5)]);
      expect(layout.high - layout.low, closeTo(0.5, 1e-9));
      expect(layout.yOf(36.45), closeTo(0.5, 1e-9));
      final wide = chartLayout([p(1, 36), p(2, 37)]);
      expect(wide.low, 36.0);
      expect(wide.high, 37.0);
    });

    test('spans widen the day range', () {
      final layout = chartLayout(
        [p(5, 36.4), p(6, 36.5)],
        spans: [ChartSpan(start: june(1), end: june(3))],
      );
      expect(layout.first, june(1));
      expect(layout.last, june(6));
    });

    test('a zero line brings zero into the range', () {
      final layout = chartLayout([p(1, 0.2), p(2, 0.4)], zeroLine: true);
      expect(layout.low, lessThanOrEqualTo(0));
      expect(layout.high, greaterThanOrEqualTo(0.4));
    });
  });

  group('describe', () {
    test('says the readings, their range and what is shaded', () {
      final chart = TrendChart(
        points: [p(1, 36.2), p(10, 36.9)],
        unit: '°C',
        menstrual: [ChartSpan(start: june(1), end: june(4))],
        luteal: ChartSpan(start: june(15), end: june(27)),
        starts: {june(1)},
      );
      expect(
        chart.describe(),
        '2 temperature readings from 1 Jun to 10 Jun, lowest 36.2 °C, '
        'highest 36.9 °C, 1 period, the days after ovulation',
      );
    });

    test('says so when there is nothing', () {
      expect(
        const TrendChart(points: [], unit: '°C').describe(),
        'No temperature readings yet',
      );
    });
  });
}
