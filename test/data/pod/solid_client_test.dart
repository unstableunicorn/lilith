import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/solid_client.dart';

void main() {
  group('redirectUrisFor', () {
    test('on the web, the redirect is on the page\'s own origin', () {
      expect(
        redirectUrisFor(
          isWeb: true,
          base: Uri.parse('https://lilith.unstableunicorn.dev/#/home'),
        ),
        ['https://lilith.unstableunicorn.dev/redirect.html'],
      );
      expect(
        redirectUrisFor(isWeb: true, base: Uri.parse('http://localhost:4400/')),
        ['http://localhost:4400/redirect.html'],
      );
    });

    test('off the web, the custom scheme comes first, the loopback second', () {
      expect(redirectUrisFor(isWeb: false, base: Uri.parse('file:///')), [
        'dev.unstableunicorn.lilith://redirect',
        'http://localhost:4400/redirect.html',
      ]);
    });
  });

  group('the published client profile', () {
    final profile = jsonDecode(
      File('web/client-profile.jsonld').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('is the client id the app sends', () {
      expect(profile['client_id'], SolidClient.clientId);
      expect(SolidClient.clientId, startsWith('${SolidClient.webOrigin}/'));
    });

    test('lists exactly the redirect URIs the app can use', () {
      final appUris = {
        ...redirectUrisFor(isWeb: true, base: Uri.parse(SolidClient.webOrigin)),
        ...redirectUrisFor(isWeb: true, base: Uri.parse(SolidClient.devOrigin)),
        ...redirectUrisFor(isWeb: false, base: Uri.parse('file:///')),
      };
      expect((profile['redirect_uris'] as List).toSet(), appUris);
      expect((profile['post_logout_redirect_uris'] as List).toSet(), appUris);
    });

    test('is a public client using the code flow', () {
      expect(profile['token_endpoint_auth_method'], 'none');
      expect(
        profile['grant_types'],
        containsAll(['authorization_code', 'refresh_token']),
      );
      expect(profile['scope'], 'openid profile offline_access webid');
    });
  });
}
