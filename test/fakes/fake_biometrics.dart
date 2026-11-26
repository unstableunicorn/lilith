import 'package:lilith/data/biometrics.dart';

/// A fingerprint reader that answers as told and counts the asks.
class FakeBiometrics implements Biometrics {
  bool available = true;
  bool answer = true;
  int asked = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return available && answer;
  }
}
