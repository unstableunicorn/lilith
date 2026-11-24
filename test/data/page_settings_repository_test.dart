import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/domain/page_settings.dart';

import '../fakes/fake_settings_store.dart';

void main() {
  test('defaults show everything', () {
    const s = PageSettings();
    expect(s.showFact, isTrue);
    expect(s.showForecast, isTrue);
    expect(s.showCalendar, isTrue);
    expect(s.showTemperatureChart, isTrue);
  });

  test('round-trips through JSON and reads missing keys as the default', () {
    const s = PageSettings(showFact: false, showCalendar: false);
    expect(PageSettings.fromJson(s.toJson()), s);
    expect(PageSettings.fromJson(const {}), const PageSettings());
  });

  test('the repository loads from the store and saves each change', () async {
    final store = FakeSettingsStore();
    await store.writePageSettings(const PageSettings(showForecast: false));
    final repo = PageSettingsRepository(store);
    await repo.load();
    expect(repo.settings.showForecast, isFalse);

    var notified = 0;
    repo.addListener(() => notified++);
    await repo.update(repo.settings.copyWith(showCalendar: false));
    expect(notified, 1);
    expect((await store.readPageSettings()).showCalendar, isFalse);
    expect((await store.readPageSettings()).showForecast, isFalse);
  });
}
