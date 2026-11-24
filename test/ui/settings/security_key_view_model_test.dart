import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/ui/settings/security_key_view_model.dart';

import '../../fakes/fake_pod_setup_service.dart';

void main() {
  const current = 'old key 1';
  late FakePodSetupService pod;
  late SecurityKeyViewModel vm;

  setUp(() async {
    pod = FakePodSetupService();
    final repo = SetupRepository(pod);
    await repo.inspect();
    await repo.chooseEncrypted(current);
    vm = SecurityKeyViewModel(repo);
  });

  void fill(String now, String next, String again) => vm
    ..setCurrentKey(now)
    ..setNewKey(next)
    ..setConfirmKey(again);

  group('the new key', () {
    final cases =
        <({String name, String next, String again, NewKeyProblem? want})>[
          (name: 'empty is too short', next: '', again: '', want: .tooShort),
          (
            name: 'seven is too short',
            next: 'abcdefg',
            again: 'abcdefg',
            want: .tooShort,
          ),
          (
            name: 'eight is enough',
            next: 'abcdefgh',
            again: 'abcdefgh',
            want: null,
          ),
          (
            name: 'a mismatch',
            next: 'abcdefgh',
            again: 'abcdefgx',
            want: .mismatch,
          ),
          (
            name: 'the same as now',
            next: current,
            again: current,
            want: .sameAsCurrent,
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        fill(current, c.next, c.again);
        expect(vm.problem, c.want);
        expect(vm.canChange, c.want == null);
      });
    }

    test('needs the current key too', () {
      fill('', 'new key 2', 'new key 2');
      expect(vm.canChange, isFalse);
    });
  });

  test('a change that works says so and keeps the new key', () async {
    fill(current, 'new key 2', 'new key 2');
    final change = vm.change();
    expect(vm.isChanging, isTrue);
    expect(vm.canChange, isFalse);
    await change;
    expect(vm.isChanging, isFalse);
    expect(vm.outcome, KeyChangeOutcome.changed);
    expect(pod.podKey, 'new key 2');
  });

  test('a wrong current key says so and lets the user try again', () async {
    fill('not the key', 'new key 2', 'new key 2');
    await vm.change();
    expect(vm.outcome, KeyChangeOutcome.wrongKey);
    expect(pod.podKey, current);
    vm.setCurrentKey(current);
    expect(vm.outcome, isNull);
    await vm.change();
    expect(vm.outcome, KeyChangeOutcome.changed);
  });

  final failures = <(String, PodException, KeyChangeOutcome)>[
    ('restored', const PodKeyChangeException('x', restored: true), .unchanged),
    (
      'not restored',
      const PodKeyChangeException('x', restored: false),
      .broken,
    ),
  ];
  for (final (name, failure, outcome) in failures) {
    test('a failed change, $name, is reported', () async {
      pod.failChangeKey = failure;
      fill(current, 'new key 2', 'new key 2');
      await vm.change();
      expect(vm.outcome, outcome);
      expect(pod.podKey, current);
    });
  }

  test('does nothing while it cannot', () async {
    fill(current, 'short', 'short');
    await vm.change();
    expect(vm.outcome, isNull);
    expect(pod.podKey, current);
  });
}
