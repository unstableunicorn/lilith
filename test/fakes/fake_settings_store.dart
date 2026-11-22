import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';

/// Settings kept in memory for a test.
class FakeSettingsStore implements SettingsStore {
  PodProvider? provider;

  @override
  Future<PodProvider?> readProvider() async => provider;

  @override
  Future<void> writeProvider(PodProvider provider) async =>
      this.provider = provider;
}
