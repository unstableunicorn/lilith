// The phone's fingerprint or face check, behind a seam so tests and the
// web have none.

abstract interface class Biometrics {
  /// Whether the phone has a fingerprint or face enrolled.
  Future<bool> isAvailable();

  /// Asks for it, saying [reason]; true when it matched.
  Future<bool> authenticate(String reason);
}

/// Where there is none: the web.
class NoBiometrics implements Biometrics {
  const NoBiometrics();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
