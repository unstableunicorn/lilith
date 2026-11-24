// The signed-in app: a tab per top-level screen, all kept alive so a
// half-edited log survives a look at another tab.

import 'package:lilith/ui/history/history_screen.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/log/log_screen.dart';
import 'package:lilith/ui/pod/pod_screen.dart';
import 'package:lilith/ui/relief/relief_screen.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ShellKeys {
  static Key tab(ShellTab t) => Key('shell.tab.${t.name}');
}

class AppShell extends StatelessWidget {
  const AppShell({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  /// The tabs come from above, where the router keeps the browser history
  /// in step with them.
  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<ShellTabs>();
    // Android's back button retraces the tabs; only with none left does it
    // leave. On the web the browser history does this instead.
    return PopScope(
      canPop: !tabs.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) tabs.goBack();
      },
      child: _Tabs(tabs: tabs, now: now),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs, required this.now});

  final ShellTabs tabs;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tabs.current.index,
        children: [
          HomeScreen(now: now),
          LogScreen(now: now),
          HistoryScreen(now: now),
          ReliefScreen(now: now),
          PodScreen(now: now),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.current.index,
        onDestinationSelected: (i) => tabs.show(ShellTab.values[i]),
        destinations: [
          for (final t in ShellTab.values)
            NavigationDestination(
              key: ShellKeys.tab(t),
              icon: Icon(t.icon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
