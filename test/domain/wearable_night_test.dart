import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';

void main() {
  DateTime june(int d) => DateTime(2026, 6, d);

  test('keeps the day only and round-trips through JSON', () {
    final d = WearableNight(date: DateTime(2026, 6, 3, 7, 30), celsius: 0.25);
    expect(d.date, june(3));
    expect(d.source, ReadingSource.watch);
    expect(WearableNight.fromJson(d.toJson()), d);
  });

  test('withNights adds, replaces by day and keeps order', () {
    final data = HealthData.empty
        .withNights([
          WearableNight(date: june(2), celsius: 0.1),
          WearableNight(date: june(1), celsius: -0.1),
        ])
        .withNights([WearableNight(date: june(2), celsius: 0.3)]);
    expect(data.wearableNights.map((d) => d.date), [june(1), june(2)]);
    expect(data.wearableNights.last.celsius, 0.3);
    expect(data.hasData, isTrue);
    expect(data.withoutNight(june(2)).wearableNights, hasLength(1));
  });

  test('nights travel with a share', () {
    final data = HealthData.empty.withNights([
      WearableNight(date: june(2), celsius: 0.1),
    ]);
    expect(sharedView(data).wearableNights, data.wearableNights);
  });
}
