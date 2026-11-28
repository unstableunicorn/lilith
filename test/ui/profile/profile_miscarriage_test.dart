import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/profile/profile_screen.dart';
import 'package:lilith/ui/profile/profile_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

/// Miscarriages in the Profile's pregnancy history: the list comes from
/// the days they are logged on, and adding or removing one changes the day.
void main() {
  final now = DateTime(2026, 6, 10, 9, 30);
  final today = DateTime(2026, 6, 10);
  final april = DateTime(2026, 4, 2);
  final lastYear = DateTime(2025, 11, 3);
  late HealthRepository health;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
  });

  Future<void> logged(List<DailyLog> logs) =>
      health.apply((d) => logs.fold(d, (d, l) => d.withDailyLog(l)));

  group('ProfileViewModel', () {
    ProfileViewModel vm() => ProfileViewModel(health, now: () => now);

    test('lists the days logged, oldest first', () async {
      expect(vm().miscarriageDays, isEmpty);
      await logged([
        DailyLog(date: april, miscarriage: true),
        DailyLog(date: lastYear, miscarriage: true, painLevel: 5),
        DailyLog(date: DateTime(2026, 5), painLevel: 2),
      ]);
      expect(vm().miscarriageDays, [lastYear, april]);
      expect(vm().isDirty, isFalse);
    });

    test('adding a day is something to save, and tells its listeners', () {
      final v = vm();
      var told = 0;
      v
        ..addListener(() => told++)
        ..addMiscarriage(DateTime(2026, 4, 2, 16));
      expect(v.miscarriageDays, [april]);
      expect(v.isDirty, isTrue);
      expect(told, 1);
    });

    test('the same day twice, or a day after today, adds nothing', () {
      final v = vm()
        ..addMiscarriage(april)
        ..addMiscarriage(april)
        ..addMiscarriage(DateTime(2026, 6, 11));
      expect(v.miscarriageDays, [april]);
      v.addMiscarriage(today);
      expect(v.miscarriageDays, [april, today]);
    });

    test('adding then removing leaves nothing to save', () {
      final v = vm()
        ..addMiscarriage(april)
        ..removeMiscarriage(april);
      expect(v.miscarriageDays, isEmpty);
      expect(v.isDirty, isFalse);
    });

    test('saving marks the day in its log, keeping what it holds', () async {
      await logged([DailyLog(date: april, painLevel: 6)]);
      final v = vm()
        ..addMiscarriage(april)
        ..addMiscarriage(lastYear);
      await v.save();
      expect(health.data.miscarriageDays, [lastYear, april]);
      expect(health.data.logFor(april)!.painLevel, 6);
      expect(v.isDirty, isFalse);
    });

    test('saving a removal unmarks the day, and stores the rest of the '
        'profile with it', () async {
      await logged([
        DailyLog(date: april, miscarriage: true, painLevel: 6),
        DailyLog(date: lastYear, miscarriage: true),
      ]);
      final v = vm()
        ..removeMiscarriage(lastYear)
        ..toggleCondition(ReproductiveCondition.pcos);
      await v.save();
      expect(health.data.miscarriageDays, [april]);
      expect(health.data.logFor(lastYear), isNull);
      expect(health.data.profile.conditions, {ReproductiveCondition.pcos});
      expect(v.isDirty, isFalse);
    });

    test('a day marked on Log meanwhile is kept by a save that did not '
        'touch it', () async {
      final v = vm()..toggleCondition(ReproductiveCondition.pcos);
      await logged([DailyLog(date: april, miscarriage: true)]);
      await v.save();
      expect(health.data.miscarriageDays, [april]);
    });
  });

  group('ProfileScreen', () {
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
          child: ProfileScreen(now: () => now),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapOn(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('offers to add one, and lists none to begin with', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(ProfileKeys.addMiscarriage), findsOneWidget);
      expect(find.byKey(ProfileKeys.miscarriage(0)), findsNothing);
      await expectAccessible(tester);
    });

    testWidgets('lists the days logged, each with a way to remove it', (
      tester,
    ) async {
      await logged([
        DailyLog(date: april, miscarriage: true),
        DailyLog(date: lastYear, miscarriage: true),
      ]);
      await pump(tester);
      expect(
        find.descendant(
          of: find.byKey(ProfileKeys.miscarriage(0)),
          matching: find.text('3 Nov 2025'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ProfileKeys.miscarriage(1)),
          matching: find.text('2 Apr'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(ProfileKeys.removeMiscarriage(0)), findsOneWidget);
      expect(find.byKey(ProfileKeys.removeMiscarriage(1)), findsOneWidget);
      await expectAccessible(tester);
    });

    testWidgets('adding picks a day from a calendar that stops at today, '
        'and saving logs it on that day', (tester) async {
      await pump(tester);
      await tapOn(tester, ProfileKeys.addMiscarriage);
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, today);
      await tester.tap(find.text('3'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileKeys.miscarriage(0)), findsOneWidget);
      await tapOn(tester, ProfileKeys.save);
      expect(health.data.miscarriageDays, [DateTime(2026, 6, 3)]);
    });

    testWidgets('removing one and saving unmarks the day', (tester) async {
      await logged([DailyLog(date: april, miscarriage: true, painLevel: 3)]);
      await pump(tester);
      await tapOn(tester, ProfileKeys.removeMiscarriage(0));
      expect(find.byKey(ProfileKeys.miscarriage(0)), findsNothing);
      await tapOn(tester, ProfileKeys.save);
      expect(health.data.miscarriageDays, isEmpty);
      expect(health.data.logFor(april)!.painLevel, 3);
    });
  });
}
