// The app's place in the browser history. Each tab switch and each page
// opened is its own entry, added straight after the tap, so Chrome's back
// button never skips it; browser back and forward move the app to match.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lilith/ui/core/browser_history.dart';
import 'package:lilith/ui/shell/app_location.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';

/// Reads and writes an [AppLocation] as route information.
class AppLocationParser extends RouteInformationParser<AppLocation> {
  const AppLocationParser();

  @override
  Future<AppLocation> parseRouteInformation(
    RouteInformation routeInformation,
  ) => SynchronousFuture(AppLocation.fromUri(routeInformation.uri));

  @override
  RouteInformation restoreRouteInformation(AppLocation configuration) =>
      RouteInformation(uri: configuration.uri);
}

/// Shows [child] in the app's one Navigator and keeps the browser history
/// in step with [tabs] and the pages pushed over [child].
class AppRouterDelegate extends RouterDelegate<AppLocation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppLocation> {
  AppRouterDelegate({
    required this.tabs,
    required this.history,
    required this.child,
  }) {
    tabs.addListener(_report);
  }

  final ShellTabs tabs;
  final BrowserHistory history;
  final Widget child;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late final _PageCounter _pages = _PageCounter(
    opened: _report,
    closed: _pageClosed,
  );
  bool _following = false;
  bool _reportScheduled = false;
  bool _disposed = false;

  @override
  AppLocation get currentConfiguration =>
      AppLocation(tabs.current, pages: _pages.count);

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    observers: [_pages],
    pages: [MaterialPage<void>(child: child)],
    onDidRemovePage: (_) {},
  );

  /// The browser moved to [configuration]: close pages and change tab to
  /// match. A page closed earlier cannot be opened again, so going forward
  /// to one leaves the app where it is.
  @override
  Future<void> setNewRoutePath(AppLocation configuration) async {
    final navigator = navigatorKey.currentState;
    _following = true;
    try {
      while (navigator != null &&
          _pages.count > configuration.pages &&
          navigator.canPop()) {
        navigator.pop();
      }
      tabs.show(configuration.tab);
    } finally {
      _following = false;
    }
    _report();
  }

  // A page closed in the app: the browser steps back to the entry before
  // it, which then matches the app and changes nothing.
  void _pageClosed() {
    if (_following) return;
    if (history.isActive) {
      history.back();
    } else {
      _report();
    }
  }

  // Route changes arrive mid-frame; the Router reads the location after.
  void _report() {
    if (_following || _reportScheduled || _disposed) return;
    _reportScheduled = true;
    scheduleMicrotask(() {
      _reportScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    tabs.removeListener(_report);
    super.dispose();
  }
}

/// Counts the routes pushed over the first one.
class _PageCounter extends NavigatorObserver {
  _PageCounter({required this.opened, required this.closed});

  final VoidCallback opened;
  final VoidCallback closed;
  final List<Route<dynamic>> _routes = [];

  int get count => _routes.isEmpty ? 0 : _routes.length - 1;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    if (_routes.length > 1) opened();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) closed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) closed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) _routes[i] = newRoute;
  }
}
