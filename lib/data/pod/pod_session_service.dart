// Logging in to and out of a Solid pod.

import 'package:flutter/widgets.dart';
import 'package:lilith/domain/pod_provider.dart';

/// A logged-in user: who they are and which provider holds their pod.
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
  /// The session saved by an earlier login, if it is still valid.
  Future<PodSession?> restore();

  /// Logs in at [provider] through the system browser. [context] is what the
  /// underlying library needs to open it. Throws a PodException on failure.
  Future<PodSession> login(PodProvider provider, BuildContext context);

  Future<void> logout();
}
