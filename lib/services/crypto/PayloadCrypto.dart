import 'dart:convert';
import 'dart:typed_data';

import 'Aes.dart';
import 'Hashing.dart';

/// Ein abgeleiteter Schlüssel: 32 Byte für die Verschlüsselung, 32 Byte für
/// die Authentifizierung (HMAC).
///
/// Die beiden Hälften kommen aus *einer* PBKDF2-Ableitung, sind aber
/// unabhängig voneinander – ein Schlüssel wird nie für zwei Zwecke benutzt.
class DerivedKey {
  const DerivedKey(this.encryptionKey, this.authenticationKey);

  final Uint8List encryptionKey;
  final Uint8List authenticationKey;

  /// Länge der PBKDF2-Ableitung in Byte (2 x 32).
  static const int rawLength = 64;
}

/// Verschlüsselung der Sync- und Share-Inhalte: AES-256-CBC mit
/// HMAC-SHA-256 im "Encrypt-then-MAC"-Verfahren.
///
/// Die Verpackung ist bewusst simpel und selbstbeschreibend, weil sie von der
/// App in beide Richtungen gelesen wird (Push und Pull) und ein Server
/// dazwischen nur einen unveränderlichen Blob sieht:
///
/// ```json
/// {"v":1,"iv":"…","ct":"…","mac":"…","kdf":{"alg":"pbkdf2-sha256","iter":120000,"salt":"…"}}
/// ```
class PayloadCrypto {
  const PayloadCrypto._();

  /// Formatversion der Verpackung. Bei inkompatiblen Änderungen hochzählen –
  /// ältere Geräte lehnen dann eine neue Verpackung ab, statt sie falsch zu
  /// lesen.
  static const int envelopeVersion = 1;

  static const String keyDerivationAlgorithm = 'pbkdf2-sha256';

  /// PBKDF2-Runden. Hoch genug, dass ein Raten einzelner Wörter der
  /// Passphrase unattraktiv ist, niedrig genug, dass ein Sync auf einem
  /// älteren Handy nicht spürbar hängt.
  static const int defaultIterations = 120000;

  /// Leitet den Schlüssel aus einer Passphrase ab. [salt] trennt die
  /// Verwendungs Zwecke voneinander, damit derselbe Satz Text in einem Sync
  /// und in einem Share nie denselben Schlüssel ergibt.
  static DerivedKey deriveKey(
    String passphrase, {
    required String salt,
    int iterations = defaultIterations,
  }) {
    final Uint8List raw = Hashing.pbkdf2(
      password: Hashing.utf8Bytes(passphrase),
      salt: Hashing.utf8Bytes(salt),
      iterations: iterations,
      length: DerivedKey.rawLength,
    );
    return DerivedKey(
      Uint8List.sublistView(raw, 0, 32),
      Uint8List.sublistView(raw, 32, 64),
    );
  }

  /// Verschlüsselt eine Map als JSON und liefert die Verpackung als Map.
  static Map<String, dynamic> encryptJson(
    DerivedKey key,
    Map<String, dynamic> payload, {
    int iterations = defaultIterations,
    String salt = '',
  }) {
    final Uint8List iv = Hashing.randomBytes(Aes.blockSize);
    final Uint8List plaintext = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final Uint8List ciphertext = Aes(key.encryptionKey).encryptCbc(plaintext, iv);
    return wrap(key, iv, ciphertext, iterations: iterations, salt: salt);
  }

  /// Verschlüsselt beliebige Bytes (z.B. eine Datei).
  static Map<String, dynamic> encryptBytes(
    DerivedKey key,
    Uint8List bytes, {
    int iterations = defaultIterations,
    String salt = '',
  }) {
    final Uint8List iv = Hashing.randomBytes(Aes.blockSize);
    final Uint8List ciphertext = Aes(key.encryptionKey).encryptCbc(bytes, iv);
    return wrap(key, iv, ciphertext, iterations: iterations, salt: salt);
  }

  static Map<String, dynamic> wrap(
    DerivedKey key,
    Uint8List iv,
    Uint8List ciphertext, {
    required int iterations,
    required String salt,
  }) {
    final Uint8List mac = Hashing.hmacSha256(
      key.authenticationKey,
      <int>[..._macHeader(iv, iterations, salt), ...ciphertext],
    );
    return <String, dynamic>{
      'v': envelopeVersion,
      'iv': base64Url.encode(iv),
      'ct': base64Url.encode(ciphertext),
      'mac': base64Url.encode(mac),
      'kdf': <String, dynamic>{
        'alg': keyDerivationAlgorithm,
        'iter': iterations,
        'salt': salt,
      },
    };
  }

