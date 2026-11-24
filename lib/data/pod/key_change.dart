// Changing the security key with copies of the key files taken first, so a
// change that fails part way can be undone.

import 'package:lilith/data/pod/pod_service.dart';

/// Reads and writes the pod's key files by URL.
abstract interface class KeyFileStore {
  Future<String> read(String url);
  Future<void> write(String url, String content);
}

/// Copies [urls] from [store], then runs [change]. A PodWrongKeyException
/// passes through untouched, since nothing was written. Any other failure
/// writes the copies back, runs [afterFailure], and throws a
/// PodKeyChangeException saying whether every copy went back.
Future<void> changeWithBackup({
  required KeyFileStore store,
  required List<String> urls,
  required Future<void> Function() change,
  required Future<void> Function() afterFailure,
}) async {
  final copies = {for (final url in urls) url: await store.read(url)};
  try {
    await change();
  } on PodWrongKeyException {
    rethrow;
  } on Object catch (e) {
    var restored = true;
    for (final MapEntry(key: url, value: content) in copies.entries) {
      restored = await _writeBack(store, url, content) && restored;
    }
    await afterFailure();
    // The type only: a key library's message could echo a key.
    throw PodKeyChangeException('${e.runtimeType}', restored: restored);
  }
}

/// How many times a copy is written back before giving up.
const int restoreAttempts = 3;

Future<bool> _writeBack(KeyFileStore store, String url, String content) async {
  for (var attempt = 0; attempt < restoreAttempts; attempt++) {
    try {
      await store.write(url, content);
      return true;
    } on Object {
      continue;
    }
  }
  return false;
}
