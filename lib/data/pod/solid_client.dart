// How the app identifies itself to a Solid identity provider.
//
// The client id is the published URL of web/client-profile.jsonld. Its
// redirect_uris must list exactly the URIs redirectUrisFor can return; a test
// checks the two agree.

/// The app's Solid OIDC client identity.
abstract final class SolidClient {
  /// Where the web app is served, and where the client profile lives.
  static const String webOrigin = 'https://lilith.unstableunicorn.dev';

  /// Where `scripts/dev.sh` serves the web app.
  static const String devOrigin = 'http://localhost:4400';

  static const String clientId = '$webOrigin/client-profile.jsonld';

  /// The custom URL scheme Android and iOS return to after login.
  static const String nativeScheme = 'dev.unstableunicorn.lilith';
}

/// The redirect URIs to offer the identity provider. On the web the redirect
/// page must share the app's origin, so it is derived from [base], the page's
/// own URL. Off the web the custom scheme serves phones and the loopback
/// serves desktops.
List<String> redirectUrisFor({required bool isWeb, required Uri base}) => isWeb
    ? ['${base.origin}/redirect.html']
    : const [
        '${SolidClient.nativeScheme}://redirect',
        '${SolidClient.devOrigin}/redirect.html',
      ];
