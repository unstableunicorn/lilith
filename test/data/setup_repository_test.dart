import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/data_protection.dart';

import '../fakes/fake_pod_setup_service.dart';

void main() {
  late FakePodSetupService pod;
  late SetupRepository repo;

  setUp(() {
    pod = FakePodSetupService();
    repo = SetupRepository(pod);
  });

  test('starts unknown', () {
    expect(repo.state, const SetupState.unknown());
    expect(repo.isBusy, isFalse);
    expect(repo.error, isNull);
  });

  group('inspect', () {
    test('a fresh pod asks for a choice', () async {
      await repo.inspect();
      expect(repo.state, const SetupState.choose());
    });

    test('a pod set up on another device asks for the key', () async {
      pod.inspection = const PodInspection(
        plainDocumentExists: false,
        keysOnPod: true,
        keyOnDevice: false,
      );
      await repo.inspect();
      expect(repo.state, const SetupState.enterKey());
    });

    test('is busy while looking and notifies', () async {
      final seen = <bool>[];
      repo.addListener(() => seen.add(repo.isBusy));
      await repo.inspect();
      expect(seen.first, isTrue);
      expect(seen.last, isFalse);
    });

    test('an unreachable pod stays unknown with an error', () async {
      pod.failInspect = const PodUnavailableException('x');
      await repo.inspect();
      expect(repo.state, const SetupState.unknown());
      expect(repo.error, SetupError.unreachable);
    });
  });

  group('choosing', () {
    test('encrypted sets the key up and is ready', () async {
      await repo.inspect();
      await repo.chooseEncrypted('correct horse');
      expect(pod.podKey, 'correct horse');
      expect(repo.state, const SetupState.ready(DataProtection.encrypted));
      expect(repo.error, isNull);
    });

    test('plain is ready without a key', () async {
      await repo.inspect();
      await repo.choosePlain();
      expect(pod.podKey, isNull);
      expect(repo.state, const SetupState.ready(DataProtection.plain));
    });

    test('a failed set-up keeps the choice open with an error', () async {
      await repo.inspect();
      pod.failSetUp = const PodAccessException('403');
      await repo.chooseEncrypted('k');
      expect(repo.state, const SetupState.choose());
      expect(repo.error, SetupError.failed);
    });
  });

  group('unlock', () {
    setUp(() async {
      pod.podKey = 'right';
      pod.inspection = const PodInspection(
        plainDocumentExists: false,
        keysOnPod: true,
        keyOnDevice: false,
      );
      await repo.inspect();
    });

    test('the right key is ready', () async {
      await repo.unlock('right');
      expect(repo.state, const SetupState.ready(DataProtection.encrypted));
    });

    test('the wrong key says so and asks again', () async {
      await repo.unlock('wrong');
      expect(repo.state, const SetupState.enterKey());
      expect(repo.error, SetupError.wrongKey);
      await repo.unlock('right');
      expect(repo.error, isNull);
      expect(repo.state, const SetupState.ready(DataProtection.encrypted));
    });
  });

  test('reset forgets everything for the next login', () async {
    await repo.inspect();
    await repo.choosePlain();
    repo.reset();
    expect(repo.state, const SetupState.unknown());
    expect(repo.error, isNull);
  });
}
