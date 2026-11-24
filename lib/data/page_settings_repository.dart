// Holds the device's page settings and saves each change.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/page_settings.dart';

class PageSettingsRepository extends ChangeNotifier {
  PageSettingsRepository(this._store);

  final SettingsStore _store;

  PageSettings _settings = const PageSettings();
  PageSettings get settings => _settings;

  Future<void> load() async {
    _settings = await _store.readPageSettings();
    notifyListeners();
  }

  Future<void> update(PageSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _store.writePageSettings(settings);
  }
}
