import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/ui/settings/security_key_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_pod_setup_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  const current = 'old key 1';
  late FakePodSetupService pod;
  late SetupRepository setup;

  setUp(() async {
    pod = FakePodSetupService();
    setup = SetupRepository(pod);
    await setup.inspect();
    await setup.chooseEncrypted(current);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        setup: setup,
        child: const SecurityKeyScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillAndChange(
    WidgetTester tester, {
    String now = current,
    String next = 'new key 2',
    String again = 'new key 2',
  }) async {
    await tester.enterText(find.byKey(SecurityKeyKeys.current), now);
    await tester.enterText(find.byKey(SecurityKeyKeys.newKey), next);
    await tester.enterText(find.byKey(SecurityKeyKeys.confirmKey), again);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SecurityKeyKeys.change));
    await tester.pumpAndSettle();
  }

  testWidgets('the button waits for acceptable keys, accessibly', (
    tester,
  ) async {
    await pump(tester);
    await fillAndChange(tester, next: 'short', again: 'short');
    expect(find.byKey(SecurityKeyKeys.problem), findsOneWidget);
    expect(pod.podKey, current);
    await expectAccessible(tester);
  });

  testWidgets('a change that works says so and hides the form', (tester) async {
    await pump(tester);
    await fillAndChange(tester);
    expect(pod.podKey, 'new key 2');
    expect(find.byKey(SecurityKeyKeys.changed), findsOneWidget);
    expect(find.byKey(SecurityKeyKeys.change), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('a wrong current key says so', (tester) async {
    await pump(tester);
    await fillAndChange(tester, now: 'not the key');
    expect(find.byKey(SecurityKeyKeys.wrongKey), findsOneWidget);
    expect(pod.podKey, current);
  });

  final failures = <(String, PodException, Key)>[
    (
      'restored',
      const PodKeyChangeException('x', restored: true),
      SecurityKeyKeys.unchanged,
    ),
    (
      'not restored',
      const PodKeyChangeException('x', restored: false),
      SecurityKeyKeys.broken,
    ),
  ];
  for (final (name, failure, key) in failures) {
    testWidgets('a failed change, $name, is explained accessibly', (
      tester,
    ) async {
      pod.failChangeKey = failure;
      await pump(tester);
      await fillAndChange(tester);
      expect(find.byKey(key), findsOneWidget);
      await expectAccessible(tester);
    });
  }
}
