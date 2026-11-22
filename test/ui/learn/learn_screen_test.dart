import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/content/period_facts.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/learn/learn_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late RecordingUrlOpener urls;

  setUp(() => urls = RecordingUrlOpener());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        openUrl: urls.call,
        child: const LearnScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every fact with its source, accessibly', (tester) async {
    await pump(tester);
    for (final f in periodFacts) {
      expect(find.byKey(LearnKeys.fact(f.text)), findsOneWidget);
    }
    expect(find.byKey(LearnKeys.answer), findsNothing);
    expect(find.byKey(LearnKeys.noAnswer), findsNothing);
    await tester.tap(find.byKey(LearnKeys.factSource(periodFacts.first.text)));
    expect(urls.opened, [Uri.parse(periodFacts.first.source.url)]);
    await expectAccessible(tester);
  });

  testWidgets('asking shows the best answer, or says there is none', (
    tester,
  ) async {
    await pump(tester);
    final entry = knowledgeBase.first;
    await tester.enterText(
      find.byKey(LearnKeys.question),
      entry.keywords.first,
    );
    await tester.tap(find.byKey(LearnKeys.ask));
    await tester.pumpAndSettle();
    expect(find.byKey(LearnKeys.answer), findsOneWidget);
    expect(find.text(entry.question), findsOneWidget);
    await tester.tap(
      find.byKey(LearnKeys.answerSource(entry.sources.first.url)),
    );
    expect(urls.opened, [Uri.parse(entry.sources.first.url)]);

    await tester.enterText(find.byKey(LearnKeys.question), 'zzqx');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(LearnKeys.noAnswer), findsOneWidget);
  });
}
