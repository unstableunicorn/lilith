import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/design/design_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  testWidgets('shows every component in both themes, accessibly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        child: const DesignScreen(),
      ),
    );
    // The wait indicator spins forever, so the page can never settle.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(DesignKeys.page), findsOneWidget);
    expect(find.text('Light theme'), findsOneWidget);
    expect(find.text('Dark theme'), findsOneWidget);
    expect(find.text('Card with icon and title'), findsNWidgets(2));
    await expectAccessible(tester);
  });
}
