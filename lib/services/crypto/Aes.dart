import 'dart:typed_data';

/// AES-Block-Cipher (128-Bit-Blöcke) in den Betriebsarten CBC und CTR.
///
/// Bewusst ohne Abhängigkeit zu einem Krypto-Paket: Die App muss auf Android,
/// iOS und im Web dieselben Bytes erzeugen, und die Implementierung wird
/// gegen die offiziellen FIPS-197-Testvektoren geprüft (siehe
/// `test/aes_test.dart`). Schlüssel sind immer 32 Byte (AES-256).
///
/// Der Server sieht diese Daten nie – er transportiert nur Blobs, die das
/// Gerät bereits verschlüsselt hat ("End-to-End", der Server ist blind).
class Aes {
  Aes(Uint8List key)
      : assert(key.length == 32, 'Only AES-256 (32 byte keys) is supported'),
        _roundKeys = expandKey(key);

  /// 16 Byte = 128 Bit.
  static const int blockSize = 16;

  static const int _nb = 4; // Spalten in der State-Matrix
  static const int _keyLength = 32;
  static const int _nk = _keyLength ~/ 4; // 8 Schlüsselwörter für AES-256
  static const int _nr = 14; // Rundenzahl für AES-256

  final Uint8List _roundKeys;

  /// Verschlüsselt einen einzelnen Block (16 Byte) im ECB – die Grundoperation,
  /// aus der CBC und CTR bestehen.
  Uint8List encryptBlock(Uint8List input) {
    final Uint8List state = Uint8List.fromList(input);
    _addRoundKey(state, 0);
    for (int round = 1; round < _nr; round++) {
      _subBytes(state, sbox);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, round);
    }
    _subBytes(state, sbox);
    _shiftRows(state);
    _addRoundKey(state, _nr);
    return state;
  }

  /// Entschlüsselt einen einzelnen Block (16 Byte) im ECB.
  Uint8List decryptBlock(Uint8List input) {
    final Uint8List state = Uint8List.fromList(input);
    _addRoundKey(state, _nr);
    for (int round = _nr - 1; round > 0; round--) {
      _invShiftRows(state);
      _subBytes(state, invSbox);
      _addRoundKey(state, round);
      _invMixColumns(state);
    }
    _invShiftRows(state);
    _subBytes(state, invSbox);
    _addRoundKey(state, 0);
    return state;
  }

  // ---------------------------------------------------------------- CBC

  /// AES-256-CBC mit zufälligem IV. [iv] muss 16 Byte lang sein.
  Uint8List encryptCbc(Uint8List plaintext, Uint8List iv) {
    _checkIv(iv);
    final Uint8List padded = _pkcs7Pad(plaintext);
    final Uint8List out = Uint8List(padded.length);
    Uint8List previous = Uint8List.fromList(iv);
    for (int offset = 0; offset < padded.length; offset += blockSize) {
      final Uint8List block = Uint8List(blockSize);
      for (int i = 0; i < blockSize; i++) {
        block[i] = padded[offset + i] ^ previous[i];
      }
      final Uint8List encrypted = encryptBlock(block);
      out.setRange(offset, offset + blockSize, encrypted);
      previous = encrypted;
    }
    return out;
  }

  /// AES-256-CBC-Entschlüsselung. Wirft [FormatException], wenn die
  /// Nachricht kein Vielfaches der Blockgröße ist.
  Uint8List decryptCbc(Uint8List ciphertext, Uint8List iv) {
    _checkIv(iv);
    if (ciphertext.isEmpty || ciphertext.length % blockSize != 0) {
      throw const FormatException('Ciphertext is not block aligned');
    }
    final Uint8List out = Uint8List(ciphertext.length);
    Uint8List previous = Uint8List.fromList(iv);
    for (int offset = 0; offset < ciphertext.length; offset += blockSize) {
      final Uint8List block = Uint8List.fromList(
        ciphertext.sublist(offset, offset + blockSize),
      );
      final Uint8List decrypted = decryptBlock(block);
      for (int i = 0; i < blockSize; i++) {
        out[offset + i] = decrypted[i] ^ previous[i];
      }
      previous = block;
    }
    return _pkcs7Unpad(out);
  }

  // ---------------------------------------------------------------- CTR

  /// AES-256-CTR. [nonce] muss 16 Byte lang sein; der mitgelieferte
  /// 4-Byte-Zähler wird im Betrieb angenommen, damit Clients ohne
  /// zusätzliche Zufallsquelle auskommen.
  Uint8List applyCtr(Uint8List data, Uint8List nonce) {
    _checkIv(nonce);
    final Uint8List out = Uint8List(data.length);
    final Uint8List counter = Uint8List.fromList(nonce);
    for (int offset = 0; offset < data.length; offset += blockSize) {
      final Uint8List keyStream = encryptBlock(counter);
      final int chunk = (data.length - offset) < blockSize
          ? (data.length - offset)
          : blockSize;
      for (int i = 0; i < chunk; i++) {
        out[offset + i] = data[offset + i] ^ keyStream[i];
      }
      _incrementCounter(counter);
    }
    return out;
  }

  static void _checkIv(Uint8List iv) {
    if (iv.length != blockSize) {
      throw ArgumentError.value(
        iv.length,
        'iv',
        'An initialization vector must be $blockSize bytes long',
      );
    }
  }

  static void _incrementCounter(Uint8List counter) {
    for (int i = counter.length - 1; i >= 0; i--) {
      counter[i] = (counter[i] + 1) & 0xFF;
      if (counter[i] != 0) return;
    }
  }

  // --------------------------------------------------------- Rundenfunktionen

  void _addRoundKey(Uint8List state, int round) {
    final int offset = round * _nb * 4;
    for (int i = 0; i < state.length; i++) {
      state[i] ^= _roundKeys[offset + i];
    }
  }

  static void _subBytes(Uint8List state, List<int> table) {
    for (int i = 0; i < state.length; i++) {
      state[i] = table[state[i]];
    }
  }

  static void _shiftRows(Uint8List s) {
    _rotateRows(s, 1);
  }

  static void _invShiftRows(Uint8List s) {
    _rotateRows(s, 3);
  }

  /// Rotiert jede Zeile zyklisch: `state'[c][r] = state[(c + shift) % 4][r]`.
  ///
  /// ShiftRows benutzt `shift == r`, InvShiftRows `shift == (4 - r) % 4` –
  /// beides sind zyklische Verschiebungen, keine Vertauschungen, deshalb der
  /// Zwischenpuffer je Zeile.
  static void _rotateRows(Uint8List s, int direction) {
    final Uint8List row = Uint8List(_nb);
    for (int r = 0; r < _nb; r++) {
      final int shift = direction * r % _nb;
      for (int c = 0; c < _nb; c++) {
        row[c] = s[c * 4 + r];
      }
      for (int c = 0; c < _nb; c++) {
        s[c * 4 + r] = row[(c + shift) % _nb];
      }
    }
  }

  static void _mixColumns(Uint8List s) {
    for (int c = 0; c < 4; c++) {
      final int i = c * 4;
      final int a0 = s[i], a1 = s[i + 1], a2 = s[i + 2], a3 = s[i + 3];
      s[i] = _gmul(a0, 2) ^ _gmul(a1, 3) ^ a2 ^ a3;
      s[i + 1] = a0 ^ _gmul(a1, 2) ^ _gmul(a2, 3) ^ a3;
      s[i + 2] = a0 ^ a1 ^ _gmul(a2, 2) ^ _gmul(a3, 3);
      s[i + 3] = _gmul(a0, 3) ^ a1 ^ a2 ^ _gmul(a3, 2);
    }
  }

  static void _invMixColumns(Uint8List s) {
    for (int c = 0; c < 4; c++) {
      final int i = c * 4;
      final int a0 = s[i], a1 = s[i + 1], a2 = s[i + 2], a3 = s[i + 3];
      s[i] = _gmul(a0, 14) ^ _gmul(a1, 11) ^ _gmul(a2, 13) ^ _gmul(a3, 9);
      s[i + 1] = _gmul(a0, 9) ^ _gmul(a1, 14) ^ _gmul(a2, 11) ^ _gmul(a3, 13);
      s[i + 2] = _gmul(a0, 13) ^ _gmul(a1, 9) ^ _gmul(a2, 14) ^ _gmul(a3, 11);
      s[i + 3] = _gmul(a0, 11) ^ _gmul(a1, 13) ^ _gmul(a2, 9) ^ _gmul(a3, 14);
    }
  }

  // ------------------------------------------------------------ Schlüssel

  /// Schlüsselexpansion nach FIPS-197 für AES-256.
  ///
  /// Öffentlich, damit die Testsuite den Schlüsselplan gegen die
  /// FIPS-197-Referenzwerte prüfen kann – ein Fehler hier ist sonst sehr
  /// schwer zu finden.
  static Uint8List expandKey(Uint8List key) {
    // (Nr + 1) * Nb * 4 = 15 * 16 = 240 Byte
    final Uint8List words = Uint8List(4 * (_nr + 1) * _nb);
    for (int i = 0; i < _nk; i++) {
      words[i * 4] = key[i * 4];
      words[i * 4 + 1] = key[i * 4 + 1];
      words[i * 4 + 2] = key[i * 4 + 2];
      words[i * 4 + 3] = key[i * 4 + 3];
    }

    final Uint8List rcon = Uint8List.fromList(<int>[
      0x00, 0x01, 0x02, 0x04, 0x08, 0x10,
      0x20, 0x40, 0x80, 0x1B, 0x36, 0x6C, 0xD8, 0xAB, 0x4D,
    ]);

    final Uint8List temp = Uint8List(4);
    for (int i = _nk; i < 4 * (_nr + 1); i++) {
      for (int j = 0; j < 4; j++) temp[j] = words[(i - 1) * 4 + j];

      if (i % _nk == 0) {
        // RotWord
        final int first = temp[0];
        temp[0] = temp[1];
        temp[1] = temp[2];
        temp[2] = temp[3];
        temp[3] = first;
        // SubWord
        for (int j = 0; j < 4; j++) {
          temp[j] = sbox[temp[j]];
        }
        temp[0] ^= rcon[i ~/ _nk];
      } else if (i % _nk == 4) {
        // Zusätzliche SubWord-Runde für AES-256.
        for (int j = 0; j < 4; j++) {
          temp[j] = sbox[temp[j]];
        }
      }
      for (int j = 0; j < 4; j++) {
        words[i * 4 + j] = words[(i - _nk) * 4 + j] ^ temp[j];
      }
    }
    return words;
  }

  // ---------------------------------------------------------------- Tabellen

  /// Produkt in GF(2^8) mit dem AES-Polynom x^8 + x^4 + x^3 + x + 1.
  static int _gmul(int a, int b) {
    int result = 0;
    for (int i = 0; i < 8; i++) {
      if ((b & 1) != 0) result ^= a;
      b >>= 1;
      a = ((a & 0x80) != 0) ? (((a << 1) & 0xFF) ^ 0x1B) : ((a << 1) & 0xFF);
    }
    return result & 0xFF;
  }

  static int _rotl8(int x, int shift) =>
      ((x << shift) | (x >> (8 - shift))) & 0xFF;

  /// Die S-Box wird aus der mathematischen Definition erzeugt statt als
  /// 256 Zeilen Tabelle: so gibt es keine Tippfehler und die Datei bleibt
  /// lesbar.
  static final List<int> sbox = List<int>.unmodifiable(_buildSbox());

  /// Umgekehrte S-Box, per Permutation aus [sbox] abgeleitet.
  static final List<int> invSbox = List<int>.unmodifiable(_buildInvSbox());

  static List<int> _buildSbox() {
    final List<int> table = List<int>.filled(256, 0);
    for (int x = 0; x < 256; x++) {
      // Multiplikative Inverse in GF(2^8); 0 bildet auf 0 ab.
      int inverse = 0;
      if (x != 0) {
        for (int y = 1; y < 256; y++) {
          if (_gmul(x, y) == 1) {
            inverse = y;
            break;
          }
        }
      }
      int result = inverse;
      for (int shift = 1; shift <= 4; shift++) {
        result ^= _rotl8(inverse, shift);
      }
      table[x] = result ^ 0x63;
    }
    return table;
  }

  static List<int> _buildInvSbox() {
    final List<int> table = List<int>.filled(256, 0);
    for (int x = 0; x < 256; x++) {
      table[sbox[x]] = x;
    }
    return table;
  }

  // ------------------------------------------------------------- Padding

  static Uint8List _pkcs7Pad(Uint8List data) {
    final int padding = blockSize - (data.length % blockSize);
    final Uint8List out = Uint8List(data.length + padding)..setRange(0, data.length, data);
    for (int i = data.length; i < out.length; i++) {
      out[i] = padding;
    }
    return out;
  }

  static Uint8List _pkcs7Unpad(Uint8List data) {
    final int padding = data[data.length - 1];
    if (padding < 1 || padding > blockSize || padding > data.length) {
      throw const FormatException('Invalid padding');
    }
    for (int i = data.length - padding; i < data.length; i++) {
      if (data[i] != padding) throw const FormatException('Invalid padding');
    }
    return Uint8List.sublistView(data, 0, data.length - padding);
  }
}
