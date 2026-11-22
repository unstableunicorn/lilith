import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/domain/pod_provider.dart';

/// Logs anyone in as [webId]. Set [restored] to pretend a session was saved,
/// [failLogin] to make the next login fail, or [redirects] to act like the
/// web, where the page leaves for the provider and login answers null.
class FakePodSessionService implements PodSessionService {
  FakePodSessionService({
    this.webId = 'https://pod.example.org/me/profile/card#me',
  });

  String webId;
  PodSession? restored;

  /// When set, restore() waits for it, so a test can observe the wait.
  Completer<void>? restoreGate;
  PodException? failLogin;
  bool redirects = false;
  final List<PodProvider> logins = [];
  final List<PodProvider> prepared = [];
  int logouts = 0;

  @override
  Future<void> prepare(PodProvider provider) async => prepared.add(provider);

  @override
  Future<PodSession?> restore() async {
    if (restoreGate case final gate?) await gate.future;
    return restored;
  }

  @override
  Future<PodSession?> login(PodProvider provider, BuildContext context) async {
    logins.add(provider);
    if (failLogin case final e?) throw e;
    if (redirects) return null;
    return PodSession(webId: webId, provider: provider);
  }

  @override
  Future<void> logout() async {
    logouts++;
    restored = null;
  }
}
