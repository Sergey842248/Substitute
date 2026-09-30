import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/sync/NameGuard.dart';

void main() {
  group('NameGuard.normalize', () {
    test('lowercases and strips everything that is not a letter', () {
      expect(NameGuard.normalize('Frau Muster'), 'fraumuster');
      expect(NameGuard.normalize('Müller'), 'muller');
      expect(NameGuard.normalize("O'Brien-Smith"), 'obriensmith');
    });

    test('resolves ß to ss', () {
      // 'ß' ist ein einzelner Zeichencode, aber zwei Konsonten wert – sonst
      // würde 'Scheiß' zu 'scheis' und am Blocklisteneintrag vorbeikommen.
      // 'Scheiß' -> 'schei' + 'ss'; die ausgeschriebene Form 'Scheisse' hat
      // ein zusätzliches 'e' und ist damit ein anderes Wort. Beide werden
      // über den Stamm 'scheiss' geblockt (siehe die Komposit-Liste).
      expect(NameGuard.normalize('Scheiß'), 'scheiss');
      expect(NameGuard.normalize('Scheisse'), 'scheisse');
      expect(NameGuard.normalize('Straße'), 'strasse');
      expect(NameGuard.isAllowed('Scheiß'), isFalse);
      expect(NameGuard.isAllowed('Scheisse'), isFalse);
    });

    test('folds leetspeak back onto the plain letters', () {
      expect(NameGuard.normalize('b1tch'), 'bitch');
      expect(NameGuard.normalize('sh1t'), 'shit');
      expect(NameGuard.normalize('@rsch'), 'arsch');
    });

    test('squashes stretched letters', () {
      // Drei oder mehr gleiche Buchstaben werden auf zwei reduziert.
      expect(NameGuard.normalize('fuuuuuck'), 'fuuck');
      expect(NameGuard.normalize('aardvark'), 'aardvark');
      // 'scheiiße' -> 'schei' + 'i' + 'ss'; die Doppel-i bleibt stehen, weil
      // erst ab drei gleichen Zeichen reduziert wird.
      expect(NameGuard.normalize('scheiiße'), 'scheiisse');
      // Vier gleiche Zeichen werden auf zwei gebracht, drei nicht.
      expect(NameGuard.normalize('müller'), 'muller');
      // Doppelte Konsonten bleiben erhalten, sonst würde 'll' zu 'l'.
      expect(NameGuard.normalize('Schille'), 'schille');
    });

    test('sees through separators', () {
      expect(NameGuard.normalize('f-u-c-k'), 'fuck');
      expect(NameGuard.normalize('f.u.c.k'), 'fuck');
      expect(NameGuard.normalize('F U C K'), 'fuck');
    });
  });

  group('NameGuard.check – blocks offensive names in any spelling', () {
    const List<String> mustBeBlocked = <String>[
      'Arschloch',
      'arschloch',
      'ARSCHLOCH',
      'Arsch loch',
      'a-r-s-c-h-l-o-c-h',
      'Ärschloch',
      'Arschl0ch',
      'Arschlоch', // kyrillisches 'о'
      'Scheißkopf',
      'Scheisskopf',
      'Scheiß kopf',
      'SCHEISS',
      'Dreckkerl',
      'Dumbsack',
      'Fotzenhocker',
      'Ficktack',
      'Ficker',
      'N1gger',
      'Nigg3r',
      'Faggot',
      'Fag',
      'Wichser',
      'Hurensohn',
      'Idiot',
      'Motherfucker',
      'Bastard',
      'Pornografie',
      'Nackt',
    ];

    for (final String name in mustBeBlocked) {
      test('blocks "$name"', () {
        final NameVerdict verdict = NameGuard.check(name);
        expect(verdict.isBlocked, isTrue, reason: '"$name" must be blocked');
        expect(verdict.reason, 'blocked');
        expect(verdict.matchedTerm, isNotNull);
      });
    }
  });

  group('NameGuard.check – allows ordinary names', () {
    // Echte Namen, die bei einer groben Prüfung leicht versehentlich fallen
    // würden. Sie stehen hier, weil eine zu strenge Liste für Lehrkräfte
    // unbrauchbar wäre.
    const List<String> mustBeAllowed = <String>[
      'Frau Muster',
      'Herr Schmidt',
      'Müller',
      'Brückner',
      'Bass',
      'Klasse',
      'Klassenzimmer',
      'Dickmann',
      'Pohlmann',
      'Sexy Teacher',
      'Klug',
      'Fuchs',
      'Ostermann',
      'Gastmann',
      'Reimann',
      'Anna Bergmann',
      'Herr Müller-Schmidt',
      "O'Brien",
      'Peter Schmidt (5b)',
      'Hürth',
      'Sahne',
    ];

    for (final String name in mustBeAllowed) {
      test('allows "$name"', () {
        final NameVerdict verdict = NameGuard.check(name);
        expect(verdict.isBlocked, isFalse,
            reason: '"$name" was blocked by "${verdict.matchedTerm}"');
      });
    }
  });

  group('NameGuard.check – structural rules', () {
    test('rejects an empty name', () {
      expect(NameGuard.check('').reason, 'empty');
      expect(NameGuard.check('   ').reason, 'empty');
    });

    test('rejects a name that is too short', () {
      expect(NameGuard.check('A').reason, 'tooShort');
      expect(NameGuard.check('  A  ').reason, 'tooShort');
    });

    test('rejects a name that is too long', () {
      expect(NameGuard.check('A' * 41).reason, 'tooLong');
      expect(NameGuard.isAllowed('A' * 40), isTrue);
    });

    test('trims surrounding whitespace before judging', () {
      expect(NameGuard.isAllowed('  Frau Muster  '), isTrue);
    });
  });

  group('NameGuard – the blocklists themselves', () {
    test('contain only usable terms', () {
      for (final String term in <String>[
        ...NameGuard.blockedTerms,
        ...NameGuard.compoundTerms,
        ...NameGuard.blockedPhrases,
      ]) {
        expect(term.trim(), term, reason: 'Begriff "$term" hat Randleerzeichen');
        expect(
          NameGuard.normalize(term).isNotEmpty,
          isTrue,
          reason: 'Begriff "$term" normalisiert zu nichts – er wäre wirkungslos',
        );
      }
    });

    test('have no duplicates within a list', () {
      for (final List<String> list in <List<String>>[
        NameGuard.blockedTerms,
        NameGuard.compoundTerms,
        NameGuard.blockedPhrases,
      ]) {
        expect(list.toSet().length, list.length,
            reason: 'Doppelte Einträge: ${list.where((String t) => list.where((String o) => o == t).length > 1).toSet()}');
      }
    });

    test('block every term they list', () {
      // Eine Regel, die ihre eigene Liste verfehlt, ist ein stiller Fehler:
      // Der Begriff käme in der App durch.
      for (final String term in NameGuard.compoundTerms) {
        expect(NameGuard.isAllowed(term), isFalse, reason: '"$term"');
        // Auch als Vorsilbe eines Kompositums.
        expect(NameGuard.isAllowed('${term}kopf'), isFalse, reason: '"${term}kopf"');
      }
      for (final String term in NameGuard.blockedTerms) {
        expect(NameGuard.isAllowed(term), isFalse, reason: '"$term"');
      }
    });
  });
}
