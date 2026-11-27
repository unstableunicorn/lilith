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

/// Moods and body signs on the Log tab, and which groups it shows.
void main() {
  final now = DateTime(2026, 6, 10, 9, 30);
  final day = DateTime(2026, 6, 10);
  final yesterday = DateTime(2026, 6, 9);
  late HealthRepository health;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
  });

  group('LogViewModel', () {
    late LogViewModel vm;

    setUp(() => vm = LogViewModel(health, now: () => now));

    test('a day starts with no signs and nothing to save', () {
      expect(vm.signs, BodySigns.none);
      expect(vm.isDirty, isFalse);
    });

    test('moods, digestion and skin toggle on and off, several at once', () {
      vm
        ..toggleMood(Mood.calm)
        ..toggleMood(Mood.happy)
        ..toggleMood(Mood.calm)
        ..toggleDigestion(Digestion.gas)
        ..toggleSkin(SkinSign.acne)
        ..toggleSkin(SkinSign.dry)
        ..toggleSkin(SkinSign.dry);
      expect(vm.signs.moods, {Mood.happy});
      expect(vm.signs.digestion, {Digestion.gas});
      expect(vm.signs.skin, {SkinSign.acne});
      expect(vm.isDirty, isTrue);
    });

    test('sleep, discharge and the pregnancy test hold one value or none', () {
      vm
        ..setSleep(SleepQuality.poor)
        ..setSleep(SleepQuality.good)
        ..setDischarge(Discharge.creamy)
        ..setPregnancyTest(PregnancyTest.negative);
      expect(vm.signs.sleep, SleepQuality.good);
      expect(vm.signs.discharge, Discharge.creamy);
      expect(vm.signs.pregnancyTest, PregnancyTest.negative);
      vm
        ..setSleep(null)
        ..setDischarge(null)
        ..setPregnancyTest(null);
      expect(vm.signs, BodySigns.none);
      expect(vm.isDirty, isFalse);
    });

    test('each edit tells listeners', () {
      var told = 0;
      vm
        ..addListener(() => told++)
        ..toggleMood(Mood.sad)
        ..setSleep(SleepQuality.okay);
      expect(told, 2);
    });

    test('saving stores the signs with the day, and they load back', () async {
      vm
        ..toggleMood(Mood.anxious)
        ..setSleep(SleepQuality.poor);
      await vm.save();
      expect(
        health.data.logFor(day),
        DailyLog(
          date: day,
          signs: BodySigns(
            moods: const {Mood.anxious},
            sleep: SleepQuality.poor,
          ),
        ),
      );
      final again = LogViewModel(health, now: () => now);
      expect(again.signs.moods, {Mood.anxious});
      expect(again.isSavedAsIs, isTrue);
    });

    test('clearing the day clears the signs', () {
      vm
        ..toggleMood(Mood.low)
        ..clear();
      expect(vm.signs, BodySigns.none);
    });

    test('only moods show until other groups are turned on', () {
      expect(vm.shows(LogGroup.moods), isTrue);
      for (final g in LogGroup.values.where((g) => g != LogGroup.moods)) {
        expect(vm.shows(g), isFalse, reason: g.name);
      }
    });

    test('a group turned on shows, and one turned off does not', () async {
      await health.apply(
        (d) => d
            .withLogGroup(LogGroup.sleep, shown: true)
            .withLogGroup(LogGroup.moods, shown: false),
      );
      expect(vm.shows(LogGroup.sleep), isTrue);
      expect(vm.shows(LogGroup.moods), isFalse);
    });

    test('a hidden group still shows on a day that holds something in it, '
        'so it can be seen and removed', () async {
      await health.apply(
        (d) => d.withDailyLog(
          DailyLog(
            date: yesterday,
            signs: BodySigns(
              skin: const {SkinSign.oily},
              pregnancyTest: PregnancyTest.negative,
            ),
          ),
        ),
      );
      expect(vm.shows(LogGroup.skin), isFalse);
      vm.pickDate(yesterday);
      expect(vm.shows(LogGroup.skin), isTrue);
      expect(vm.shows(LogGroup.pregnancyTest), isTrue);
      expect(vm.shows(LogGroup.discharge), isFalse);
      vm.toggleSkin(SkinSign.oily);
      expect(vm.shows(LogGroup.skin), isTrue, reason: 'until saved');
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

    testWidgets('shows moods and no other new group at first', (tester) async {
      await pump(tester);
      expect(find.byKey(LogKeys.group(LogGroup.moods)), findsOneWidget);
      for (final m in Mood.values) {
        expect(find.byKey(LogKeys.mood(m)), findsOneWidget);
      }
      for (final g in LogGroup.values.where((g) => g != LogGroup.moods)) {
        expect(find.byKey(LogKeys.group(g)), findsNothing, reason: g.name);
      }
      expect(find.byKey(LogKeys.sleep(SleepQuality.good)), findsNothing);
      expect(find.byKey(LogKeys.pregnancyTest(null)), findsNothing);
      await expectAccessible(tester);
    });

    testWidgets('tapping moods and saving stores them', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(LogKeys.mood(Mood.calm)));
      await tester.tap(find.byKey(LogKeys.mood(Mood.sensitive)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilterChip>(find.byKey(LogKeys.mood(Mood.calm))).selected,
        isTrue,
      );
      await tester.tap(find.byKey(LogKeys.save));
      await tester.pumpAndSettle();
      expect(health.data.logFor(day)!.signs.moods, {Mood.calm, Mood.sensitive});
    });

    testWidgets('with every group on, each has its choices, accessibly', (
      tester,
    ) async {
      await health.apply((d) {
        var next = d;
        for (final g in LogGroup.values) {
          next = next.withLogGroup(g, shown: true);
        }
        return next;
      });
      await pump(tester);
      for (final g in LogGroup.values) {
        expect(find.byKey(LogKeys.group(g)), findsOneWidget, reason: g.name);
      }
      for (final s in [null, ...SleepQuality.values]) {
        expect(find.byKey(LogKeys.sleep(s)), findsOneWidget);
      }
      for (final d in Digestion.values) {
        expect(find.byKey(LogKeys.digestion(d)), findsOneWidget);
      }
      for (final s in SkinSign.values) {
        expect(find.byKey(LogKeys.skin(s)), findsOneWidget);
      }
      for (final d in [null, ...Discharge.values]) {
        expect(find.byKey(LogKeys.discharge(d)), findsOneWidget);
      }
      for (final t in [null, ...PregnancyTest.values]) {
        expect(find.byKey(LogKeys.pregnancyTest(t)), findsOneWidget);
      }
      await expectAccessible(tester);
    });

    testWidgets('one tap each records sleep, digestion, skin, discharge and '
        'a pregnancy test', (tester) async {
      await health.apply((d) {
        var next = d;
        for (final g in LogGroup.values) {
          next = next.withLogGroup(g, shown: true);
        }
        return next;
      });
      await pump(tester);
      for (final key in [
        LogKeys.sleep(SleepQuality.poor),
        LogKeys.digestion(Digestion.indigestion),
        LogKeys.skin(SkinSign.dry),
        LogKeys.discharge(Discharge.eggWhite),
        LogKeys.pregnancyTest(PregnancyTest.negative),
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(LogKeys.sleep(SleepQuality.poor)))
            .selected,
        isTrue,
      );
      await tester.ensureVisible(find.byKey(LogKeys.save));
      await tester.tap(find.byKey(LogKeys.save));
      await tester.pumpAndSettle();
      expect(
        health.data.logFor(day)!.signs,
        BodySigns(
          sleep: SleepQuality.poor,
          digestion: const {Digestion.indigestion},
          skin: const {SkinSign.dry},
          discharge: Discharge.eggWhite,
          pregnancyTest: PregnancyTest.negative,
        ),
      );
    });

    testWidgets('with moods turned off the Log tab has none', (tester) async {
      await health.apply((d) => d.withLogGroup(LogGroup.moods, shown: false));
      await pump(tester);
      expect(find.byKey(LogKeys.group(LogGroup.moods)), findsNothing);
      expect(find.byKey(LogKeys.mood(Mood.calm)), findsNothing);
    });
  });
}
