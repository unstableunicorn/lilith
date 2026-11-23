import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/domain/share.dart';
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

  test('keeps an invite until it is cleared', () async {
    expect(await store.readInvite(), isNull);
    const invite = ShareInvite(
      sharerWebId: 'https://x.example/p/profile/card#me',
      code: 'ABCD-EFGH-JKMN-PQRS',
    );
    await store.writeInvite(invite);
    expect(await store.readInvite(), invite);
    await store.clearInvite();
    expect(await store.readInvite(), isNull);
  });

  test('a corrupt stored invite reads as none', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsStore.inviteKey: '::not a uri::',
    });
    expect(await store.readInvite(), isNull);
  });

  test('keeps the daily reminder, off by default', () async {
    expect(await store.readReminder(), const ReminderSetting());
    const on = ReminderSetting(enabled: true, hour: 6, minute: 45);
    await store.writeReminder(on);
    expect(await store.readReminder(), on);
  });
}
