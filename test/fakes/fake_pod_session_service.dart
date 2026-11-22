import 'package:flutter/widgets.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/domain/pod_provider.dart';

/// Logs anyone in as [webId]. Set [restored] to pretend a session was saved,
/// or [failLogin] to make the next login fail.
class FakePodSessionService implements PodSessionService {
  FakePodSessionService({
    this.webId = 'https://pod.example.org/me/profile/card#me',
  });

  String webId;
  PodSession? restored;
  PodException? failLogin;
  final List<PodProvider> logins = [];
  int logouts = 0;

  @override
  Future<PodSession?> restore() async => restored;

  @override
  Future<PodSession> login(PodProvider provider, BuildContext context) async {
    logins.add(provider);
    if (failLogin case final e?) throw e;
    return PodSession(webId: webId, provider: provider);
  }

  @override
  Future<void> logout() async {
    logouts++;
    restored = null;
  }
}
