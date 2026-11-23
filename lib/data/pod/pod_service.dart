// The only way to a Solid pod. Everything else in the app talks to this.

import 'package:lilith/domain/pod_provider.dart';

/// Reads and writes documents in the app's data folder on the user's pod.
/// Paths are relative to that folder; callers always see plain text.
abstract interface class PodService {
  PodProvider get provider;

  /// The document's content, or null when it does not exist.
  Future<String?> read(String path);

  /// Creates or replaces the document, encrypted on the device first when
  /// [encrypted].
  Future<void> write(String path, String content, {required bool encrypted});
}

/// Something went wrong talking to the pod.
sealed class PodException implements Exception {
  const PodException(this.message);
  final String message;
  @override
  // The type is the failure's name in a log; never shown to a user.
  // ignore: no_runtimetype_tostring
  String toString() => '$runtimeType: $message';
}

/// There is no session; the user has to log in.
class PodNotLoggedInException extends PodException {
  const PodNotLoggedInException() : super('not logged in');
}

/// The pod refused the request.
class PodAccessException extends PodException {
  const PodAccessException(super.message);
}

/// The pod could not be reached or did not answer properly.
class PodUnavailableException extends PodException {
  const PodUnavailableException(super.message);
}

/// The user did not finish logging in.
class PodLoginCancelledException extends PodException {
  const PodLoginCancelledException() : super('login cancelled');
}

/// The identity provider did not log the user in.
class PodLoginFailedException extends PodException {
  const PodLoginFailedException(super.message);
}

/// The security key does not match the pod's.
class PodWrongKeyException extends PodException {
  const PodWrongKeyException() : super('wrong security key');
}
