import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/log/log_screen.dart';
import 'package:lilith/ui/log/log_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

/// A miscarriage on the Log tab: offered with the pregnancy test group, and
/// always on a day that already holds one.
void main() {
  final now = DateTime(2026, 6, 10, 9, 30);
  final day = DateTime(2026, 6, 10);
  final marked = DateTime(2026, 6, 3);
  late HealthRepository health;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    await health.apply(
      (d) => d.withDailyLog(DailyLog(date: marked, miscarriage: true)),
    );
  });

  Future<void> groupOn() =>
      health.apply((d) => d.withLogGroup(LogGroup.pregnancyTest, shown: true));

  group('LogViewModel', () {
    LogViewModel vm() => LogViewModel(health, now: () => now);

    test('is not offered on a plain day until the pregnancy test group is '
        'shown', () async {
      expect(vm().offersMiscarriage, isFalse);
      await groupOn();
      expect(vm().offersMiscarriage, isTrue);
      expect(vm().miscarriage, isFalse);
    });

    test('a day that holds one always offers it', () {
      final v = vm()..pickDate(marked);
      expect(v.miscarriage, isTrue);
      expect(v.offersMiscarriage, isTrue);
      v.setMiscarriage(false);
      expect(v.offersMiscarriage, isTrue, reason: 'still stored');
    });

    test('marking it is something to save, and saving stores it', () async {
      await groupOn();
      final v = vm();
      var told = 0;
      v
        ..addListener(() => told++)
        ..setMiscarriage(true);
      expect(v.miscarriage, isTrue);
      expect(v.isDirty, isTrue);
      expect(told, 1);
      await v.save();
      expect(health.data.miscarriageDays, [marked, day]);
      expect(v.isDirty, isFalse);
    });

    test('unmarking and saving clears a day that held nothing else', () async {
      final v = vm()
        ..pickDate(marked)
        ..setMiscarriage(false);
      await v.save();
      expect(health.data.miscarriageDays, isEmpty);
      expect(health.data.logFor(marked), isNull);
    });

    test('logging one starts no period', () async {
      await groupOn();
      final v = vm()..setMiscarriage(true);
      await v.save();
      expect(health.data.periods, isEmpty);
    });
  });

  group('LogScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          session: SessionRepository(
            FakePodSessionService(),
            FakeSettingsStore(),
          ),
          health: health,
          child: LogScreen(now: () => now),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool on(WidgetTester tester) =>
        tester.widget<SwitchListTile>(find.byKey(LogKeys.miscarriage)).value;

    testWidgets('has no switch for it on a plain day', (tester) async {
      await pump(tester);
      expect(find.byKey(LogKeys.miscarriage), findsNothing);
    });

    testWidgets('with the pregnancy test group shown, a switch marks the '
        'day and saving stores it', (tester) async {
      await groupOn();
      await pump(tester);
      expect(on(tester), isFalse);
      await expectAccessible(tester);
      await tester.ensureVisible(find.byKey(LogKeys.miscarriage));
      await tester.tap(find.byKey(LogKeys.miscarriage));
      await tester.pumpAndSettle();
      expect(on(tester), isTrue);
      await tester.ensureVisible(find.byKey(LogKeys.save));
      await tester.tap(find.byKey(LogKeys.save));
      await tester.pumpAndSettle();
      expect(health.data.miscarriageDays, [marked, day]);
    });
  });
}
