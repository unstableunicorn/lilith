// The browser's own history, so a page closed inside the app also steps the
// browser back and the two stay in step.

import 'package:lilith/ui/core/browser_history_stub.dart'
    if (dart.library.js_interop) 'package:lilith/ui/core/browser_history_web.dart';

abstract interface class BrowserHistory {
  /// Whether there is a browser history to step through: only on the web.
  bool get isActive;

  /// Steps the browser back one entry, as its back button would.
  void back();
}

/// The browser history of the platform the app runs on.
BrowserHistory platformBrowserHistory() => createBrowserHistory();
