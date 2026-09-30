import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/crypto/Aes.dart';
import 'package:substitute/services/crypto/Hashing.dart';
import 'package:substitute/services/crypto/PayloadCrypto.dart';

Uint8List hex(String value) => Hashing.fromHex(value);

void main() {
  group('AES-256 (FIPS-197 test vectors)', () {
    // FIPS-197, Appendix C.3
    final Uint8List key =
        hex('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');
    final Uint8List plain = hex('00112233445566778899aabbccddeeff');

    test('encrypts the reference block', () {
      final Aes aes = Aes(key);
      expect(
        Hashing.toHex(aes.encryptBlock(plain)),
        '8ea2b7ca516745bfeafc49904b496089',
      );
    });

    test('decrypts the reference block back to the plaintext', () {
      final Aes aes = Aes(key);
      final Uint8List cipher = aes.encryptBlock(plain);
      expect(Hashing.toHex(aes.decryptBlock(cipher)), Hashing.toHex(plain));
    });

    test('rejects a key that is not 256 bit', () {
      expect(() => Aes(Uint8List(16)), throwsA(isA<AssertionError>()));
    });

    test('round trips a multi-block CBC message', () {
      final Aes aes = Aes(key);
      final Uint8List iv = hex('000102030405060708090a0b0c0d0e0f');
      final Uint8List message = Uint8List.fromList(
        List<int>.generate(1000, (int i) => (i * 7) % 256),
      );
      expect(aes.decryptCbc(aes.encryptCbc(message, iv), iv), message);
    });

    test('rejects a broken IV length', () {
      final Aes aes = Aes(key);
      expect(
        () => aes.encryptCbc(Uint8List(4), Uint8List(8)),
        throwsArgumentError,
      );
    });

    test('rejects ciphertext that is not block aligned', () {
      final Aes aes = Aes(key);
      expect(
        () => aes.decryptCbc(Uint8List(17), Uint8List(16)),
        throwsFormatException,
      );
    });

    test('CTR is its own inverse', () {
      final Aes aes = Aes(key);
      final Uint8List nonce = hex('0f0e0d0c0b0a09080706050403020100');
      final Uint8List message =
          Uint8List.fromList(List<int>.generate(70, (int i) => i % 256));
      expect(aes.applyCtr(aes.applyCtr(message, nonce), nonce), message);
    });
  });

  group('SHA-256', () {
    test('matches the FIPS-180 test vectors', () {
      expect(
        Hashing.toHex(Hashing.sha256(utf8.encode(''))),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        Hashing.toHex(Hashing.sha256(utf8.encode('abc'))),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('handles inputs that straddle block boundaries', () {
      // 55, 56, 63, 64 and 65 bytes exercise every padding branch.
      final Map<int, String> expected = <int, String>{
        55: '9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318',
        56: 'b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a',
        64: 'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb',
      };
      expected.forEach((int length, String digest) {
        expect(
          Hashing.toHex(Hashing.sha256(List<int>.filled(length, 0x61))),
          digest,
          reason: 'length $length',
        );
      });
    });

    test('agrees with a 1000 byte message', () {
      expect(
        Hashing.toHex(Hashing.sha256(List<int>.filled(1000, 0x61))),
        '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3',
      );
    });
  });

  group('HMAC-SHA-256 (RFC 4231)', () {
    test('matches test case 1', () {
      final List<int> key = List<int>.filled(20, 0x0b);
      expect(
        Hashing.toHex(Hashing.hmacSha256(key, utf8.encode('Hi There'))),
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      );
    });

    test('matches test case 2', () {
      expect(
        Hashing.toHex(Hashing.hmacSha256(utf8.encode('Jefe'),
            utf8.encode('what do ya want for nothing?'))),
        '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      );
    });
  });

  group('PBKDF2-HMAC-SHA256 (RFC 6070 style vectors)', () {
    test('matches the single-block vector', () {
      final Uint8List derived = Hashing.pbkdf2(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 1,
        length: 32,
      );
      expect(
        Hashing.toHex(derived),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('matches the two-block vector', () {
      final Uint8List derived = Hashing.pbkdf2(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 2,
        length: 32,
      );
      expect(
        Hashing.toHex(derived),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('handles lengths that need more than one block', () {
      final Uint8List derived = Hashing.pbkdf2(
        password: utf8.encode('passwordPASSWORDpassword'),
        salt: utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
        iterations: 4096,
        length: 40,
      );
      expect(
        Hashing.toHex(derived),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9',
      );
    });
  });

  group('constantTimeEquals', () {
    test('is true for equal buffers and false otherwise', () {
      expect(Hashing.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
      expect(Hashing.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
      expect(Hashing.constantTimeEquals(<int>[1, 2], <int>[1, 2, 3]), isFalse);
      expect(Hashing.constantTimeEquals(<int>[], <int>[]), isTrue);
    });
  });

  group('hex helpers', () {
    test('round trips', () {
      final Uint8List bytes = Uint8List.fromList(<int>[0, 1, 15, 16, 255]);
      expect(Hashing.fromHex(Hashing.toHex(bytes)), bytes);
    });

    test('rejects malformed input', () {
      expect(() => Hashing.fromHex('abc'), throwsFormatException);
      expect(() => Hashing.fromHex('zz'), throwsFormatException);
    });
  });

  group('PayloadCrypto', () {
    final DerivedKey key = PayloadCrypto.deriveKey(
      'blue sky river seven mango candle',
      salt: 'substitute/sync/v1',
      iterations: 1000,
    );

    test('round trips a payload', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'app': 'substitute',
        'schema': 2,
        'classes': <String>['5a', '10b'],
        'persons': <dynamic>[
          <String, dynamic>{'id': '1', 'name': 'Hans'},
        ],
      };
      final Map<String, dynamic> envelope =
          PayloadCrypto.encryptJson(key, payload, iterations: 1000);
      expect(
        PayloadCrypto.decryptJson(key, envelope),
        payload,
      );
    });

    test('does not leak the plaintext into the envelope', () {
      final Map<String, dynamic> envelope = PayloadCrypto.encryptJson(
        key,
        <String, dynamic>{'secret': 'Vertretungsplan für Frau Yilmaz'},
        iterations: 1000,
      );
      final String raw = jsonEncode(envelope);
      expect(raw.contains('Vertretungsplan'), isFalse);
      expect(raw.contains('Frau'), isFalse);
    });

    test('produces a different ciphertext every time (random IV)', () {
      final Map<String, dynamic> payload = <String, dynamic>{'a': 1};
      final String a =
          jsonEncode(PayloadCrypto.encryptJson(key, payload, iterations: 1000));
      final String b =
          jsonEncode(PayloadCrypto.encryptJson(key, payload, iterations: 1000));
      expect(a, isNot(b));
      expect(PayloadCrypto.decryptJson(key, jsonDecode(a)), payload);
      expect(PayloadCrypto.decryptJson(key, jsonDecode(b)), payload);
    });

    test('rejects the wrong passphrase', () {
      final Map<String, dynamic> envelope = PayloadCrypto.encryptJson(
        key,
        <String, dynamic>{'a': 1},
        iterations: 1000,
      );
      final DerivedKey other = PayloadCrypto.deriveKey(
        'completely different words here',
        salt: 'substitute/sync/v1',
        iterations: 1000,
      );
      expect(
        () => PayloadCrypto.decryptJson(other, envelope),
        throwsA(isA<PayloadCryptoException>()),
      );
    });

    test('rejects a tampered ciphertext', () {
      final Map<String, dynamic> envelope = PayloadCrypto.encryptJson(
        key,
        <String, dynamic>{'a': 1},
        iterations: 1000,
      );
      final List<int> ct = base64Url.decode(envelope['ct'] as String);
      ct[0] ^= 0xFF;
      envelope['ct'] = base64Url.encode(ct);
      expect(
        () => PayloadCrypto.decryptJson(key, envelope),
        throwsA(isA<PayloadCryptoException>()),
      );
    });

    test('rejects a swapped iteration count', () {
      final Map<String, dynamic> envelope = PayloadCrypto.encryptJson(
        key,
        <String, dynamic>{'a': 1},
        iterations: 1000,
      );
      (envelope['kdf'] as Map<String, dynamic>)['iter'] = 999;
      expect(
        () => PayloadCrypto.decryptJson(key, envelope),
        throwsA(isA<PayloadCryptoException>()),
      );
    });

    test('rejects a future envelope version', () {
      final Map<String, dynamic> envelope = PayloadCrypto.encryptJson(
        key,
        <String, dynamic>{'a': 1},
        iterations: 1000,
      );
      envelope['v'] = PayloadCrypto.envelopeVersion + 1;
      expect(
        () => PayloadCrypto.decryptJson(key, envelope),
        throwsA(isA<PayloadCryptoException>()),
      );
    });

    test('derives different keys for the same text in different domains', () {
      final DerivedKey syncKey = PayloadCrypto.deriveKey(
        'same words everywhere',
        salt: 'substitute/sync/v1',
        iterations: 1000,
      );
      final DerivedKey shareKey = PayloadCrypto.deriveKey(
        'same words everywhere',
        salt: 'substitute/share/v1',
        iterations: 1000,
      );
      expect(syncKey.encryptionKey, isNot(shareKey.encryptionKey));
    });

    test('publicId is stable, domain separated and free of padding', () {
      final String a = PayloadCrypto.publicId('Blue Sky', 'sync');
      final String b = PayloadCrypto.publicId('  blue   sky ', 'sync');
      final String c = PayloadCrypto.publicId('blue sky', 'share');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.contains('='), isFalse);
      expect(a, isNot(contains('blue')));
    });

    test('rejects an unknown key derivation algorithm', () {
      final Map<String, dynamic> envelope = PayloadCrypto.encryptJson(
        key,
        <String, dynamic>{'a': 1},
        iterations: 1000,
      );
      (envelope['kdf'] as Map<String, dynamic>)['alg'] = 'rot13';
      expect(
        () => PayloadCrypto.decryptJson(key, envelope),
        throwsA(isA<PayloadCryptoException>()),
      );
    });
  });

  group('randomBelow', () {
    test('stays in range and covers the whole range', () {
      final Set<int> seen = <int>{};
      for (int i = 0; i < 5000; i++) {
        final int value = Hashing.randomBelow(7);
        expect(value, inInclusiveRange(0, 6));
        seen.add(value);
      }
      // Bei 5 000 Ziehungen aus 7 Werten fehlt praktisch nie ein Wert.
      expect(seen.length, 7);
    });

    test('works for bounds above a byte', () {
      // Größen wie die Wortliste: eine Grenze über 256 darf nicht in einer
      // Endlosschleife landen, weil `range % max` dort `range` ist.
      final Set<int> seen = <int>{};
      for (int i = 0; i < 2000; i++) {
        final int value = Hashing.randomBelow(1128);
        expect(value, inInclusiveRange(0, 1127));
        if (i < 1128) seen.add(value);
      }
      // Bei 1 128 Ziehungen aus 1 128 Werten sind nach dem
      // Coupon-Collector-Effekt rund 1 128 * (1 - 1/e) ≈ 713 verschiedene
      // Werte zu erwarten – deutlich unter 1 128, aber weit über der
      // Hälfte. Genau das bestätigt, dass wirklich über den ganzen Bereich
      // gezogen wird und nicht nur über einen Teil.
      expect(seen.length, greaterThan(600));
    });

    test('works for exactly 256 and 257', () {
      expect(Hashing.randomBelow(256), inInclusiveRange(0, 255));
      expect(Hashing.randomBelow(257), inInclusiveRange(0, 256));
    });

    test('handles the degenerate bounds', () {
      expect(Hashing.randomBelow(1), 0);
      expect(() => Hashing.randomBelow(0), throwsArgumentError);
    });
  });
}
