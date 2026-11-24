// The temperature trend: readings over days with the periods shaded and
// their starts marked, through TrendChart.

import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/components/trend_chart.dart';
import 'package:material_ui/material_ui.dart';

class TemperatureChart extends StatelessWidget {
  const TemperatureChart({
    required this.readings,
    required this.periodStarts,
    this.periods = const [],
    this.luteal,
    super.key,
  });

  /// Oldest first.
  final List<TemperatureReading> readings;
  final Set<DateTime> periodStarts;

  /// The known days of each period, shaded.
  final List<ChartSpan> periods;

  /// From the estimated ovulation to the predicted period, when known.
  final ChartSpan? luteal;

  @override
  Widget build(BuildContext context) => TrendChart(
    points: [
      for (final r in readings) ChartPoint(date: r.date, value: r.celsius),
    ],
    unit: '°C',
    menstrual: periods,
    luteal: luteal,
    starts: periodStarts,
  );

  /// The sentence the chart carries for anyone who cannot see it.
  String describe() => TrendChart(
    points: [
      for (final r in readings) ChartPoint(date: r.date, value: r.celsius),
    ],
    unit: '°C',
    menstrual: periods,
    luteal: luteal,
    starts: periodStarts,
  ).describe();
}
