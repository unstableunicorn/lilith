// Biometrics on Android and iOS through local_auth. Only the fingerprint
// or face: the PIN is the app's own, not the phone's.

import 'package:flutter/services.dart';
import 'package:lilith/data/biometrics.dart';
import 'package:local_auth/local_auth.dart';

class LocalBiometrics implements Biometrics {
  LocalBiometrics();

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}
