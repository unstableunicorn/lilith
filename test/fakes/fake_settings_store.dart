import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/app_lock.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/domain/share.dart';

/// Settings kept in memory for a test.
class FakeSettingsStore implements SettingsStore {
  PodProvider? provider;
  ShareInvite? invite;
  ReminderSetting reminder = const ReminderSetting();
  PageSettings pageSettings = const PageSettings();
  DateTime? snoozedThrough;
  DoseCache doseCache = const DoseCache();
  AppLock appLock = const AppLock();

  @override
  Future<AppLock> readAppLock() async => appLock;

  @override
  Future<void> writeAppLock(AppLock lock) async => appLock = lock;

  @override
  Future<DoseCache> readDoseCache() async => doseCache;

  @override
  Future<void> writeDoseCache(DoseCache cache) async => doseCache = cache;

  @override
  Future<DateTime?> readSnoozedThrough() async => snoozedThrough;

  @override
  Future<void> writeSnoozedThrough(DateTime day) async => snoozedThrough = day;

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

  @override
  Future<ReminderSetting> readReminder() async => reminder;

  @override
  Future<void> writeReminder(ReminderSetting setting) async =>
      reminder = setting;

  @override
  Future<PageSettings> readPageSettings() async => pageSettings;

  @override
  Future<void> writePageSettings(PageSettings settings) async =>
      pageSettings = settings;
}
