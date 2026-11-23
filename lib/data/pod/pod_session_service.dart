// Logging in to and out of a Solid pod.

import 'package:flutter/widgets.dart';
import 'package:lilith/domain/pod_provider.dart';

/// A logged-in user: who they are and which provider holds their pod.
@immutable
class PodSession {
  const PodSession({required this.webId, required this.provider});

  factory PodSession.fromJson(Map<String, dynamic> json) => PodSession(
    webId: json['webId'] as String,
    provider: PodProvider.fromJson(json['provider'] as Map<String, dynamic>),
  );

  final String webId;
  final PodProvider provider;

  Map<String, dynamic> toJson() => {
    'webId': webId,
    'provider': provider.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is PodSession && other.webId == webId && other.provider == provider;

  @override
  int get hashCode => Object.hash(webId, provider);
}

/// Starts, restores and ends the pod session.
abstract interface class PodSessionService {
  /// Does the network lookups for [provider] ahead of [login], so the login
  /// can open its browser window at once when the user taps. Browsers block
  /// a window opened too long after the tap.
  Future<void> prepare(PodProvider provider);

  /// The session saved by an earlier login, if it is still valid.
  Future<PodSession?> restore();

  /// Logs in at [provider] through the browser. [context] is what the
  /// underlying library needs to open it. Throws a PodException on failure.
  /// Returns null when the page itself has left for the provider: the result
  /// then arrives through [restore] when the app starts again.
  Future<PodSession?> login(PodProvider provider, BuildContext context);

  Future<void> logout();
}
