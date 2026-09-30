import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/crypto/Hashing.dart';
import 'package:substitute/services/crypto/Passphrase.dart';
import 'package:substitute/services/sync/NameGuard.dart';

void main() {
  group('Passphrase.generate', () {
    test('produces exactly ten words by default', () {
      expect(Passphrase.split(Passphrase.generate()).length, 10);
      expect(Passphrase.wordCount, 10);
    });

    test('produces ten words with a capital letter at most', () {
      // Jedes Wort kommt aus der kuratierten Liste und ist deshalb ein
      // echtes englisches Wort statt einer zufälligen Zeichenfolge.
      for (int i = 0; i < 200; i++) {
        final List<String> words = Passphrase.split(Passphrase.generate());
        for (final String word in words) {
          expect(RegExp(r'^[a-z]{3,10}$').hasMatch(word), isTrue,
              reason: '"$word" is not a plain readable word');
        }
      }
    });

    test('never repeats a word within one phrase', () {
      for (int i = 0; i < 100; i++) {
        final List<String> words = Passphrase.split(Passphrase.generate());
        expect(words.toSet().length, words.length);
      }
    });

    test('uses the whole word list over many draws', () {
      final Set<String> seen = <String>{};
      for (int i = 0; i < 400; i++) {
        seen.addAll(Passphrase.split(Passphrase.generate()));
      }
      // Bei 4 000 Ziehungen aus über 1 000 Wörtern muss der größte Teil der
      // Liste vorkommen – sonst ist die Liste zu kurz und die Entropie zu
      // gering (ein Fehler, der sonst erst in der Praxis auffällt).
      expect(seen.length, greaterThan(Passphrase.size * 0.5));
    });

    test('is not predictable from a seeded Random in production use', () {
      // Ohne übergebenes Random kommt die Wahl aus der kryptografischen
      // Quelle – zwei Aufrufe liefern mit overwhelmingly hoher
      // Wahrscheinlichkeit verschiedene Phrasen.
      expect(Passphrase.generate(), isNot(Passphrase.generate()));
    });

    test('can be driven by a seeded Random for tests', () {
      final String a =
          Passphrase.generate(random: Random(42));
      final String b =
          Passphrase.generate(random: Random(42));
      expect(a, b);
    });

    test('rejects a nonsensical word count', () {
      expect(() => Passphrase.generate(words: 0), throwsArgumentError);
    });
  });

  group('Passphrase.split / normalize', () {
    test('ignores case, extra spaces and punctuation', () {
      const String messy = '  Blue   SKY,  river-seven!  Mango  ';
      expect(Passphrase.split(messy), <String>['blue', 'sky', 'river', 'seven', 'mango']);
      expect(Passphrase.normalize(messy), 'blue sky river seven mango');
    });

    test('treats a typed-out phrase and a scanned one identically', () {
      expect(
        Passphrase.normalize('blue sky river seven mango'),
        Passphrase.normalize('Blue-Sky, River Seven Mango.'),
      );
    });

    test('recognises what is and is not a phrase', () {
      expect(Passphrase.looksLikePassphrase('one two three'), isTrue);
      expect(Passphrase.looksLikePassphrase('one two'), isFalse);
      expect(Passphrase.looksLikePassphrase('   '), isFalse);
    });

    test('spots words that are not in the list', () {
      expect(
        Passphrase.unknownWords('blue appel sky'),
        <String>['appel'],
      );
      expect(Passphrase.unknownWords('blue sky river'), isEmpty);
    });
  });

  group('wordList', () {
    test('is large enough to be unguessable', () {
      // 10 Wörter aus N Wörtern: 10 * log2(N) Bit. Bei über 1 000 Wörtern sind
      // das mindestens 100 Bit.
      final double bits = 10 * (log(Passphrase.size) / ln2);
      expect(bits, greaterThan(100));
    });

    test('has no duplicates', () {
      expect(wordList.toSet().length, wordList.length);
    });

    test('contains only plain, short, readable words', () {
      for (final String word in wordList) {
        expect(RegExp(r'^[a-z]{3,10}$').hasMatch(word), isTrue,
            reason: '"$word" does not match the word format');
      }
    });

    test('contains no offensive or otherwise unusable words', () {
      // Die Wortliste ist auch die Wortliste für Nutzernamen, die in der Suche
      // auftauchen – hier darf nichts anstößig stehen.
      for (final String word in wordList) {
        expect(NameGuard.isAllowed(word), isTrue, reason: '"$word"');
      }
    });
  });
}
