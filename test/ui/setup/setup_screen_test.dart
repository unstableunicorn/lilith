import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/setup/setup_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_pod_setup_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late FakePodSetupService pod;
  late SetupRepository setup;
  late SessionRepository session;

  setUp(() {
    pod = FakePodSetupService();
    setup = SetupRepository(pod);
    session = SessionRepository(FakePodSessionService(), FakeSettingsStore());
  });

  // The explanations are long; a phone-tall viewport keeps every control built.
  Future<void> pump(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      harness(
        session: session,
        child: ChangeNotifierProvider.value(
          value: setup,
          child: const SetupScreen(),
        ),
      ),
    );
  }

  testWidgets('meets the accessibility guidelines', (tester) async {
    await setup.inspect();
    await pump(tester);
    await expectAccessible(tester);
  });

  group('choosing', () {
    setUp(() => setup.inspect());

    testWidgets('shows both options with encrypted selected and explained', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.byKey(SetupKeys.option(DataProtection.encrypted)),
        findsOneWidget,
      );
      expect(
        find.byKey(SetupKeys.option(DataProtection.plain)),
        findsOneWidget,
      );
      expect(
        find.byKey(SetupKeys.explanation(DataProtection.encrypted)),
        findsOneWidget,
      );
      expect(
        find.byKey(SetupKeys.explanation(DataProtection.plain)),
        findsOneWidget,
      );
      expect(find.byKey(SetupKeys.key), findsOneWidget);
      expect(find.byKey(SetupKeys.confirmKey), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(SetupKeys.confirm)).enabled,
        isFalse,
      );
    });

    testWidgets(
      'a matching key of enough length enables confirm and sets the pod up',
      (tester) async {
        await pump(tester);
        await tester.enterText(find.byKey(SetupKeys.key), 'correct horse');
        await tester.enterText(
          find.byKey(SetupKeys.confirmKey),
          'correct horse',
        );
        await tester.pump();
        expect(
          tester.widget<FilledButton>(find.byKey(SetupKeys.confirm)).enabled,
          isTrue,
        );
        await tester.tap(find.byKey(SetupKeys.confirm));
        await tester.pumpAndSettle();
        expect(pod.podKey, 'correct horse');
      },
    );

    testWidgets('a mismatch shows a problem and keeps confirm off', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byKey(SetupKeys.key), 'correct horse');
      await tester.enterText(find.byKey(SetupKeys.confirmKey), 'correct norse');
      await tester.pump();
      expect(find.byKey(SetupKeys.keyProblem), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(SetupKeys.confirm)).enabled,
        isFalse,
      );
    });

    testWidgets('plain hides the key fields and confirms at once', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(SetupKeys.option(DataProtection.plain)));
      await tester.pump();
      expect(find.byKey(SetupKeys.key), findsNothing);
      await tester.tap(find.byKey(SetupKeys.confirm));
      await tester.pumpAndSettle();
      expect(setup.state, const SetupState.ready(DataProtection.plain));
    });
  });

  group('entering the key on a new device', () {
    setUp(() async {
      pod.podKey = 'right';
      pod.inspection = const PodInspection(
        plainDocumentExists: false,
        keysOnPod: true,
        keyOnDevice: false,
      );
      await setup.inspect();
    });

    testWidgets('asks for the key only, and the wrong one shows an error', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(SetupKeys.option(DataProtection.plain)), findsNothing);
      expect(find.byKey(SetupKeys.key), findsOneWidget);
      expect(find.byKey(SetupKeys.confirmKey), findsNothing);
      await tester.enterText(find.byKey(SetupKeys.key), 'wrong');
      await tester.pump();
      await tester.tap(find.byKey(SetupKeys.unlock));
      await tester.pumpAndSettle();
      expect(find.byKey(SetupKeys.error), findsOneWidget);
      expect(setup.state, const SetupState.enterKey());
    });

    testWidgets('the right key unlocks', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(SetupKeys.key), 'right');
      await tester.pump();
      await tester.tap(find.byKey(SetupKeys.unlock));
      await tester.pumpAndSettle();
      expect(setup.state, const SetupState.ready(DataProtection.encrypted));
    });
  });

  testWidgets('a failed set-up shows what the pod said', (tester) async {
    await setup.inspect();
    pod.failSetUp = const PodAccessException('403 on /lilith/.acl');
    await pump(tester);
    await tester.tap(find.byKey(SetupKeys.option(DataProtection.plain)));
    await tester.pump();
    await tester.tap(find.byKey(SetupKeys.confirm));
    await tester.pumpAndSettle();
    expect(find.byKey(SetupKeys.error), findsOneWidget);
    expect(find.byKey(SetupKeys.errorDetail), findsOneWidget);
    expect(find.textContaining('403 on /lilith/.acl'), findsOneWidget);
  });

  testWidgets('an unreachable pod offers retry', (tester) async {
    pod.failInspect = const PodUnavailableException('x');
    await setup.inspect();
    await pump(tester);
    expect(find.byKey(SetupKeys.error), findsOneWidget);
    pod.failInspect = null;
    await tester.tap(find.byKey(SetupKeys.retry));
    await tester.pumpAndSettle();
    expect(setup.state, const SetupState.choose());
  });
}
