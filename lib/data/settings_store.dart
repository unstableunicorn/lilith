// Small per-device settings that must exist before there is a pod to read.

import 'dart:convert';

import 'package:lilith/domain/app_lock.dart';
import 'package:lilith/domain/contraception_reminders.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/domain/share.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsStore {
  /// The provider chosen at the last login, if any.
  Future<PodProvider?> readProvider();

  Future<void> writeProvider(PodProvider provider);

  /// An invite the app was opened with, kept until it has been acted on,
  /// since the login may leave and come back to the page in between.
  Future<ShareInvite?> readInvite();

  Future<void> writeInvite(ShareInvite invite);

  Future<void> clearInvite();

  /// The daily reminder as set on this device; off until set.
  Future<ReminderSetting> readReminder();

  Future<void> writeReminder(ReminderSetting setting);

  /// What the tabs show on this device; everything until set.
  Future<PageSettings> readPageSettings();

  Future<void> writePageSettings(PageSettings settings);

  /// The last day a late-period check-in was snoozed through, if any.
  Future<DateTime?> readSnoozedThrough();

  Future<void> writeSnoozedThrough(DateTime day);

  /// The pill, patch or ring state this phone keeps; empty until written.
  Future<DoseCache> readDoseCache();

  Future<void> writeDoseCache(DoseCache cache);

  /// The app lock on this phone; off until a PIN is set.
  Future<AppLock> readAppLock();

  Future<void> writeAppLock(AppLock lock);
}

class SharedPreferencesSettingsStore implements SettingsStore {
  static const String providerKey = 'pod_provider';
  static const String inviteKey = 'share_invite';
  static const String reminderKey = 'daily_reminder';
  static const String pageSettingsKey = 'page_settings';
  static const String snoozeKey = 'check_in_snoozed_through';
  static const String doseCacheKey = 'dose_cache';
  static const String appLockKey = 'app_lock';

  @override
  Future<AppLock> readAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(appLockKey);
    if (raw == null) return const AppLock();
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?>
          ? AppLock.fromJson(json)
          : const AppLock();
    } on FormatException {
      return const AppLock();
    }
  }

  @override
  Future<void> writeAppLock(AppLock lock) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appLockKey, jsonEncode(lock.toJson()));
  }

  /// Written from a notification's own isolate too, so read fresh.
  @override
  Future<DoseCache> readDoseCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(doseCacheKey);
    if (raw == null) return const DoseCache();
    try {
      return DoseCache.fromJson(jsonDecode(raw));
    } on Object {
      return const DoseCache();
    }
  }

  @override
  Future<void> writeDoseCache(DoseCache cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(doseCacheKey, jsonEncode(cache.toJson()));
  }

  /// A snooze is written from a notification's own isolate, so this one's
  /// cached copy is refreshed before reading it.
  @override
  Future<DateTime?> readSnoozedThrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(snoozeKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> writeSnoozedThrough(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(snoozeKey, dateOnly(day).toIso8601String());
  }

  @override
  Future<PodProvider?> readProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(providerKey);
    if (raw == null) return null;
    try {
      return PodProvider.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeProvider(PodProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(providerKey, jsonEncode(provider.toJson()));
  }

  @override
  Future<ShareInvite?> readInvite() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(inviteKey);
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    return uri == null ? null : ShareInvite.fromUri(uri);
  }

  @override
  Future<void> writeInvite(ShareInvite invite) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(inviteKey, invite.toUri(Uri()).toString());
  }

  @override
  Future<void> clearInvite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(inviteKey);
  }

  @override
  Future<ReminderSetting> readReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(reminderKey);
    if (raw == null) return const ReminderSetting();
    try {
      return ReminderSetting.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const ReminderSetting();
    }
  }

  @override
  Future<void> writeReminder(ReminderSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(reminderKey, jsonEncode(setting.toJson()));
  }

  @override
  Future<PageSettings> readPageSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pageSettingsKey);
    if (raw == null) return const PageSettings();
    try {
      return PageSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const PageSettings();
    }
  }

  @override
  Future<void> writePageSettings(PageSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pageSettingsKey, jsonEncode(settings.toJson()));
  }
}
