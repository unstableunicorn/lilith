import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/share.dart';

/// Settings kept in memory for a test.
class FakeSettingsStore implements SettingsStore {
  PodProvider? provider;
  ShareInvite? invite;

  @override
  Future<PodProvider?> readProvider() async => provider;

  @override
  Future<void> writeProvider(PodProvider provider) async =>
      this.provider = provider;

  @override
  Future<ShareInvite?> readInvite() async => invite;

  @override
  Future<void> writeInvite(ShareInvite invite) async => this.invite = invite;

  @override
  Future<void> clearInvite() async => invite = null;
}
