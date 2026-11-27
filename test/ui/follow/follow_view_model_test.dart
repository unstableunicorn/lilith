import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/follow/follow_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  ReceivedShare from(String name) => ReceivedShare(
    sharerWebId: 'https://pod.example.org/$name/profile/card#me',
    label: name,
    addedOn: DateTime(2026, 6),
  );
  final ada = from('ada');
  final bea = from('bea');

  late HealthRepository health;
  late FollowViewModel vm;

  setUp(() {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    vm = FollowViewModel(health);
  });

  test('is not loaded until the data is', () async {
    expect(vm.isLoaded, isFalse);
    await health.load();
    expect(vm.isLoaded, isTrue);
  });

  test('with nobody sharing there is no one to show or choose', () async {
    await health.load();
    expect(vm.people, isEmpty);
    expect(vm.followed, isNull);
    expect(vm.showsChooser, isFalse);
  });

  test('one sharer is shown, with no chooser', () async {
    await health.load();
    await health.apply((d) => d.withReceived(ada));
    expect(vm.people, [ada]);
    expect(vm.followed, ada);
    expect(vm.showsChooser, isFalse);
  });

  test('two sharers: the first shows, and a chooser is offered', () async {
    await health.load();
    await health.apply((d) => d.withReceived(ada).withReceived(bea));
    expect(vm.followed, ada);
    expect(vm.showsChooser, isTrue);
  });

  test('following someone is saved to the pod and tells listeners', () async {
    await health.load();
    await health.apply((d) => d.withReceived(ada).withReceived(bea));
    var told = 0;
    vm.addListener(() => told++);
    await vm.follow(bea);
    expect(vm.followed, bea);
    expect(health.data.following, bea.sharerWebId);
    expect(told, greaterThan(0));
  });
}
