import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';

import '../../fakes/fake_pod_service.dart';

/// The contract every PodService keeps; run against the fake here.
void main() {
  late PodService pod;
  setUp(() => pod = FakePodService());

  test('a document that was never written reads as null', () async {
    expect(await pod.read('cycle_data.ttl'), isNull);
  });

  test('a written document reads back and a rewrite replaces it', () async {
    await pod.write('a.ttl', 'one', encrypted: true);
    expect(await pod.read('a.ttl'), 'one');
    await pod.write('a.ttl', 'two', encrypted: true);
    expect(await pod.read('a.ttl'), 'two');
    expect(await pod.read('b.ttl'), isNull);
  });

  test('failures are PodExceptions the repository can tell apart', () {
    const errors = <PodException>[
      PodNotLoggedInException(),
      PodAccessException('403'),
      PodUnavailableException('timeout'),
    ];
    expect(errors.map((e) => e.runtimeType).toSet().length, 3);
    for (final e in errors) {
      expect(e.toString(), contains(e.message));
    }
  });
}
