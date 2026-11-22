import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/content/symptom_advice.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/ui/core/shop_links.dart';
import 'package:lilith/ui/relief/relief_screen.dart';
import 'package:lilith/ui/shopping/shopping_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = DateTime(2026, 6, 10);
  late HealthRepository health;
  late RecordingUrlOpener urls;

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    urls = RecordingUrlOpener();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        health: health,
        openUrl: urls.call,
        child: ReliefScreen(now: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  final cramps = symptomAdvice[Symptom.cramps]!;
  final heat = cramps.remedies.firstWhere((r) => r.shopItem != null);

  testWidgets('shows every symptom, the doctor note and the remedies', (
    tester,
  ) async {
    await pump(tester);
    for (final s in Symptom.values) {
      expect(find.byKey(ReliefKeys.symptom(s)), findsOneWidget);
    }
    expect(find.byKey(ReliefKeys.seeDoctor), findsOneWidget);
    for (final r in cramps.remedies) {
      expect(find.byKey(ReliefKeys.remedy(r.title)), findsOneWidget);
    }
    await expectAccessible(tester);
  });

  testWidgets('choosing a symptom shows its remedies', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(ReliefKeys.symptom(Symptom.insomnia)));
    await tester.pumpAndSettle();
    for (final r in symptomAdvice[Symptom.insomnia]!.remedies) {
      expect(find.byKey(ReliefKeys.remedy(r.title)), findsOneWidget);
    }
    expect(find.byKey(ReliefKeys.remedy(heat.title)), findsNothing);
  });

  testWidgets('rating writes through and helped moves to the top', (
    tester,
  ) async {
    await pump(tester);
    final last = cramps.remedies.last;
    await tester.tap(find.byKey(ReliefKeys.helped(last.title)));
    await tester.pumpAndSettle();
    expect(health.data.ratingFor('cramps', last.title), RemedyRating.helped);
    final firstCard = tester.getTopLeft(
      find.byKey(ReliefKeys.remedy(last.title)),
    );
    final heatCard = tester.getTopLeft(
      find.byKey(ReliefKeys.remedy(heat.title)),
    );
    expect(firstCard.dy, lessThan(heatCard.dy));
    await tester.tap(find.byKey(ReliefKeys.didNotHelp(heat.title)));
    await tester.pumpAndSettle();
    expect(find.textContaining('not for you'), findsOneWidget);
  });

  testWidgets('shopping buttons add to the list and open searches', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(ReliefKeys.addToList(heat.title)));
    await tester.pumpAndSettle();
    expect(health.data.shopping.single.name, heat.shopItem);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(ReliefKeys.addToList(heat.title)))
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(ReliefKeys.nearby(heat.title)));
    await tester.tap(find.byKey(ReliefKeys.online(heat.title)));
    expect(urls.opened, [
      mapsNearMe(heat.shopItem!),
      retailerSearch(heat.shopItem!),
    ]);
  });

  testWidgets('the list link counts what is to buy and opens the list', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('List'), findsOneWidget);
    await tester.tap(find.byKey(ReliefKeys.addToList(heat.title)));
    await tester.pumpAndSettle();
    expect(find.text('List (1)'), findsOneWidget);
    await tester.tap(find.byKey(ReliefKeys.shopping));
    await tester.pumpAndSettle();
    expect(find.byKey(ShoppingKeys.item(heat.shopItem!)), findsOneWidget);
  });

  testWidgets('a source chip opens its page', (tester) async {
    await pump(tester);
    final source = heat.sources.first;
    await tester.tap(find.byKey(ReliefKeys.source(heat.title, source.url)));
    expect(urls.opened, [Uri.parse(source.url)]);
  });
}
