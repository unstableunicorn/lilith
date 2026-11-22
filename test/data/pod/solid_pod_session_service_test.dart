import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/solid_pod_session_service.dart';
import 'package:lilith/domain/pod_provider.dart';

void main() {
  group('providerForRestoredSession', () {
    test('prefers the provider saved at login', () {
      expect(
        providerForRestoredSession(
          webId: 'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me',
          saved: PodProvider.solidCommunityAu,
        ),
        PodProvider.solidCommunityAu,
      );
    });

    test(
      'falls back to the WebID\'s host, matching a built-in when it is one',
      () {
        expect(
          providerForRestoredSession(
            webId: 'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me',
            saved: null,
          ),
          PodProvider.unstableUnicorn,
        );
        expect(
          providerForRestoredSession(
            webId: 'https://pods.example.org/me/profile/card#me',
            saved: null,
          ).serverUrl,
          Uri.parse('https://pods.example.org'),
        );
      },
    );
  });
}
