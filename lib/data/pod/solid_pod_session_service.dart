// PodSessionService on a real Solid identity provider through solidpod.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/data/pod/solid_client.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:solidpod/solidpod.dart' as solid;

class SolidPodSessionService implements PodSessionService {
  SolidPodSessionService(this._settings);

  final SettingsStore _settings;

  @override
  Future<PodSession?> restore() async {
    final result = await solid.tryRestoreSession();
    if (result == null) return null;
    final webId = result[1] as String;
    return PodSession(
      webId: webId,
      provider: providerForRestoredSession(
        webId: webId,
        saved: await _settings.readProvider(),
      ),
    );
  }

  @override
  Future<PodSession> login(PodProvider provider, BuildContext context) async {
    // solidpod swallows its own errors and answers null for any failure,
    // the user closing the browser included.
    final result = await solid.solidAuthenticate(
      provider.serverUrl.toString(),
      context,
      clientId: SolidClient.clientId,
      redirectUris: redirectUrisFor(isWeb: kIsWeb, base: Uri.base),
    );
    if (result == null) {
      throw const PodLoginFailedException('the login did not complete');
    }
    return PodSession(webId: result[1] as String, provider: provider);
  }

  @override
  Future<void> logout() async {
    await solid.logoutPod();
  }
}

/// The provider a restored session belongs to: the one saved at login, else
/// the WebID's own host.
PodProvider providerForRestoredSession({
  required String webId,
  required PodProvider? saved,
}) => saved ?? PodProvider.custom(Uri.parse(webId).origin)!;
