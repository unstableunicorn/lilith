import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/temperature_delta.dart';
import 'package:lilith/domain/temperature_reading.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);

  test('keeps the day only and round-trips through JSON', () {
    final d = TemperatureDelta(
      date: DateTime(2026, 6, 3, 7, 30),
      deltaCelsius: 0.25,
    );
    expect(d.date, june(3));
    expect(d.source, ReadingSource.watch);
    expect(TemperatureDelta.fromJson(d.toJson()), d);
  });

  test('withDeltas adds, replaces by day and keeps order', () {
    final data = HealthData.empty
        .withDeltas([
          TemperatureDelta(date: june(2), deltaCelsius: 0.1),
          TemperatureDelta(date: june(1), deltaCelsius: -0.1),
        ])
        .withDeltas([TemperatureDelta(date: june(2), deltaCelsius: 0.3)]);
    expect(data.temperatureDeltas.map((d) => d.date), [june(1), june(2)]);
    expect(data.temperatureDeltas.last.deltaCelsius, 0.3);
    expect(data.hasData, isTrue);
    expect(data.withoutDelta(june(2)).temperatureDeltas, hasLength(1));
  });

  test('deltas travel with a share', () {
    final data = HealthData.empty.withDeltas([
      TemperatureDelta(date: june(2), deltaCelsius: 0.1),
    ]);
    expect(sharedView(data).temperatureDeltas, data.temperatureDeltas);
  });
}
