// Small per-device settings that must exist before there is a pod to read.

import 'dart:convert';

import 'package:lilith/domain/pod_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsStore {
  /// The provider chosen at the last login, if any.
  Future<PodProvider?> readProvider();

  Future<void> writeProvider(PodProvider provider);
}

class SharedPreferencesSettingsStore implements SettingsStore {
  static const String providerKey = 'pod_provider';

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
}
