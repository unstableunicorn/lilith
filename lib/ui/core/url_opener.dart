// Opening a URL outside the app, injected so screens can be tested.

/// Opens [url] in the system browser.
typedef UrlOpener = Future<void> Function(Uri url);
