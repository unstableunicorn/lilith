// PodSessionService on a real Solid identity provider.
//
// The app owns the solid_auth manager rather than going through solidpod's
// solidAuthenticate: on the web the login is a same-page redirect, so the
// call that starts it never returns, and solidpod only saves what its own
// restore needs after that return. Owning the manager lets restore() finish
// the login on the next start and then hand the manager to solidpod, whose
// read and write functions work through AuthDataManager.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/pod/solid_client.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:oidc/oidc.dart';
import 'package:solid_auth/solid_auth.dart';
import 'package:solidpod/solidpod.dart' as solid;

/// solidpod configured for this app. Every call into solidpod awaits it
/// first, so the app folder name is set before any path is built.
final Future<void> solidPodReady = solid.setAppDirName(SolidClient.appDirName);

/// The OIDC client configuration for this platform. [pick] chooses the
/// redirect URI for the platform from the ones the client profile lists.
/// On the web the login and logout redirect within the page: a second tab
/// is blocked or frozen too often on phones to be relied on.
SolidOidcConfig solidOidcConfigFor({
  required bool isWeb,
  required Uri base,
  required String Function(List<String>) pick,
}) {
  final redirect = Uri.parse(pick(redirectUrisFor(isWeb: isWeb, base: base)));
  return SolidOidcConfig(
    clientId: SolidClient.clientId,
    redirectUri: redirect,
    postLogoutRedirectUri: redirect,
    options: const OidcPlatformSpecificOptions(
      web: OidcPlatformSpecificOptions_Web(
        navigationMode: OidcPlatformSpecificOptions_Web_NavigationMode.samePage,
      ),
    ),
  );
}

/// What a failed authenticate() means. Null is not a failure: on the web the
/// library reports no user because the page is already leaving.
PodException? authFailureFor(Object error, {required bool isWeb}) =>
    switch (error) {
      SolidAuthTokenException() when isWeb => null,
      SolidAuthTokenException() => const PodLoginCancelledException(),
      SolidAuthDiscoveryException() => PodUnavailableException('$error'),
      _ => PodLoginFailedException('$error'),
    };

class SolidPodSessionService implements PodSessionService {
  SolidPodSessionService(this._settings);

  final SettingsStore _settings;
  late final SolidOidcConfig _config = solidOidcConfigFor(
    isWeb: kIsWeb,
    base: Uri.base,
    pick: solid.pickRedirectUri,
  );
  late final SolidAuthManager _auth = SolidAuthManager(config: _config);

  @override
  Future<void> prepare(PodProvider provider) async {
    await solidPodReady;
    await _auth.prewarm(provider.serverUrl.toString());
  }

  @override
  Future<PodSession?> restore() async {
    await solidPodReady;
    final data = await _auth.tryRestoreSession();
    if (data == null) return null;
    await _register(data);
    return PodSession(
      webId: data.webId,
      provider: providerForRestoredSession(
        webId: data.webId,
        saved: await _settings.readProvider(),
      ),
    );
  }

  @override
  Future<PodSession?> login(PodProvider provider, BuildContext context) async {
    await solidPodReady;
    final SolidAuthData? data;
    try {
      data = await _auth.authenticate(provider.serverUrl.toString());
    } on Object catch (e) {
      final failure = authFailureFor(e, isWeb: kIsWeb);
      if (failure == null) return null;
      throw failure;
    }
    if (data == null) throw const PodLoginFailedException('no user returned');
    await _register(data);
    return PodSession(webId: data.webId, provider: provider);
  }

  /// Hands the live manager to solidpod, which keys every pod request off it.
  Future<void> _register(SolidAuthData data) =>
      solid.AuthDataManager.saveAuthData(
        data,
        _auth,
        oidcClientId: _config.clientId,
        redirectUri: _config.redirectUri.toString(),
      );

  @override
  Future<void> logout() async {
    await solidPodReady;
    if (kIsWeb) await _leaveForLogout();
    await solid.logoutPod();
  }

  /// On the web the provider's logout page replaces this one and comes back
  /// to the app's own URL, so the local clean-up must come first.
  Future<void> _leaveForLogout() async {
    await solid.KeyManager.clear();
    try {
      await _auth.oidcManager.logout(originalUri: Uri.base);
    } on Object {
      // Not logged in at the provider: the local logout below still applies.
    }
  }
}

/// The provider a restored session belongs to: the one saved at login, else
/// the WebID's own host.
PodProvider providerForRestoredSession({
  required String webId,
  required PodProvider? saved,
}) => saved ?? PodProvider.custom(Uri.parse(webId).origin)!;
