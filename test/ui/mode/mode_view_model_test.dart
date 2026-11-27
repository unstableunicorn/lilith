import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/mode/mode_view_model.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../fakes/fake_share_reader.dart';

void main() {
  const me = 'https://pod.example.org/me/profile/card#me';

  late FakePodService pod;
  late HealthRepository health;
  late FakeSettingsStore settings;
  late ReceivedShareRepository received;
  late ModeViewModel vm;

  setUp(() async {
    pod = FakePodService();
    health = HealthRepository(pod, protection: DataProtection.plain);
    await health.load();
    settings = FakeSettingsStore();
    received = ReceivedShareRepository(
      health,
      FakeShareReader(),
      ownWebId: me,
      settings: settings,
    );
    vm = ModeViewModel(health, received);
  });

  test('offers tracking first', () {
    expect(vm.choice, AppMode.tracker);
  });

  test('offers following first to someone who arrived by an invite', () async {
    settings.invite = const ShareInvite(
      sharerWebId: 'https://pod.example.org/ada/profile/card#me',
    );
    var told = 0;
    vm.addListener(() => told++);
    await received.loadInvite();
    expect(vm.choice, AppMode.partner);
    expect(told, greaterThan(0));
  });

  test('a pick replaces what was offered, invite or not', () async {
    settings.invite = const ShareInvite(
      sharerWebId: 'https://pod.example.org/ada/profile/card#me',
    );
    await received.loadInvite();
    var told = 0;
    vm
      ..addListener(() => told++)
      ..choose(AppMode.both);
    expect(vm.choice, AppMode.both);
    expect(told, 1);
  });

  test('confirming saves the choice to the pod', () async {
    vm.choose(AppMode.partner);
    final saving = vm.confirm();
    expect(vm.isBusy, isTrue);
    await saving;
    expect(vm.isBusy, isFalse);
    expect(health.data.mode, AppMode.partner);
    expect(pod.documents[health.documentPath], contains('"mode":"partner"'));
  });

  test('confirming what was offered saves that', () async {
    await vm.confirm();
    expect(health.data.mode, AppMode.tracker);
  });
}
