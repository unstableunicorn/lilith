import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/pod_provider.dart';

void main() {
  group('PodProvider', () {
    test("the built-in list holds the original app's host", () {
      expect(PodProvider.builtIn, contains(PodProvider.solidCommunityAu));
      expect(
        PodProvider.solidCommunityAu.serverUrl,
        Uri.parse('https://pods.solidcommunity.au'),
      );
      expect(PodProvider.solidCommunityAu.manageUrl, isNotNull);
    });

    test("the built-in list holds the owner's cluster pod, login only", () {
      expect(PodProvider.builtIn, contains(PodProvider.unstableUnicorn));
      expect(
        PodProvider.unstableUnicorn.serverUrl,
        Uri.parse('https://solid.unstableunicorn.dev'),
      );
      expect(
        PodProvider.unstableUnicorn.manageUrl,
        Uri.parse('https://solid.unstableunicorn.dev/.account/'),
      );
      expect(PodProvider.unstableUnicorn.allowsSignup, isFalse);
      expect(PodProvider.solidCommunityAu.allowsSignup, isTrue);
    });

    test(
      'a typed server that matches a built-in provider is that provider',
      () {
        expect(
          PodProvider.custom('solid.unstableunicorn.dev/'),
          PodProvider.unstableUnicorn,
        );
        expect(
          PodProvider.custom('https://pods.example.org')!.allowsSignup,
          isTrue,
        );
      },
    );

    test('built-in providers have distinct names and servers', () {
      final names = PodProvider.builtIn.map((p) => p.name).toSet();
      final servers = PodProvider.builtIn.map((p) => p.serverUrl).toSet();
      expect(names.length, PodProvider.builtIn.length);
      expect(servers.length, PodProvider.builtIn.length);
    });

    group('custom', () {
      final cases = <({String name, String input, String? want})>[
        (
          name: 'a bare host gets https',
          input: 'pods.example.org',
          want: 'https://pods.example.org',
        ),
        (
          name: 'a trailing slash is dropped',
          input: 'https://pods.example.org/',
          want: 'https://pods.example.org',
        ),
        (
          name: 'surrounding whitespace is dropped',
          input: '  https://pods.example.org ',
          want: 'https://pods.example.org',
        ),
        (
          name: 'http is kept for a local server',
          input: 'http://pod.lan:3000',
          want: 'http://pod.lan:3000',
        ),
        (name: 'empty is refused', input: '   ', want: null),
        (name: 'not a URL is refused', input: 'not a url', want: null),
      ];
      for (final c in cases) {
        test(c.name, () {
          final got = PodProvider.custom(c.input);
          expect(got?.serverUrl.toString(), c.want);
          if (got != null) {
            expect(got.manageUrl, got.serverUrl);
            expect(got.isBuiltIn, isFalse);
          }
        });
      }
    });

    test('is equal by value and round-trips through JSON', () {
      final a = PodProvider.custom('https://pods.example.org')!;
      final b = PodProvider.custom('pods.example.org')!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(PodProvider.fromJson(a.toJson()), a);
      expect(
        PodProvider.fromJson(PodProvider.solidCommunityAu.toJson()),
        PodProvider.solidCommunityAu,
      );
    });
  });
}
