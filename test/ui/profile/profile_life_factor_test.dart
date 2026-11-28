import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/ui/profile/profile_screen.dart';
import 'package:lilith/ui/profile/profile_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

/// Life factors on the profile: starting, dating, ending and removing one.
void main() {
  final now = DateTime(2026, 6, 10, 9, 30);
  final today = DateTime(2026, 6, 10);
  late HealthRepository health;

  LifeFactor factor(
    LifeFactorKind kind, {
    DateTime? start,
    DateTime? end,
    DateTime? due,
  }) => LifeFactor(kind: kind, start: start ?? today, end: end, dueDate: due);

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
  });

  group('ProfileViewModel', () {
    late ProfileViewModel vm;

    setUp(() => vm = ProfileViewModel(health, now: () => now));

    test('starts with the factors the pod holds', () async {
      expect(vm.lifeFactors, isEmpty);
      final stored = factor(LifeFactorKind.pregnant, start: DateTime(2026, 5));
      await health.apply(
        (d) => d.withProfile(HealthProfile(lifeFactors: [stored])),
      );
      expect(ProfileViewModel(health, now: () => now).lifeFactors, [stored]);
    });

    test('starting one adds it from today and is something to save', () {
      var told = 0;
      vm
        ..addListener(() => told++)
        ..startFactor(LifeFactorKind.pregnant);
      expect(vm.lifeFactors, [factor(LifeFactorKind.pregnant)]);
      expect(vm.isDirty, isTrue);
      expect(told, 1);
    });

    test('a kind that is already open is not started twice', () {
      vm
        ..startFactor(LifeFactorKind.pregnant)
        ..startFactor(LifeFactorKind.pregnant)
        ..startFactor(LifeFactorKind.breastfeeding);
      expect(vm.lifeFactors, hasLength(2));
    });

    test('a kind that has ended can be started again', () {
      vm
        ..startFactor(LifeFactorKind.breastfeeding)
        ..endFactor(vm.lifeFactors.single)
        ..startFactor(LifeFactorKind.breastfeeding);
      expect(vm.lifeFactors, hasLength(2));
    });

    test('its start can be moved back, not past today', () {
      vm.startFactor(LifeFactorKind.pregnant);
      vm.setFactorStart(vm.lifeFactors.single, DateTime(2026, 4, 2, 13));
      expect(vm.lifeFactors.single.start, DateTime(2026, 4, 2));
      vm.setFactorStart(vm.lifeFactors.single, DateTime(2026, 6, 11));
      expect(vm.lifeFactors.single.start, DateTime(2026, 4, 2));
    });

    test('a pregnancy takes a due date, and gives it up again', () {
      vm.startFactor(LifeFactorKind.pregnant);
      vm.setFactorDue(vm.lifeFactors.single, DateTime(2026, 12, 20));
      expect(vm.lifeFactors.single.dueDate, DateTime(2026, 12, 20));
      vm.setFactorDue(vm.lifeFactors.single, null);
      expect(vm.lifeFactors.single.dueDate, isNull);
    });

    test('ending one sets today as its last day', () {
      vm.startFactor(LifeFactorKind.pregnant);
      vm.setFactorStart(vm.lifeFactors.single, DateTime(2026, 4, 2));
      vm.endFactor(vm.lifeFactors.single);
      expect(vm.lifeFactors.single.end, today);
    });

    test('removing one takes it out', () {
      vm
        ..startFactor(LifeFactorKind.pregnant)
        ..startFactor(LifeFactorKind.breastfeeding);
      vm.removeFactor(vm.lifeFactors.first);
      expect(vm.lifeFactors, hasLength(1));
      vm.removeFactor(vm.lifeFactors.single);
      expect(vm.lifeFactors, isEmpty);
      expect(vm.isDirty, isFalse);
    });

    test('saving stores them with the rest of the profile', () async {
      vm
        ..toggleCondition(ReproductiveCondition.pcos)
        ..startFactor(LifeFactorKind.miscarriage);
      await vm.save();
      expect(health.data.profile.lifeFactors, [
        factor(LifeFactorKind.miscarriage),
      ]);
      expect(health.data.profile.conditions, {ReproductiveCondition.pcos});
      expect(vm.isDirty, isFalse);
    });
  });

  group('ProfileScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3200);
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

    testWidgets('offers each kind to start, and says what it does', (
      tester,
    ) async {
      await pump(tester);
      for (final k in LifeFactorKind.values) {
        expect(find.byKey(ProfileKeys.startFactor(k)), findsOneWidget);
      }
      expect(
        find.textContaining('predictions and the fertile window pause'),
        findsOneWidget,
      );
      expect(find.byKey(ProfileKeys.factor(0)), findsNothing);
      await expectAccessible(tester);
    });

    testWidgets('starting a pregnancy shows it with its dates to set, and '
        'saving stores it', (tester) async {
      await pump(tester);
      await tapOn(tester, ProfileKeys.startFactor(LifeFactorKind.pregnant));
      expect(find.byKey(ProfileKeys.factor(0)), findsOneWidget);
      expect(find.text('Pregnant since 10 Jun'), findsOneWidget);
      expect(find.byKey(ProfileKeys.factorStart(0)), findsOneWidget);
      expect(find.byKey(ProfileKeys.factorDue(0)), findsOneWidget);
      expect(find.byKey(ProfileKeys.endFactor(0)), findsOneWidget);
      expect(find.byKey(ProfileKeys.removeFactor(0)), findsOneWidget);
      await expectAccessible(tester);
      await tapOn(tester, ProfileKeys.save);
      expect(health.data.profile.lifeFactors, [
        factor(LifeFactorKind.pregnant),
      ]);
    });

    testWidgets('only a pregnancy has a due date to set', (tester) async {
      await pump(tester);
      await tapOn(
        tester,
        ProfileKeys.startFactor(LifeFactorKind.breastfeeding),
      );
      expect(find.text('Breastfeeding since 10 Jun'), findsOneWidget);
      expect(find.byKey(ProfileKeys.factorDue(0)), findsNothing);
    });

    testWidgets('the start is picked from a calendar that stops at today', (
      tester,
    ) async {
      await pump(tester);
      await tapOn(tester, ProfileKeys.startFactor(LifeFactorKind.pregnant));
      await tapOn(tester, ProfileKeys.factorStart(0));
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, today);
      expect(picker.initialDate, today);
      await tester.tap(find.text('3'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Pregnant since 3 Jun'), findsOneWidget);
    });

    testWidgets('the due date is picked from today on', (tester) async {
      await pump(tester);
      await tapOn(tester, ProfileKeys.startFactor(LifeFactorKind.pregnant));
      await tapOn(tester, ProfileKeys.factorDue(0));
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, today);
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Pregnant since 10 Jun, due 20 Jun'), findsOneWidget);
    });

    testWidgets('ending one keeps it as history without its buttons to '
        'date or end it', (tester) async {
      await health.apply(
        (d) => d.withProfile(
          HealthProfile(
            lifeFactors: [
              factor(LifeFactorKind.pregnant, start: DateTime(2026, 4, 2)),
            ],
          ),
        ),
      );
      await pump(tester);
      expect(find.text('Pregnant since 2 Apr'), findsOneWidget);
      await tapOn(tester, ProfileKeys.endFactor(0));
      expect(find.text('Pregnant, 2 Apr to 10 Jun'), findsOneWidget);
      expect(find.byKey(ProfileKeys.endFactor(0)), findsNothing);
      expect(find.byKey(ProfileKeys.factorStart(0)), findsNothing);
      expect(find.byKey(ProfileKeys.removeFactor(0)), findsOneWidget);
      await tapOn(tester, ProfileKeys.save);
      expect(health.data.profile.lifeFactors.single.end, today);
    });

    testWidgets('removing one takes its card away', (tester) async {
      await pump(tester);
      await tapOn(tester, ProfileKeys.startFactor(LifeFactorKind.miscarriage));
      expect(find.text('Miscarriage on 10 Jun'), findsOneWidget);
      await tapOn(tester, ProfileKeys.removeFactor(0));
      expect(find.byKey(ProfileKeys.factor(0)), findsNothing);
    });
  });
}
