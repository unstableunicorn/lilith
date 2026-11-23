import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/profile/profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late HealthRepository health;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        health: health,
        child: const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers every condition and treatment, and notes', (
    tester,
  ) async {
    await pump(tester);
    for (final c in ReproductiveCondition.values) {
      expect(find.byKey(ProfileKeys.condition(c)), findsOneWidget);
    }
    for (final t in FertilityTreatment.values) {
      expect(find.byKey(ProfileKeys.treatment(t)), findsOneWidget);
    }
    expect(find.byKey(ProfileKeys.notes), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(ProfileKeys.save)).enabled,
      isFalse,
    );
    await expectAccessible(tester);
  });

  testWidgets('choices and notes save together', (tester) async {
    await pump(tester);
    await tester.tap(
      find.byKey(ProfileKeys.condition(ReproductiveCondition.pcos)),
    );
    await tester.tap(find.byKey(ProfileKeys.treatment(FertilityTreatment.ivf)));
    await tester.enterText(
      find.byKey(ProfileKeys.notes),
      'Seeing Dr A in July',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProfileKeys.save));
    await tester.pumpAndSettle();
    expect(
      health.data.profile,
      HealthProfile(
        conditions: const {ReproductiveCondition.pcos},
        treatments: const {FertilityTreatment.ivf},
        notes: 'Seeing Dr A in July',
      ),
    );
    expect(find.byKey(ProfileKeys.saved), findsOneWidget);
  });
}
