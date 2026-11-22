import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/data_protection.dart';

void main() {
  test('encrypted is the recommended default', () {
    expect(DataProtection.recommended, DataProtection.encrypted);
  });

  test('each mode has its own document on the pod', () {
    expect(DataProtection.encrypted.documentPath, endsWith('.ttl'));
    expect(DataProtection.plain.documentPath, endsWith('.json'));
    expect(
      DataProtection.encrypted.documentPath,
      isNot(DataProtection.plain.documentPath),
    );
  });

  group('setupStateFor', () {
    final cases = <({String name, PodInspection seen, SetupState want})>[
      (
        name: 'a plain document means plain, ready',
        seen: const PodInspection(
          plainDocumentExists: true,
          keysOnPod: true,
          keyOnDevice: true,
        ),
        want: const SetupState.ready(DataProtection.plain),
      ),
      (
        name: 'keys on the pod and on the device means encrypted, ready',
        seen: const PodInspection(
          plainDocumentExists: false,
          keysOnPod: true,
          keyOnDevice: true,
        ),
        want: const SetupState.ready(DataProtection.encrypted),
      ),
      (
        name: 'keys on the pod but not on this device means enter the key',
        seen: const PodInspection(
          plainDocumentExists: false,
          keysOnPod: true,
          keyOnDevice: false,
        ),
        want: const SetupState.enterKey(),
      ),
      (
        name: 'nothing on the pod means choose',
        seen: const PodInspection(
          plainDocumentExists: false,
          keysOnPod: false,
          keyOnDevice: false,
        ),
        want: const SetupState.choose(),
      ),
      (
        name: 'a stale device key with nothing on the pod still means choose',
        seen: const PodInspection(
          plainDocumentExists: false,
          keysOnPod: false,
          keyOnDevice: true,
        ),
        want: const SetupState.choose(),
      ),
    ];
    for (final c in cases) {
      test(c.name, () => expect(setupStateFor(c.seen), c.want));
    }
  });
}
