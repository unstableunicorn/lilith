import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/setup/setup_view_model.dart';

import '../../fakes/fake_pod_setup_service.dart';

void main() {
  late FakePodSetupService pod;
  late SetupRepository repo;
  late SetupViewModel vm;

  setUp(() {
    pod = FakePodSetupService();
    repo = SetupRepository(pod);
    vm = SetupViewModel(repo);
  });

  test('recommends encryption and starts with it selected', () {
    expect(vm.choice, DataProtection.recommended);
    expect(vm.choice, DataProtection.encrypted);
  });

  group('a new security key', () {
    final cases =
        <({String name, String key, String confirm, KeyProblem? want})>[
          (
            name: 'empty is too short',
            key: '',
            confirm: '',
            want: KeyProblem.tooShort,
          ),
          (
            name: 'seven characters is too short',
            key: 'abcdefg',
            confirm: 'abcdefg',
            want: KeyProblem.tooShort,
          ),
          (
            name: 'eight characters is long enough',
            key: 'abcdefgh',
            confirm: 'abcdefgh',
            want: null,
          ),
          (
            name: 'a mismatch is a mismatch',
            key: 'abcdefgh',
            confirm: 'abcdefgx',
            want: KeyProblem.mismatch,
          ),
          (
            name: 'surrounding spaces count against it',
            key: ' abcdefgh ',
            confirm: 'abcdefgh',
            want: KeyProblem.mismatch,
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        vm.setKey(c.key);
        vm.setConfirmKey(c.confirm);
        expect(vm.keyProblem, c.want);
        expect(vm.canConfirm, c.want == null);
      });
    }
  });

  test('plain needs no key to confirm', () {
    vm.choose(DataProtection.plain);
    expect(vm.canConfirm, isTrue);
    expect(vm.keyProblem, isNull);
  });

  group('confirm', () {
    test('encrypted sets the pod up with the key', () async {
      vm.setKey('correct horse');
      vm.setConfirmKey('correct horse');
      await vm.confirm();
      expect(pod.podKey, 'correct horse');
      expect(repo.state, const SetupState.ready(DataProtection.encrypted));
    });

    test('plain sets the pod up without one', () async {
      vm.choose(DataProtection.plain);
      await vm.confirm();
      expect(pod.podKey, isNull);
      expect(repo.state, const SetupState.ready(DataProtection.plain));
    });

    test('does nothing while the key is not acceptable', () async {
      vm.setKey('short');
      await vm.confirm();
      expect(repo.state, isNot(isA<SetupReady>()));
    });
  });

  group('unlock', () {
    test('needs something typed', () {
      expect(vm.canUnlock, isFalse);
      vm.setKey('x');
      expect(vm.canUnlock, isTrue);
    });

    test('passes the key through', () async {
      pod.podKey = 'right';
      vm.setKey('right');
      await vm.unlock();
      expect(repo.state, const SetupState.ready(DataProtection.encrypted));
    });
  });

  test('the error and busy flag come from the repository', () async {
    pod.podKey = 'right';
    vm.setKey('wrong');
    await vm.unlock();
    expect(vm.error, SetupError.wrongKey);
    expect(vm.isBusy, isFalse);
  });
}