  /// Entschlüsselt eine von [encryptJson] erzeugte Verpackung.
  ///
  /// Wirft [PayloadCryptoException], wenn die Verpackung kaputt, von einer
  /// neueren App-Version oder mit dem falschen Schlüssel erzeugt wurde.
  static Map<String, dynamic> decryptJson(
    DerivedKey key,
    Map<String, dynamic> envelope,
  ) {
    final Uint8List plaintext = decryptBytes(key, envelope);
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plaintext));
    } catch (_) {
      throw const PayloadCryptoException('The shared data is not readable.');
    }
    if (decoded is! Map) {
      throw const PayloadCryptoException('The shared data is not readable.');
    }
    return decoded.cast<String, dynamic>();
  }

  /// Entschlüsselt eine Verpackung und gibt die Klarbytes zurück.
  static Uint8List decryptBytes(DerivedKey key, Map<String, dynamic> envelope) {
    final int version = _asInt(envelope['v']);
    if (version != envelopeVersion) {
      throw PayloadCryptoException(
        version > envelopeVersion
            ? 'This data was created by a newer version of the app.'
            : 'This data uses an unknown encryption format.',
      );
    }
    final Map<String, dynamic> kdf = _asMap(envelope['kdf']);
    if (kdf['alg'] != keyDerivationAlgorithm) {
      throw const PayloadCryptoException(
        'This data uses an unknown encryption format.',
      );
    }
    final String salt = kdf['salt']?.toString() ?? '';
    final int iterations = _asInt(kdf['iter'], fallback: defaultIterations);

    final Uint8List iv = _asBytes(envelope['iv'], 'iv');
    final Uint8List ciphertext = _asBytes(envelope['ct'], 'ct');
    final Uint8List mac = _asBytes(envelope['mac'], 'mac');

    final Uint8List expected = Hashing.hmacSha256(
      key.authenticationKey,
      <int>[..._macHeader(iv, iterations, salt), ...ciphertext],
    );
    if (!Hashing.constantTimeEquals(expected, mac)) {
      throw const PayloadCryptoException(
        'Wrong code – or the data was changed on the way.',
      );
    }

    try {
      return Aes(key.encryptionKey).decryptCbc(ciphertext, iv);
    } on FormatException {
      throw const PayloadCryptoException('The shared data is not readable.');
    }
  }

  /// Öffentlicher, umkehrbarer Bezeichner für einen Schlüssel.
  ///
  /// Wird verwendet, um ein Sync-Kette oder einen Share ohne Kenntnis der
  /// Passphrase beim Server *zu finden*: Wer die Passphrase kennt, berechnet
  /// denselben Bezeichner. Das ist sicher, weil die Passphrase aus zehn
  /// zufälligen Wörtern besteht und ein Raten nicht in Frage kommt – der
  /// Bezeichner gibt nichts preis, was nicht ohnehin in der Passphrase steht.
  static String publicId(String passphrase, String domain) {
    // Groß-/Kleinschreibung und Trennzeichen sind unerheblich: "Blue Sky",
    // "  blue   sky " und "blue-sky" müssen denselben Bezeichner ergeben.
    final String normalized = passphrase
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final Uint8List digest = Hashing.sha256(
      Hashing.utf8Bytes('$domain\n$normalized'),
    );
    return base64Url.encode(digest).replaceAll('=', '');
  }

  // ------------------------------------------------------------- Internes

  /// Header, der in die MAC-Berechnung eingeht, damit ein Angreifer nicht
  /// Iterationszahl, Salt oder IV austauschen kann, ohne am MAC zu scheitern.
  static Uint8List _macHeader(Uint8List iv, int iterations, String salt) {
    return Uint8List.fromList(<int>[
      ...utf8.encode('substitute/e2e/v$envelopeVersion'),
      ..._int32(iterations),
      ..._int32(salt.length),
      ...utf8.encode(salt),
      ..._int32(iv.length),
      ...iv,
    ]);
  }

  static Uint8List _int32(int value) => Uint8List(4)
    ..[0] = (value >> 24) & 0xFF
    ..[1] = (value >> 16) & 0xFF
    ..[2] = (value >> 8) & 0xFF
    ..[3] = value & 0xFF;

  static int _asInt(Object? value, {int? fallback}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback ?? 0;
    return fallback ?? 0;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    throw const PayloadCryptoException(
      'This data uses an unknown encryption format.',
    );
  }

  static Uint8List _asBytes(Object? value, String field) {
    if (value is! String) {
      throw const PayloadCryptoException('The shared data is not readable.');
    }
    try {
      return base64Url.decode(base64.normalize(value));
    } catch (_) {
      throw PayloadCryptoException('The shared data is not readable ($field).');
    }
  }
}

/// Fehler beim Entschlüsseln – trägt eine Meldung, die direkt in der UI
/// angezeigt werden kann.
class PayloadCryptoException implements Exception {
  const PayloadCryptoException(this.message);

  final String message;

  @override
  String toString() => 'PayloadCryptoException: $message';
}
