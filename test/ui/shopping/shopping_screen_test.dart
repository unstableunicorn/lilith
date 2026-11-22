import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/ui/core/shop_links.dart';
import 'package:lilith/ui/shopping/shopping_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
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
    tester.view.physicalSize = const Size(800, 2000);
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
        child: const ShoppingScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty list says so and still offers the add field', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(ShoppingKeys.empty), findsOneWidget);
    expect(find.byKey(ShoppingKeys.newItem), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('adding, ticking off and removing', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(ShoppingKeys.newItem), 'Ginger tea');
    await tester.tap(find.byKey(ShoppingKeys.add));
    await tester.pumpAndSettle();
    expect(health.data.shopping.single.name, 'Ginger tea');
    expect(find.byKey(ShoppingKeys.item('Ginger tea')), findsOneWidget);
    expect(find.byKey(ShoppingKeys.empty), findsNothing);

    await tester.tap(find.byKey(ShoppingKeys.add));
    await tester.pump();
    expect(find.byKey(ShoppingKeys.problem), findsOneWidget);

    await tester.tap(find.byKey(ShoppingKeys.toggle('Ginger tea')));
    await tester.pumpAndSettle();
    expect(health.data.shopping.single.bought, isTrue);
    expect(find.byKey(ShoppingKeys.nearby('Ginger tea')), findsNothing);

    await tester.tap(find.byKey(ShoppingKeys.remove('Ginger tea')));
    await tester.pumpAndSettle();
    expect(health.data.shopping, isEmpty);
  });

  testWidgets('an unbought item shows its note and opens searches', (
    tester,
  ) async {
    await health.apply(
      (d) => d.withShoppingItem(
        const ShoppingItem(name: 'Heat pad', note: 'For Cramps'),
      ),
    );
    await pump(tester);
    expect(find.text('For Cramps'), findsOneWidget);
    await tester.tap(find.byKey(ShoppingKeys.nearby('Heat pad')));
    await tester.tap(find.byKey(ShoppingKeys.online('Heat pad')));
    expect(urls.opened, [mapsNearMe('Heat pad'), retailerSearch('Heat pad')]);
    await expectAccessible(tester);
  });
}
