// Off the web there is no browser history.

import 'package:lilith/ui/core/browser_history.dart';

BrowserHistory createBrowserHistory() => const _NoBrowserHistory();

class _NoBrowserHistory implements BrowserHistory {
  const _NoBrowserHistory();

  @override
  bool get isActive => false;

  @override
  void back() {}
}
