import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/solid_client.dart';
import 'package:lilith/data/pod/solid_pod_session_service.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:oidc/oidc.dart';
import 'package:solid_auth/solid_auth.dart';

void main() {
  solidOidcConfigTests();
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

void solidOidcConfigTests() {
  final base = Uri.parse('https://lilith-dev.unstableunicorn.dev/#/x');

  test('the web config redirects within the page, back to its own origin', () {
    final config = solidOidcConfigFor(isWeb: true, base: base, pick: first);
    expect(
      config.redirectUri,
      Uri.parse('https://lilith-dev.unstableunicorn.dev/redirect.html'),
    );
    expect(config.postLogoutRedirectUri, config.redirectUri);
    expect(config.clientId, SolidClient.clientId);
    expect(
      config.options?.web.navigationMode,
      OidcPlatformSpecificOptions_Web_NavigationMode.samePage,
    );
  });

  test('a phone comes back through the app scheme', () {
    final config = solidOidcConfigFor(isWeb: false, base: base, pick: first);
    expect(
      config.redirectUri,
      Uri.parse('dev.unstableunicorn.lilith://redirect'),
    );
    expect(config.postLogoutRedirectUri, config.redirectUri);
  });

  group('authFailureFor', () {
    const noUser = SolidAuthTokenException('Login cancelled or failed.');

    test('on the web, no user means the page is leaving: not a failure', () {
      expect(authFailureFor(noUser, isWeb: true), isNull);
    });

    test('on a phone, no user means the user closed the browser', () {
      expect(
        authFailureFor(noUser, isWeb: false),
        isA<PodLoginCancelledException>(),
      );
    });

    test('a provider that cannot be reached is unavailable', () {
      expect(
        authFailureFor(
          const SolidAuthDiscoveryException('x', webId: 'y'),
          isWeb: true,
        ),
        isA<PodUnavailableException>(),
      );
    });

    test('anything else is a failed login carrying the detail', () {
      final e = authFailureFor(StateError('boom'), isWeb: true);
      expect(e, isA<PodLoginFailedException>());
      expect(e.toString(), contains('boom'));
    });
  });
}

String first(List<String> uris) => uris.first;
