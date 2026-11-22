// The temperature trend: readings as a line, period starts as markers, and
// a sentence saying the same for anyone who cannot see it.

import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class TemperatureChart extends StatelessWidget {
  const TemperatureChart({
    required this.readings,
    required this.periodStarts,
    super.key,
  });

  /// Oldest first.
  final List<TemperatureReading> readings;
  final Set<DateTime> periodStarts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: describe(),
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: Sizes.chart,
          child: CustomPaint(
            size: Size.infinite,
            painter: _Painter(
              readings: readings,
              periodStarts: periodStarts,
              line: scheme.primary,
              marker: scheme.error,
              grid: scheme.outlineVariant,
              text: scheme.onSurfaceVariant,
              labelStyle: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ),
    );
  }

  /// E.g. "10 readings from 1 Jun to 10 Jun, lowest 36.0 °C, highest 36.9 °C".
  String describe() {
    if (readings.isEmpty) return 'No temperature readings yet';
    final temps = readings.map((r) => r.celsius);
    final today = readings.last.date;
    final low = temps.reduce((a, b) => a < b ? a : b).toStringAsFixed(1);
    final high = temps.reduce((a, b) => a > b ? a : b).toStringAsFixed(1);
    return '${readings.length} readings from '
        '${formatShortDate(readings.first.date, today: today)} to '
        '${formatShortDate(readings.last.date, today: today)}, '
        'lowest $low °C, highest $high °C';
  }
}

class _Painter extends CustomPainter {
  _Painter({
    required this.readings,
    required this.periodStarts,
    required this.line,
    required this.marker,
    required this.grid,
    required this.text,
    required this.labelStyle,
  });

  final List<TemperatureReading> readings;
  final Set<DateTime> periodStarts;
  final Color line;
  final Color marker;
  final Color grid;
  final Color text;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;
    final temps = readings.map((r) => r.celsius).toList();
    var low = temps.reduce((a, b) => a < b ? a : b);
    var high = temps.reduce((a, b) => a > b ? a : b);
    if (high - low < 0.5) {
      final mid = (high + low) / 2;
      low = mid - 0.25;
      high = mid + 0.25;
    }
    const left = Sizes.chartLabelGutter;
    const top = Space.sm;
    final height = size.height - top - Space.lg;
    final width = size.width - left;
    double y(double t) => top + height * (1 - (t - low) / (high - low));
    double x(int i) =>
        left +
        (readings.length == 1 ? width / 2 : width * i / (readings.length - 1));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final t = low + (high - low) * frac;
      canvas.drawLine(Offset(left, y(t)), Offset(size.width, y(t)), gridPaint);
      _label(canvas, t.toStringAsFixed(1), Offset(0, y(t) - Space.sm));
    }

    final markerPaint = Paint()
      ..color = marker
      ..strokeWidth = 2;
    for (var i = 0; i < readings.length; i++) {
      if (!periodStarts.contains(readings[i].date)) continue;
      canvas.drawLine(
        Offset(x(i), top),
        Offset(x(i), top + height),
        markerPaint,
      );
    }

    final path = Path();
    for (var i = 0; i < readings.length; i++) {
      final p = Offset(x(i), y(readings[i].celsius));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final dot = Paint()..color = line;
    for (var i = 0; i < readings.length; i++) {
      canvas.drawCircle(Offset(x(i), y(readings[i].celsius)), 3, dot);
    }
  }

  void _label(Canvas canvas, String value, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: labelStyle?.copyWith(color: text),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_Painter old) =>
      old.readings != readings ||
      old.periodStarts != periodStarts ||
      old.line != line;
}
