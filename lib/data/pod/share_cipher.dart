// The per-share key and the envelope a share copy is written in. The app
// encrypts share copies itself, so none of solidpod's key material is shared,
// and it uses JWE (RFC 7516) so any app with the key can open them.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:meta/meta.dart';

/// The envelope could not be read with this key.
class ShareUndecryptableException implements Exception {
  const ShareUndecryptableException(this.cause);
  final Object cause;
  @override
  String toString() => 'ShareUndecryptableException: $cause';
}

/// A share's secret: 16 characters from a 32-letter alphabet without the
/// letters people confuse with digits, shown in groups of four. The AES key
/// is derived from the code, so the code is all the recipient needs to type.
class ShareKey {
  const ShareKey._(this.code);

  /// Crockford's base-32 alphabet: no I, L, O or U.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int length = 16;

  factory ShareKey.generate(Random random) {
    final chars = [
      for (var i = 0; i < length; i++)
        alphabet[random.nextInt(alphabet.length)],
    ];
    return ShareKey._(_grouped(chars.join()));
  }

  /// The code as typed: case, spaces and dashes do not matter, and I, L and
  /// O are read as 1, 1 and 0. Null when it is not a code.
  static ShareKey? fromCode(String typed) {
    final raw = typed
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0');
    if (raw.length != length) return null;
    for (final c in raw.split('')) {
      if (!alphabet.contains(c)) return null;
    }
    return ShareKey._(_grouped(raw));
  }

  static String _grouped(String raw) =>
      [for (var i = 0; i < raw.length; i += 4) raw.substring(i, i + 4)]
          .join('-');

  /// The code to show and to type, `XXXX-XXXX-XXXX-XXXX`.
  final String code;

  /// The 256-bit AES key the code stands for: SHA-256 of the code.
  Uint8List get bytes =>
      Uint8List.fromList(sha256.convert(utf8.encode(code)).bytes);

  @override
  bool operator ==(Object other) => other is ShareKey && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'ShareKey(****)';
}

/// JWE compact serialisation with a direct key and AES-256-GCM:
/// `header.<empty>.iv.ciphertext.tag`, each part base64url without padding.
class ShareCipher {
  const ShareCipher();

  /// `{"alg":"dir","enc":"A256GCM"}`, as the JWE protected header.
  static final String protectedHeader = _b64(
    utf8.encode('{"alg":"dir","enc":"A256GCM"}'),
  );
  static const int _nonceLength = 12;
  static const int _tagLength = 16;

  String encrypt(String plaintext, ShareKey key, Random random) {
    final iv = Uint8List.fromList([
      for (var i = 0; i < _nonceLength; i++) random.nextInt(256),
    ]);
    final (:ciphertext, :tag) = seal(
      plaintext: utf8.encode(plaintext),
      key: key.bytes,
      iv: iv,
      protectedHeader: protectedHeader,
    );
    return [
      protectedHeader,
      '',
      _b64(iv),
      _b64(ciphertext),
      _b64(tag),
    ].join('.');
  }

  String decrypt(String envelope, ShareKey key) {
    try {
      final parts = envelope.split('.');
      if (parts.length != 5 || parts[1].isNotEmpty) {
        throw const FormatException('not a direct-key compact JWE');
      }
      final header =
          jsonDecode(utf8.decode(_unb64(parts[0]))) as Map<String, dynamic>;
      if (header['alg'] != 'dir' || header['enc'] != 'A256GCM') {
        throw FormatException('unsupported JWE ${header['alg']}');
      }
      final plain = open(
        ciphertext: _unb64(parts[3]),
        tag: _unb64(parts[4]),
        key: key.bytes,
        iv: _unb64(parts[2]),
        protectedHeader: parts[0],
      );
      return utf8.decode(plain);
    } on Object catch (e) {
      throw ShareUndecryptableException(e);
    }
  }

  /// The content encryption step of JWE: AES-GCM over [plaintext] with the
  /// encoded protected header as the additional authenticated data.
  @visibleForTesting
  static ({Uint8List ciphertext, Uint8List tag}) seal({
    required List<int> plaintext,
    required Uint8List key,
    required Uint8List iv,
    required String protectedHeader,
  }) {
    final out = Encrypter(AES(Key(key), mode: AESMode.gcm))
        .encryptBytes(
          plaintext,
          iv: IV(iv),
          associatedData: ascii.encode(protectedHeader),
        )
        .bytes;
    final split = out.length - _tagLength;
    return (
      ciphertext: Uint8List.sublistView(out, 0, split),
      tag: Uint8List.sublistView(out, split),
    );
  }

  @visibleForTesting
  static List<int> open({
    required Uint8List ciphertext,
    required Uint8List tag,
    required Uint8List key,
    required Uint8List iv,
    required String protectedHeader,
  }) => Encrypter(AES(Key(key), mode: AESMode.gcm)).decryptBytes(
    Encrypted(Uint8List.fromList([...ciphertext, ...tag])),
    iv: IV(iv),
    associatedData: ascii.encode(protectedHeader),
  );

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String text) =>
      base64Url.decode(base64Url.normalize(text));
}
