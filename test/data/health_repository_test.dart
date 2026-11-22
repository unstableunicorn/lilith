import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';

import '../fakes/fake_pod_service.dart';

void main() {
  const codec = HealthDocumentCodec();
  final may1 = DateTime(2026, 5, 1);
  final stored = HealthData.empty.withPeriod(PeriodEvent(startDate: may1));

  late FakePodService pod;
  late HealthRepository repo;
  late int notifications;

  setUp(() {
    pod = FakePodService();
    repo = HealthRepository(pod);
    notifications = 0;
    repo.addListener(() => notifications++);
  });

  test('starts empty, not loaded, without error', () {
    expect(repo.data, HealthData.empty);
    expect(repo.isLoaded, isFalse);
    expect(repo.isLoading, isFalse);
    expect(repo.error, isNull);
  });

  group('load', () {
    test('a missing document is a new user, not an error', () async {
      await repo.load();
      expect(repo.data, HealthData.empty);
      expect(repo.isLoaded, isTrue);
      expect(repo.error, isNull);
      expect(pod.reads, 1);
    });

    test('reads the stored document', () async {
      pod.documents[HealthRepository.documentPath] = codec.encode(stored);
      await repo.load();
      expect(repo.data, stored);
      expect(repo.isLoaded, isTrue);
    });

    test('notifies while loading and when done', () async {
      final seen = <bool>[];
      repo.addListener(() => seen.add(repo.isLoading));
      await repo.load();
      expect(seen, [true, false]);
    });

    test('does not read again once loaded, unless forced', () async {
      await repo.load();
      await repo.load();
      expect(pod.reads, 1);
      await repo.load(force: true);
      expect(pod.reads, 2);
    });

    test('reads once when called twice at the same time', () async {
      await Future.wait([repo.load(), repo.load()]);
      expect(pod.reads, 1);
    });

    final failures =
        <({String name, void Function() arrange, RepositoryError want})>[
          (
            name: 'a refused read',
            arrange: () => pod.failReads = const PodAccessException('403'),
            want: RepositoryError.loadFailed,
          ),
          (
            name: 'an unreachable pod',
            arrange: () =>
                pod.failReads = const PodUnavailableException('timeout'),
            want: RepositoryError.loadFailed,
          ),
          (
            name: 'no session',
            arrange: () => pod.failReads = const PodNotLoggedInException(),
            want: RepositoryError.notLoggedIn,
          ),
          (
            name: 'a malformed document',
            arrange: () =>
                pod.documents[HealthRepository.documentPath] = 'not json',
            want: RepositoryError.malformed,
          ),
          (
            name: 'a document from a newer app',
            arrange: () =>
                pod.documents[HealthRepository.documentPath] = '{"version":99}',
            want: RepositoryError.newerVersion,
          ),
        ];
    for (final f in failures) {
      test(
        '${f.name} leaves the data untouched and reports ${f.want.name}',
        () async {
          f.arrange();
          await repo.load();
          expect(repo.error, f.want);
          expect(repo.isLoaded, isFalse);
          expect(repo.isLoading, isFalse);
          expect(repo.data, HealthData.empty);
        },
      );
    }

    test('a later successful load clears the error', () async {
      pod.failReads = const PodUnavailableException('timeout');
      await repo.load();
      pod.failReads = null;
      await repo.load();
      expect(repo.error, isNull);
      expect(repo.isLoaded, isTrue);
    });
  });

  group('apply', () {
    final reading = TemperatureReading(date: may1, celsius: 36.4);

    test('changes the data, notifies, and writes the whole document', () async {
      await repo.load();
      notifications = 0;
      await repo.apply((d) => d.withReading(reading));
      expect(repo.data.readings, [reading]);
      expect(pod.writes, 1);
      expect(
        codec.decode(pod.documents[HealthRepository.documentPath]!),
        repo.data,
      );
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('a change that changes nothing writes nothing', () async {
      await repo.load();
      await repo.apply((d) => d);
      expect(pod.writes, 0);
    });

    test('a refused write keeps the change and reports saveFailed', () async {
      await repo.load();
      pod.failWrites = const PodAccessException('403');
      await repo.apply((d) => d.withReading(reading));
      expect(repo.data.readings, [reading]);
      expect(repo.error, RepositoryError.saveFailed);
      expect(pod.documents[HealthRepository.documentPath], isNull);
    });

    test('a lost session on write reports notLoggedIn', () async {
      await repo.load();
      pod.failWrites = const PodNotLoggedInException();
      await repo.apply((d) => d.withReading(reading));
      expect(repo.error, RepositoryError.notLoggedIn);
    });

    test('the next successful write clears the error', () async {
      await repo.load();
      pod.failWrites = const PodAccessException('403');
      await repo.apply((d) => d.withReading(reading));
      pod.failWrites = null;
      await repo.apply((d) => d.withPeriod(PeriodEvent(startDate: may1)));
      expect(repo.error, isNull);
      expect(
        codec.decode(pod.documents[HealthRepository.documentPath]!),
        repo.data,
      );
    });

    test('refuses to write before a load has succeeded', () async {
      await repo.apply((d) => d.withReading(reading));
      expect(pod.writes, 0);
      expect(repo.data, HealthData.empty);
      expect(repo.error, RepositoryError.notLoaded);
    });
  });

  test('clearError drops the error and notifies', () async {
    pod.failReads = const PodUnavailableException('timeout');
    await repo.load();
    notifications = 0;
    repo.clearError();
    expect(repo.error, isNull);
    expect(notifications, 1);
  });
}
