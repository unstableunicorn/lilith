import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/app_lock.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/contraception_schedule.dart';
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

  test('keeps the day a check-in is snoozed through', () async {
    expect(await store.readSnoozedThrough(), isNull);
    await store.writeSnoozedThrough(DateTime(2026, 6, 25));
    expect(await store.readSnoozedThrough(), DateTime(2026, 6, 25));
  });

  test('keeps the dose cache, empty by default and when corrupt', () async {
    expect(await store.readDoseCache(), const DoseCache());
    final cache = DoseCache(
      schedule: ContraceptionSchedule(
        form: DoseForm.pill,
        start: DateTime(2026, 6, 1),
        daysOn: 21,
        daysOff: 7,
        windowHours: 12,
      ),
      done: {DateTime(2026, 6, 3)},
      pending: {DateTime(2026, 6, 4): DateTime(2026, 6, 4, 9, 5)},
    );
    await store.writeDoseCache(cache);
    expect(await store.readDoseCache(), cache);
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsStore.doseCacheKey: '{not json',
    });
    expect(await store.readDoseCache(), const DoseCache());
  });

  test('a corrupt snooze reads as none', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsStore.snoozeKey: 'soon',
    });
    expect(await store.readSnoozedThrough(), isNull);
  });

  test('keeps the app lock, off by default and when corrupt', () async {
    expect((await store.readAppLock()).isEnabled, isFalse);
    final on = AppLock(pin: PinHash.create('2468'), failures: 3);
    await store.writeAppLock(on);
    final back = await store.readAppLock();
    expect(back.pin?.matches('2468'), isTrue);
    expect(back.failures, 3);
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsStore.appLockKey: '{not json',
    });
    expect((await store.readAppLock()).isEnabled, isFalse);
  });
}
