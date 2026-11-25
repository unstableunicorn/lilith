// Opening a URL outside the app, injected so screens can be tested.

/// Opens [url] in the system browser.
typedef UrlOpener = Future<void> Function(Uri url);

/// Downloads the file at a URL and leaves the page as it is: on the web, no
/// new tab. A class, not a typedef, so a provider tells it from [UrlOpener].
final class Downloader {
  const Downloader(this._download);

  final Future<void> Function(Uri url) _download;

  Future<void> call(Uri url) => _download(url);
}
