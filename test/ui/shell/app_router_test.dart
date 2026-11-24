import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/ui/shell/app_router.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_browser_history.dart';

const _open = Key('open');
const _close = Key('close');
const _page = Key('page');

/// Stands in for the app: shows the tab, opens and closes a page.
class _Shell extends StatelessWidget {
  const _Shell(this.tabs);

  final ShellTabs tabs;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tabs,
    builder: (context, _) => Scaffold(
      body: Column(
        children: [
          Text(key: Key('tab.${tabs.current.name}'), tabs.current.name),
          for (final t in ShellTab.values)
            TextButton(
              key: Key('show.${t.name}'),
              onPressed: () => tabs.show(t),
              child: Text(t.name),
            ),
          TextButton(
            key: _open,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  key: _page,
                  body: TextButton(
                    key: _close,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('close'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late ShellTabs tabs;
  late FakeBrowserHistory history;
  late List<(String, bool)> reported;

  Future<void> pump(WidgetTester tester, {bool web = true}) async {
    tabs = ShellTabs();
    history = FakeBrowserHistory(isActive: web);
    reported = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          final args = call.arguments as Map;
          reported.add((args['uri'] as String, args['replace'] as bool));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
    final delegate = AppRouterDelegate(
      tabs: tabs,
      history: history,
      child: _Shell(tabs),
    );
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: const AppLocationParser(),
      ),
    );
    await tester.pumpAndSettle();
    reported.clear();
  }

  Future<void> browserGoesTo(WidgetTester tester, String location) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': location,
          'state': null,
        }),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  bool onTab(ShellTab t) =>
      find.byKey(Key('tab.${t.name}')).evaluate().isNotEmpty;
  bool pageOpen() => find.byKey(_page).evaluate().isNotEmpty;

  testWidgets('a tab switch adds a browser entry for the tab', (tester) async {
    await pump(tester);
    await tap(tester, const Key('show.history'));
    expect(reported, [('/history', false)]);
  });

  testWidgets('browser back returns to the previous tab, adding nothing', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, const Key('show.history'));
    reported.clear();
    await browserGoesTo(tester, '/today');
    expect(onTab(ShellTab.today), isTrue);
    expect(reported.where((r) => !r.$2), isEmpty);
  });

  testWidgets('opening a page adds an entry, and browser back closes it', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, _open);
    expect(reported, [('/today/1', false)]);
    reported.clear();
    await browserGoesTo(tester, '/today');
    expect(pageOpen(), isFalse);
    expect(reported.where((r) => !r.$2), isEmpty);
    expect(history.backs, 0);
  });

  testWidgets('browser back can close a page and change tab at once', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, const Key('show.log'));
    await tap(tester, _open);
    await browserGoesTo(tester, '/today');
    expect(pageOpen(), isFalse);
    expect(onTab(ShellTab.today), isTrue);
  });

  testWidgets('closing a page in the app steps the browser back instead', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, _open);
    reported.clear();
    await tap(tester, _close);
    expect(history.backs, 1);
    expect(reported, isEmpty);
    await browserGoesTo(tester, '/today');
    expect(onTab(ShellTab.today), isTrue);
    expect(reported.where((r) => !r.$2), isEmpty);
  });

  testWidgets('browser forward to a closed page keeps the app as it is', (
    tester,
  ) async {
    await pump(tester);
    await browserGoesTo(tester, '/today/1');
    expect(pageOpen(), isFalse);
    expect(onTab(ShellTab.today), isTrue);
  });

  testWidgets('the app opens on the tab its address names', (tester) async {
    await pump(tester);
    await browserGoesTo(tester, '/relief');
    expect(onTab(ShellTab.relief), isTrue);
  });

  testWidgets('off the web, closing a page reports where the app is', (
    tester,
  ) async {
    await pump(tester, web: false);
    await tap(tester, _open);
    reported.clear();
    await tap(tester, _close);
    expect(history.backs, 0);
    expect(reported.last.$1, '/today');
  });

  testWidgets('the Android back button closes a page, then leaves', (
    tester,
  ) async {
    await pump(tester, web: false);
    await tap(tester, _open);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(pageOpen(), isFalse);
    expect(await tester.binding.handlePopRoute(), isFalse);
  });
}
