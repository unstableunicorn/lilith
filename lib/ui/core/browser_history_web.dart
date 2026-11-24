// The browser history on the web, through the page's `window.history`.

import 'dart:js_interop';

import 'package:lilith/ui/core/browser_history.dart';

@JS('window.history.back')
external void _historyBack();

BrowserHistory createBrowserHistory() => const _WebBrowserHistory();

class _WebBrowserHistory implements BrowserHistory {
  const _WebBrowserHistory();

  @override
  bool get isActive => true;

  @override
  void back() => _historyBack();
}
