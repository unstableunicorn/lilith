// The signed-in app: a tab per top-level screen, all kept alive so a
// half-edited log survives a look at another tab. Which tabs there are
// follows how the person uses the app.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/ui/follow/follow_screen.dart';
import 'package:lilith/ui/history/history_screen.dart';
import 'package:lilith/ui/home/home_screen.dart';
import 'package:lilith/ui/learn/learn_screen.dart';
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
    final mode = context.select<HealthRepository, AppMode>(
      (health) => health.data.modeInForce,
    );
    final shown = shellTabsFor(mode);
    // The mode changed: the tabs learn of it after this frame, which
    // already draws the new ones.
    if (!listEquals(tabs.allowed, shown)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tabs.allow(shown));
    }
    // Android's back button retraces the tabs; only with none left does it
    // leave. On the web the browser history does this instead.
    return PopScope(
      canPop: !tabs.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) tabs.goBack();
      },
      child: _Tabs(tabs: tabs, shown: shown, mode: mode, now: now),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.shown,
    required this.mode,
    required this.now,
  });

  final ShellTabs tabs;
  final List<ShellTab> shown;
  final AppMode mode;
  final DateTime Function() now;

  Widget _screen(ShellTab tab) => switch (tab) {
    ShellTab.today when mode.tracksOwnCycle => HomeScreen(now: now),
    ShellTab.today => FollowScreen(now: now),
    ShellTab.log => LogScreen(now: now),
    ShellTab.history => HistoryScreen(now: now),
    ShellTab.relief => ReliefScreen(now: now),
    ShellTab.pod => PodScreen(now: now),
    ShellTab.learn => const LearnScreen(asTab: true),
  };

  @override
  Widget build(BuildContext context) {
    final at = shown.indexOf(tabs.current);
    final index = at < 0 ? 0 : at;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          // Keyed, so a tab keeps its state when the tabs around it change.
          for (final t in shown)
            KeyedSubtree(key: ValueKey(t), child: _screen(t)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => tabs.show(shown[i]),
        destinations: [
          for (final t in shown)
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
