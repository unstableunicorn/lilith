import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_session_service.dart';
import 'package:lilith/domain/pod_provider.dart';

void main() {
  group('PodSession', () {
    final session = PodSession(
      webId:
          'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me',
      provider: PodProvider.unstableUnicorn,
    );

    test('is equal by value', () {
      expect(
        session,
        PodSession(
          webId: 'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me',
          provider: PodProvider.unstableUnicorn,
        ),
      );
      expect(
        session,
        isNot(
          PodSession(
            webId: 'https://x/#me',
            provider: PodProvider.unstableUnicorn,
          ),
        ),
      );
    });

    test('round-trips through JSON', () {
      expect(PodSession.fromJson(session.toJson()), session);
    });
  });
}
