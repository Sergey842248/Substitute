import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Hash- und Schlüsselableitungsfunktionen (SHA-256, HMAC-SHA256, PBKDF2) als
/// reine Dart-Funktionen.
///
/// `package:crypto` wird bewusst nicht genommen: Die Sync-/Share-Funktionen
/// sollen keine zusätzliche Abhängigkeit in den App-Build ziehen, und der
/// Server unter `docs/server` soll exakt denselben Code verwenden können.
/// PBKDF2 ist hier unkritisch in Bezug auf die Laufzeit, weil die Passphrasen
/// aus zehn zufälligen Wörtern bestehen und damit weit über 100 Bit Entropie
/// haben – die Iterationen schützen vor dem Raten einzelner Wörter.
class Hashing {
  const Hashing._();

  static const int sha256BlockSize = 64;

  /// SHA-256 über beliebige Bytes.
  static Uint8List sha256(List<int> message) {
    final Uint8List data = _padded(message);
    final Uint32List h = Uint32List.fromList(<int>[
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]);

    final Uint32List w = Uint32List(64);
    for (int offset = 0; offset < data.length; offset += 64) {
      for (int i = 0; i < 16; i++) {
        final int p = offset + i * 4;
        w[i] = (data[p] << 24) |
            (data[p + 1] << 16) |
            (data[p + 2] << 8) |
            data[p + 3];
      }
      for (int i = 16; i < 64; i++) {
        final int s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final int s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h[0], b = h[1], c = h[2], d = h[3];
      int e = h[4], f = h[5], g = h[6], hh = h[7];

      for (int i = 0; i < 64; i++) {
        final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final int ch = (e & f) ^ (~e & g);
        final int temp1 = (hh + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
        final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final int maj = (a & b) ^ (a & c) ^ (b & c);
        final int temp2 = (s0 + maj) & 0xFFFFFFFF;

        hh = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h[0] = (h[0] + a) & 0xFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFF;
      h[7] = (h[7] + hh) & 0xFFFFFFFF;
    }

    final Uint8List out = Uint8List(32);
    for (int i = 0; i < 8; i++) {
      out[i * 4] = (h[i] >> 24) & 0xFF;
      out[i * 4 + 1] = (h[i] >> 16) & 0xFF;
      out[i * 4 + 2] = (h[i] >> 8) & 0xFF;
      out[i * 4 + 3] = h[i] & 0xFF;
    }
    return out;
  }

  /// HMAC-SHA-256 (RFC 2104).
  static Uint8List hmacSha256(List<int> key, List<int> message) {
    Uint8List normalisedKey = Uint8List.fromList(key);
    if (normalisedKey.length > sha256BlockSize) {
      normalisedKey = sha256(normalisedKey);
    }
    final Uint8List padded = Uint8List(sha256BlockSize);
    padded.setRange(0, normalisedKey.length, normalisedKey);

    final Uint8List inner = Uint8List(sha256BlockSize);
    final Uint8List outer = Uint8List(sha256BlockSize);
    for (int i = 0; i < sha256BlockSize; i++) {
      inner[i] = padded[i] ^ 0x36;
      outer[i] = padded[i] ^ 0x5C;
    }
    return sha256(<int>[...outer, ...sha256(<int>[...inner, ...message])]);
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018) – leitet [length] Schlüsselbytes ab.
  static Uint8List pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int length,
  }) {
    if (iterations < 1) throw ArgumentError.value(iterations, 'iterations');
    if (length < 1) throw ArgumentError.value(length, 'length');

    final Uint8List out = Uint8List(length);
    int produced = 0;
    for (int block = 1; produced < length; block++) {
      final Uint8List saltBlock = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (block >> 24) & 0xFF
        ..[salt.length + 1] = (block >> 16) & 0xFF
        ..[salt.length + 2] = (block >> 8) & 0xFF
        ..[salt.length + 3] = block & 0xFF;

      Uint8List u = hmacSha256(password, saltBlock);
      final Uint8List t = Uint8List.fromList(u);
      for (int i = 1; i < iterations; i++) {
        u = hmacSha256(password, u);
        for (int j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final int take = (length - produced) < t.length ? (length - produced) : t.length;
      out.setRange(produced, produced + take, t);
      produced += take;
    }
    return out;
  }

  /// Vergleich zweier Bytefolgen in konstanter Zeit – verhindert, dass ein
  /// Angreifer durch Messen der Antwortzeit ein MAC errät.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String toHex(List<int> bytes) =>
      bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List fromHex(String hex) {
    final String cleaned = hex.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length.isOdd) throw const FormatException('Odd length hex');
    final Uint8List out = Uint8List(cleaned.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      final int? value = int.tryParse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
      if (value == null) throw const FormatException('Invalid hex');
      out[i] = value;
    }
    return out;
  }

  /// Kryptografisch zufällige Bytes aus der stärksten vom System angebotenen
  /// Quelle (auf Geräten ohne `Random.secure()` wird degradiert).
  static Uint8List randomBytes(int length) {
    final Random random = _secureRandom();
    final Uint8List out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = random.nextInt(256);
    }
    return out;
  }

  /// Zufallszahl in `[0, max)` – vermeidet das modulo-Verzerrungsproblem von
  /// `nextInt` bei nicht Zweierpotenzen, indem überschüssige Werte verworfen
  /// werden (Rejection Sampling).
  ///
  /// [max] muss höchstens 2^32 sein.
  static int randomBelow(int max) {
    if (max < 1) throw ArgumentError.value(max, 'max', 'Must be at least 1');
    if (max == 1) return 0;
    assert(max <= 0x100000000, 'max must not exceed 2^32');
    final Random random = _secureRandom();
    // 8-Bit-Bereich, solange [max] hineinpasst – das ist der Fall für
    // Passphrasen, wo [randomBelow] pro Wort aufgerufen wird.
    final int bits = max <= 0x100 ? 8 : 32;
    final int range = 1 << bits;
    // Der kleinste Wert, bei dem `range % max == 0`; alles darüber wird
    // verworfen, damit jede Zahl exakt gleich oft vorkommt.
    final int limit = range - (range % max);
    int value;
    do {
      value = random.nextInt(range);
    } while (value >= limit);
    return value % max;
  }

  static Random? _cachedRandom;
  static Random _secureRandom() {
    try {
      return _cachedRandom ??= Random.secure();
    } catch (_) {
      return _cachedRandom ??= Random(DateTime.now().microsecondsSinceEpoch);
    }
  }

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

  static Uint8List _padded(List<int> message) {
    final int bitLength = message.length * 8;
    // 1 Byte 0x80, dann Nullen, dann die 64-Bit-Länge. Die Gesamtlänge muss ein
    // Vielfaches von 64 sein – deshalb wird die Restlänge *modulo* 64
    // genommen: Ist sie bereits 0 (z.B. bei 55 Byte Nachricht), wird kein
    // zusätzlicher Block angehängt.
    final int padding =
        (sha256BlockSize - ((message.length + 9) % sha256BlockSize)) %
            sha256BlockSize;
    final Uint8List data = Uint8List(message.length + 1 + padding + 8);
    data.setRange(0, message.length, message);
    data[message.length] = 0x80;
    final int lengthOffset = data.length - 8;
    for (int i = 0; i < 8; i++) {
      data[lengthOffset + i] = (bitLength >> (56 - i * 8)) & 0xFF;
    }
    return data;
  }

  /// UTF-8-Bytes eines Textes – der Normalfall für Passphrasen.
  static List<int> utf8Bytes(String text) => utf8.encode(text);

  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
}
