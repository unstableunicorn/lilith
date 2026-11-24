import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/key_change.dart';
import 'package:lilith/data/pod/pod_service.dart';

class FakeKeyFileStore implements KeyFileStore {
  FakeKeyFileStore(this.files);

  final Map<String, String> files;
  final List<String> writes = [];
  PodException? failRead;
  int failingWrites = 0;

  @override
  Future<String> read(String url) async {
    if (failRead case final e?) throw e;
    return files[url]!;
  }

  @override
  Future<void> write(String url, String content) async {
    if (failingWrites > 0) {
      failingWrites--;
      throw Exception('pod gone');
    }
    writes.add(url);
    files[url] = content;
  }
}

void main() {
  const enc = 'https://pod.example/a/lilith/encryption/enc-keys.ttl';
  const ind = 'https://pod.example/a/lilith/encryption/ind-keys.ttl';
  late FakeKeyFileStore store;
  late int resets;

  setUp(() {
    store = FakeKeyFileStore({enc: 'old enc', ind: 'old ind'});
    resets = 0;
  });

  Future<void> run(Future<void> Function() change) => changeWithBackup(
    store: store,
    urls: const [enc, ind],
    change: change,
    afterFailure: () async => resets++,
  );

  test('a change that works leaves the new files alone', () async {
    await run(() async {
      store.files[enc] = 'new enc';
      store.files[ind] = 'new ind';
    });
    expect(store.files, {enc: 'new enc', ind: 'new ind'});
    expect(store.writes, isEmpty);
    expect(resets, 0);
  });

  test('a wrong current key writes nothing back', () async {
    await expectLater(
      run(() async => throw const PodWrongKeyException()),
      throwsA(isA<PodWrongKeyException>()),
    );
    expect(store.writes, isEmpty);
    expect(resets, 0);
  });

  test('a failure part way writes both copies back', () async {
    await expectLater(
      run(() async {
        store.files[enc] = 'new enc';
        throw Exception('ind-keys write failed');
      }),
      throwsA(
        isA<PodKeyChangeException>().having(
          (e) => e.restored,
          'restored',
          true,
        ),
      ),
    );
    expect(store.files, {enc: 'old enc', ind: 'old ind'});
    expect(store.writes, [enc, ind]);
    expect(resets, 1);
  });

  test('a copy that fails to go back once is tried again', () async {
    await expectLater(
      run(() async {
        store
          ..files[enc] = 'new enc'
          ..failingWrites = 1;
        throw Exception('ind-keys write failed');
      }),
      throwsA(
        isA<PodKeyChangeException>().having(
          (e) => e.restored,
          'restored',
          true,
        ),
      ),
    );
    expect(store.files, {enc: 'old enc', ind: 'old ind'});
  });

  test('a restore that keeps failing says so', () async {
    await expectLater(
      run(() async {
        store
          ..files[enc] = 'new enc'
          ..failingWrites = 99;
        throw Exception('ind-keys write failed');
      }),
      throwsA(
        isA<PodKeyChangeException>().having(
          (e) => e.restored,
          'restored',
          false,
        ),
      ),
    );
    expect(resets, 1);
  });

  test('copies that cannot be read stop the change before it starts', () async {
    store.failRead = const PodUnavailableException('offline');
    var changed = false;
    await expectLater(
      run(() async => changed = true),
      throwsA(isA<PodUnavailableException>()),
    );
    expect(changed, isFalse);
    expect(store.writes, isEmpty);
  });
}
