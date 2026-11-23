import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/share_cipher.dart';

void main() {
  group('ShareKey', () {
    test('generates a code of four groups of four from the safe alphabet', () {
      final key = ShareKey.generate(Random(1));
      expect(
        key.code,
        matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{4}){3}$')),
      );
    });

    test('two keys differ', () {
      expect(
        ShareKey.generate(Random(1)).code,
        isNot(ShareKey.generate(Random(2)).code),
      );
    });

    test('reads the code back however it was typed', () {
      final key = ShareKey.generate(Random(3));
      final typed = key.code.toLowerCase().replaceAll('-', ' ');
      expect(ShareKey.fromCode(typed), key);
      expect(ShareKey.fromCode(key.code.replaceAll('-', '')), key);
    });

    test('maps the letters people confuse with digits', () {
      expect(ShareKey.fromCode('ABCD-EFGH-JKMN-PQRS'), isNotNull);
      final a = ShareKey.fromCode('0000-1111-0000-1111');
      final b = ShareKey.fromCode('OOOO-IIII-oooo-llll');
      expect(b, a);
    });

    test('refuses a code of the wrong length or alphabet', () {
      expect(ShareKey.fromCode('ABCD-EFGH-JKMN'), isNull);
      expect(ShareKey.fromCode('ABCD-EFGH-JKMN-PQRU'), isNull);
      expect(ShareKey.fromCode(''), isNull);
    });

    test('derives a 256-bit key and never prints it', () {
      final key = ShareKey.generate(Random(1));
      expect(key.bytes, hasLength(32));
      expect(key.toString(), isNot(contains(key.code)));
    });
  });

  group('ShareCipher', () {
    final key = ShareKey.generate(Random(7));
    const cipher = ShareCipher();

    test('round-trips text and never repeats the envelope', () {
      final a = cipher.encrypt('{"version":3}', key, Random(1));
      final b = cipher.encrypt('{"version":3}', key, Random(2));
      expect(cipher.decrypt(a, key), '{"version":3}');
      expect(cipher.decrypt(b, key), '{"version":3}');
      expect(a, isNot(b));
    });

    test('is a compact JWE with a direct AES-256-GCM key', () {
      final parts = cipher.encrypt('x', key, Random(1)).split('.');
      expect(parts, hasLength(5));
      expect(parts[1], isEmpty);
      final header = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[0])),
      );
      expect(jsonDecode(header), {'alg': 'dir', 'enc': 'A256GCM'});
      expect(base64Url.decode(base64Url.normalize(parts[2])), hasLength(12));
      expect(base64Url.decode(base64Url.normalize(parts[4])), hasLength(16));
      for (final p in parts) {
        expect(p, isNot(contains('=')));
      }
    });

    test('matches the RFC 7516 A.1 content encryption vector', () {
      // The CEK, IV, header and plaintext of RFC 7516 appendix A.1; the key
      // wrapping differs (RSA there), the AES-GCM step is the same.
      final cek = Uint8List.fromList([
        177,
        161,
        244,
        128,
        84,
        143,
        225,
        115,
        63,
        180,
        3,
        255,
        107,
        154,
        212,
        246,
        138,
        7,
        110,
        91,
        112,
        46,
        34,
        105,
        47,
        130,
        203,
        46,
        122,
        234,
        64,
        252,
      ]);
      final iv = Uint8List.fromList([
        227,
        197,
        117,
        252,
        2,
        219,
        233,
        68,
        180,
        225,
        77,
        219,
      ]);
      const header = 'eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZHQ00ifQ';
      const plaintext =
          'The true sign of intelligence is not knowledge but imagination.';
      final (:ciphertext, :tag) = ShareCipher.seal(
        plaintext: utf8.encode(plaintext),
        key: cek,
        iv: iv,
        protectedHeader: header,
      );
      expect(
        base64Url.encode(ciphertext).replaceAll('=', ''),
        '5eym8TW_c8SuK0ltJ3rpYIzOeDQz7TALvtu6UG9oMo4vpzs9tX_EFShS8iB7j6ji'
        'SdiwkIr3ajwQzaBtQD_A',
      );
      expect(
        base64Url.encode(tag).replaceAll('=', ''),
        'XFBoMYUZodetZdvTiFvSkQ',
      );
      expect(
        utf8.decode(
          ShareCipher.open(
            ciphertext: ciphertext,
            tag: tag,
            key: cek,
            iv: iv,
            protectedHeader: header,
          ),
        ),
        plaintext,
      );
    });

    test('the wrong key cannot read it', () {
      final env = cipher.encrypt('secret', key, Random(1));
      expect(
        () => cipher.decrypt(env, ShareKey.generate(Random(8))),
        throwsA(isA<ShareUndecryptableException>()),
      );
    });

    test('a tampered or malformed envelope is refused', () {
      final env = cipher.encrypt('secret', key, Random(1));
      final parts = env.split('.');
      parts[3] = 'AAAA${parts[3]}';
      expect(
        () => cipher.decrypt(parts.join('.'), key),
        throwsA(isA<ShareUndecryptableException>()),
      );
      final otherAlgorithm =
          'eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZHQ00ifQ'
          '..${parts[2]}.${parts[3]}.${parts[4]}';
      for (final bad in [
        'not a jwe',
        'a.b.c.d',
        '${parts[0]}.KEY.${parts[2]}.${parts[3]}.${parts[4]}',
        otherAlgorithm,
      ]) {
        expect(
          () => cipher.decrypt(bad, key),
          throwsA(isA<ShareUndecryptableException>()),
          reason: bad,
        );
      }
    });
  });
}
