import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/wearable/wearable_repository.dart';
import 'package:lilith/data/wearable/wearable_source.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/wearable_night.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_wearable_source.dart';

void main() {
  final today = DateTime(2026, 6, 20, 9);
  late HealthRepository health;
  late FakeWearableSource source;
  late WearableRepository repo;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    source = FakeWearableSource();
    repo = WearableRepository(health, source, now: () => today);
  });

  test('without a source there is nothing to sync', () async {
    final none = WearableRepository(
      health,
      const NoWearableSource(),
      now: () => today,
    );
    expect(none.isAvailable, isFalse);
    await none.sync();
    expect(none.state, isA<WearableIdle>());
  });

  test('a sync reads the last 90 days and keeps every night', () async {
    source.nights = [
      WearableNight(date: DateTime(2026, 6, 18), celsius: 0.2),
      WearableNight(date: DateTime(2026, 6, 19), celsius: 0.3),
    ];
    await repo.sync();
    expect(source.windows.single, (
      DateTime(2026, 3, 22),
      DateTime(2026, 6, 20),
    ));
    expect(health.data.wearableNights, hasLength(2));
    expect(
      repo.state,
      isA<WearableSynced>().having((s) => s.nights, 'nights', 2),
    );
  });

  test('a refused permission is said and nothing is written', () async {
    source
      ..permission = false
      ..nights = [WearableNight(date: DateTime(2026, 6, 19), celsius: 0.3)];
    await repo.sync();
    expect(repo.state, isA<WearableRefused>());
    expect(health.data.wearableNights, isEmpty);
  });

  test('a failed read is reported and the data left as it was', () async {
    source.failRead = Exception('watch offline');
    await repo.sync();
    expect(repo.state, isA<WearableFailed>());
    expect(health.data.wearableNights, isEmpty);
  });

  test('syncing again replaces a night rather than adding to it', () async {
    source.nights = [WearableNight(date: DateTime(2026, 6, 19), celsius: 0.3)];
    await repo.sync();
    source.nights = [WearableNight(date: DateTime(2026, 6, 19), celsius: 0.1)];
    await repo.sync();
    expect(health.data.wearableNights.single.celsius, 0.1);
  });
}
