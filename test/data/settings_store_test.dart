import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferencesSettingsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SharedPreferencesSettingsStore();
  });

  test('has no provider until one is written', () async {
    expect(await store.readProvider(), isNull);
  });

  test('reads back the provider it wrote', () async {
    await store.writeProvider(PodProvider.unstableUnicorn);
    expect(await store.readProvider(), PodProvider.unstableUnicorn);
    final custom = PodProvider.custom('https://pods.example.org')!;
    await store.writeProvider(custom);
    expect(await store.readProvider(), custom);
  });

  test('a corrupt stored value reads as no provider', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsStore.providerKey: 'not json',
    });
    expect(await store.readProvider(), isNull);
  });
}
