import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/mode_memory.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_settings_store.dart';

void main() {
  late FakeSettingsStore store;
  late ModeMemory memory;

  setUp(() {
    store = FakeSettingsStore();
    memory = ModeMemory(store);
  });

  test('remembers nothing at first', () async {
    await memory.load();
    expect(memory.mode, isNull);
  });

  test('loads what the device kept, and tells', () async {
    store.mode = AppMode.partner;
    var told = 0;
    memory.addListener(() => told++);
    await memory.load();
    expect(memory.mode, AppMode.partner);
    expect(told, 1);
  });

  test('remembering keeps it on the device and tells once', () async {
    var told = 0;
    memory.addListener(() => told++);
    await memory.remember(AppMode.partner);
    await memory.remember(AppMode.partner);
    expect(memory.mode, AppMode.partner);
    expect(store.mode, AppMode.partner);
    expect(told, 1);
  });

  test('forgetting clears it from the device', () async {
    await memory.remember(AppMode.both);
    await memory.forget();
    expect(memory.mode, isNull);
    expect(store.mode, isNull);
  });

  test('the pod decides once it has loaded', () async {
    await memory.remember(AppMode.partner);
    expect(
      memory.modeFor(loaded: true, fromPod: AppMode.tracker),
      AppMode.tracker,
    );
  });

  test('until then the remembered mode shows', () async {
    await memory.remember(AppMode.partner);
    expect(
      memory.modeFor(loaded: false, fromPod: AppMode.tracker),
      AppMode.partner,
    );
  });

  test('with nothing remembered, a tracker shows until the pod loads', () {
    expect(
      memory.modeFor(loaded: false, fromPod: AppMode.tracker),
      AppMode.tracker,
    );
  });

  group('on the device', () {
    late SharedPreferencesSettingsStore prefs;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      prefs = SharedPreferencesSettingsStore();
    });

    test('there is no mode until one is written', () async {
      expect(await prefs.readMode(), isNull);
    });

    test('a mode is read back, and gone once cleared', () async {
      await prefs.writeMode(AppMode.partner);
      expect(await prefs.readMode(), AppMode.partner);
      await prefs.clearMode();
      expect(await prefs.readMode(), isNull);
    });

    test('a value this app does not know reads as none', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSettingsStore.modeKey: 'coach',
      });
      expect(await prefs.readMode(), isNull);
    });
  });
}
