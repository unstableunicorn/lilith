// A value over days: points placed by date, shaded spans for the phases,
// marked starts, date ticks, a legend, and a sentence saying the same.

import 'package:lilith/domain/day.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

/// One plotted value on one day.
@immutable
class ChartPoint {
  ChartPoint({required DateTime date, required this.value})
    : date = dateOnly(date);

  final DateTime date;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is ChartPoint && other.date == date && other.value == value;

  @override
  int get hashCode => Object.hash(date, value);
}

/// A run of days, first and last included; an open span ends on [end] as
/// given, which a caller sets to the last plotted day.
@immutable
class ChartSpan {
  ChartSpan({required DateTime start, required DateTime end})
    : start = dateOnly(start),
      end = dateOnly(end);

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is ChartSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Where everything goes, as fractions of the plot area, so the drawing and
/// its tests share one answer. Values grow upward: y 0 is the bottom.
@immutable
class ChartLayout {
  const ChartLayout({
    required this.first,
    required this.last,
    required this.low,
    required this.high,
    required this.ticks,
  });

  /// The whole range of days shown, and of values shown.
  final DateTime first;
  final DateTime last;
  final double low;
  final double high;

  /// The days labelled along the bottom.
  final List<DateTime> ticks;

  int get dayCount => daysBetween(first, last) + 1;

  /// 0 at the first day, 1 at the last; a single day sits in the middle.
  double xOf(DateTime day) =>
      dayCount == 1 ? 0.5 : daysBetween(first, dateOnly(day)) / (dayCount - 1);

  /// 0 at [low], 1 at [high].
  double yOf(double value) => (value - low) / (high - low);
}

/// The layout for [points]: the day range is theirs (widened to any span),
/// the value range is theirs padded to at least [minimumRange], and a zero
/// line is included when asked. Ticks fall on the first, middle and last day.
ChartLayout chartLayout(
  List<ChartPoint> points, {
  Iterable<ChartSpan> spans = const [],
  bool zeroLine = false,
  double minimumRange = 0.5,
}) {
  final days = [
    ...points.map((p) => p.date),
    for (final s in spans) ...[s.start, s.end],
  ];
  var first = days.reduce((a, b) => a.isBefore(b) ? a : b);
  var last = days.reduce((a, b) => a.isAfter(b) ? a : b);
  final values = points.map((p) => p.value);
  var low = values.reduce((a, b) => a < b ? a : b);
  var high = values.reduce((a, b) => a > b ? a : b);
  if (zeroLine) {
    if (low > 0) low = 0;
    if (high < 0) high = 0;
  }
  if (high - low < minimumRange) {
    final mid = (high + low) / 2;
    low = mid - minimumRange / 2;
    high = mid + minimumRange / 2;
  }
  final span = daysBetween(first, last);
  final ticks = span == 0
      ? [first]
      : {first, addDays(first, span ~/ 2), last}.toList();
  first = dateOnly(first);
  last = dateOnly(last);
  return ChartLayout(
    first: first,
    last: last,
    low: low,
    high: high,
    ticks: ticks,
  );
}

class TrendChart extends StatelessWidget {
  const TrendChart({
    required this.points,
    required this.unit,
    this.menstrual = const [],
    this.luteal,
    this.starts = const {},
    this.zeroLine = false,
    this.subject = 'temperature',
    super.key,
  });

  /// Oldest first.
  final List<ChartPoint> points;

  /// Shown after values in labels and the description, e.g. "°C".
  final String unit;

  /// Period days, shaded.
  final List<ChartSpan> menstrual;

  /// From the estimated ovulation to the predicted period, shaded lighter.
  final ChartSpan? luteal;

  /// Period starts, marked with a shape as well as a colour.
  final Set<DateTime> starts;

  /// Draw and include a line at zero: for a series of changes.
  final bool zeroLine;

