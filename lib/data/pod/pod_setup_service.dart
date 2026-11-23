// Setting a pod up for the app: the key files for encryption, or nothing.

import 'package:lilith/domain/data_protection.dart';

abstract interface class PodSetupService {
  /// Looks at the pod and this device. Needs a session.
  Future<PodInspection> inspect();

  /// Creates the app's folders and key files on the pod from [securityKey],
  /// and keeps the key on this device.
  Future<void> setUpEncryption(String securityKey);

  /// Creates the app's folders and an empty plain document.
  Future<void> setUpPlain();

  /// Verifies [securityKey] against the pod and keeps it on this device.
  /// Throws a PodWrongKeyException when it does not match.
  Future<void> unlock(String securityKey);

  /// Drops the key from this device; the pod is untouched.
  Future<void> forgetKey();
}