  /// What the values are, for the description.
  final String subject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      label: describe(),
      image: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: Sizes.chart,
              child: CustomPaint(
                size: Size.infinite,
                painter: _Painter(
                  points: points,
                  layout: points.isEmpty
                      ? null
                      : chartLayout(
                          points,
                          spans: [...menstrual, ?luteal],
                          zeroLine: zeroLine,
                        ),
                  menstrual: menstrual,
                  luteal: luteal,
                  starts: starts,
                  zeroLine: zeroLine,
                  unit: unit,
                  line: scheme.primary,
                  marker: scheme.error,
                  menstrualFill: scheme.errorContainer,
                  lutealFill: scheme.secondaryContainer,
                  grid: scheme.outlineVariant,
                  text: scheme.onSurfaceVariant,
                  labelStyle: labelStyle,
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.md,
              runSpacing: Space.xs,
              children: [
                _LegendItem(color: scheme.primary, label: subject),
                if (menstrual.isNotEmpty)
                  _LegendItem(color: scheme.errorContainer, label: 'period'),
                if (starts.isNotEmpty)
                  _LegendItem(
                    color: scheme.error,
                    label: 'period start',
                    shape: _LegendShape.marker,
                  ),
                if (luteal != null)
                  _LegendItem(
                    color: scheme.secondaryContainer,
                    label: 'after ovulation',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// E.g. "10 temperature readings from 1 Jun to 10 Jun, lowest 36.0 °C,
  /// highest 36.9 °C, 1 period, 1 period start".
  String describe() {
    if (points.isEmpty) return 'No $subject readings yet';
    final values = points.map((p) => p.value);
    final today = points.last.date;
    final low = values.reduce((a, b) => a < b ? a : b).toStringAsFixed(1);
    final high = values.reduce((a, b) => a > b ? a : b).toStringAsFixed(1);
    final extras = [
      if (menstrual.isNotEmpty)
        '${menstrual.length} ${menstrual.length == 1 ? 'period' : 'periods'}',
      if (luteal != null) 'the days after ovulation',
    ];
    return '${points.length} $subject readings from '
        '${formatShortDate(points.first.date, today: today)} to '
        '${formatShortDate(points.last.date, today: today)}, '
        'lowest $low $unit, highest $high $unit'
        '${extras.isEmpty ? '' : ', ${extras.join(', ')}'}';
  }
}

enum _LegendShape { swatch, marker }

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.shape = _LegendShape.swatch,
  });

  final Color color;
  final String label;
  final _LegendShape shape;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      switch (shape) {
        _LegendShape.swatch => Container(
          width: Space.md,
          height: Space.md,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Space.xs),
          ),
        ),
        _LegendShape.marker => Icon(
          Icons.arrow_drop_down_rounded,
          size: Space.lg,
          color: color,
        ),
      },
      const SizedBox(width: Space.xs),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _Painter extends CustomPainter {
  _Painter({
    required this.points,
    required this.layout,
    required this.menstrual,
    required this.luteal,
    required this.starts,
    required this.zeroLine,
    required this.unit,
    required this.line,
    required this.marker,
    required this.menstrualFill,
    required this.lutealFill,
    required this.grid,
    required this.text,
    required this.labelStyle,
  });

  final List<ChartPoint> points;
  final ChartLayout? layout;
  final List<ChartSpan> menstrual;
  final ChartSpan? luteal;
  final Set<DateTime> starts;
  final bool zeroLine;
  final String unit;
  final Color line;
  final Color marker;
  final Color menstrualFill;
  final Color lutealFill;
  final Color grid;
  final Color text;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = this.layout;
    if (layout == null) return;
    const left = Sizes.chartLabelGutter;
    const top = Space.sm;
    final bottom = size.height - Space.lg;
    final height = bottom - top;
    final width = size.width - left;
    double x(DateTime d) => left + width * layout.xOf(d);
    double y(double v) => top + height * (1 - layout.yOf(v));
    // A day is as wide as the gap between two neighbouring days.
    final dayWidth = width / layout.dayCount;

    void shade(ChartSpan span, Color color) {
      final rect = Rect.fromLTRB(
        x(span.start) - dayWidth / 2,
        top,
        x(span.end) + dayWidth / 2,
        bottom,
      ).intersect(Rect.fromLTRB(left, top, size.width, bottom));
      canvas.drawRect(rect, Paint()..color = color);
    }

    if (luteal case final l?) shade(l, lutealFill);
    for (final m in menstrual) {
      shade(m, menstrualFill);
    }

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final v = layout.low + (layout.high - layout.low) * frac;
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), gridPaint);
      _label(canvas, v.toStringAsFixed(1), Offset(0, y(v) - Space.sm));
    }
    if (zeroLine && layout.low < 0 && layout.high > 0) {
      canvas.drawLine(
        Offset(left, y(0)),
        Offset(size.width, y(0)),
        Paint()
          ..color = text
          ..strokeWidth = 1,
      );
    }
    for (final tick in layout.ticks) {
      final label = formatShortDate(tick, today: layout.last);
      final painter = _textPainter(label);
      final dx = (x(tick) - painter.width / 2).clamp(
        left,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(dx, bottom + Space.xs));
    }

    final markerPaint = Paint()..color = marker;
    for (final start in starts) {
      if (start.isBefore(layout.first) || start.isAfter(layout.last)) continue;
      final cx = x(start);
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx, bottom),
        Paint()
          ..color = marker
          ..strokeWidth = 2,
      );
      final tri = Path()
        ..moveTo(cx - Space.xs, top)
        ..lineTo(cx + Space.xs, top)
        ..lineTo(cx, top + Space.sm)
        ..close();
      canvas.drawPath(tri, markerPaint);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(x(points[i].date), y(points[i].value));
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
    for (final p in points) {
      canvas.drawCircle(Offset(x(p.date), y(p.value)), 3, dot);
    }
  }

  TextPainter _textPainter(String value) => TextPainter(
    text: TextSpan(
      text: value,
      style: labelStyle?.copyWith(color: text),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _label(Canvas canvas, String value, Offset at) =>
      _textPainter(value).paint(canvas, at);

  @override
  bool shouldRepaint(_Painter old) =>
      old.points != points ||
      old.menstrual != menstrual ||
      old.luteal != luteal ||
      old.starts != starts ||
      old.line != line ||
      old.grid != grid ||
      old.text != text ||
      old.menstrualFill != menstrualFill ||
      old.lutealFill != lutealFill;
}
