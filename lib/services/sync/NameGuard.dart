/// Blockliste für Namen, die in einem Share- oder Such-Eintrag sichtbar werden.
///
/// Zwei Anforderungen stecken dahinter:
///
/// 1. **Keine anstößigen Namen.** Ein Nutzername oder ein Anzeigename steht
///    offen in einer Suchliste, die alle Nutzer einer Schulnummer sehen. Namen,
///    die beleidigend, geschmacklos oder diskriminierend sind, werden deshalb
///    abgelehnt.
/// 2. **Robust gegen Umgehung.** Die Prüfung läuft auf einer normalisierten
///    Form, damit `F@@k`, `f-a-k` und `Faaaak` genauso erkannt werden wie
///    `Fak` – in jeder Schreibweise, wie es in der Anforderung heißt.
///
/// Die Liste ist bewusst eine Positiv-/Negativ-Liste mit whole-word- und
/// Substring-Prüfung statt eines Modells: Sie muss offline, ohne Netz und auf
/// jedem Gerät identisch funktionieren, und das Ergebnis muss für den Nutzer
/// nachvollziehbar sein ("Dieser Name ist nicht erlaubt").
library;

/// Ergebnis einer Namensprüfung.
class NameVerdict {
  const NameVerdict._(this.isBlocked, this.reason, this.matchedTerm);

  /// Der Name ist unproblematisch.
  static const NameVerdict allowed = NameVerdict._(false, null, null);

  /// Der Name wird abgelehnt. [reason] ist ein Schlüssel, mit dem die UI eine
  /// übersetzbare Meldung wählt; [matchedTerm] ist das Wort, das anstoß war
  /// (wird nicht angezeigt, hilft aber beim Nachvollziehen im Test).
  final bool isBlocked;
  final String? reason;
  final String? matchedTerm;

  bool get isAllowed => !isBlocked;
}

/// Prüft Namen, bevor sie anderen Nutzern angezeigt werden.
class NameGuard {
  const NameGuard._();

  /// Mindestlänge eines Anzeigenamens.
  static const int minimumLength = 2;

  /// Höchstlänge eines Anzeigenamens.
  static const int maximumLength = 40;

  /// Prüft einen Anzeigenamen.
  ///
  /// Leer und zu kurz ist genauso abgelehnt wie ein blockierter Name – beide
  /// Fälle liefern einen [NameVerdict], damit die UI nur eine Stelle abfragen
  /// muss.
  static NameVerdict check(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const NameVerdict._(true, 'empty', null);
    }
    if (trimmed.length < minimumLength) {
      return const NameVerdict._(true, 'tooShort', null);
    }
    if (trimmed.length > maximumLength) {
      return const NameVerdict._(true, 'tooLong', null);
    }

    final String normalized = normalize(trimmed);

    for (final String term in _normalizedPhrases) {
      if (normalized.contains(term)) {
        return NameVerdict._(true, 'blocked', term);
      }
    }
    for (final String term in _normalizedWordTerms) {
      if (_containsWord(normalized, term)) {
        return NameVerdict._(true, 'blocked', term);
      }
    }
    for (final String term in _normalizedCompoundTerms) {
      if (_startsWord(normalized, term)) {
        return NameVerdict._(true, 'blocked', term);
      }
    }
    return NameVerdict.allowed;
  }

  /// true, wenn [name] verwendet werden darf.
  static bool isAllowed(String name) => check(name).isAllowed;

  /// Bringt einen Namen in die Form, in der verglichen wird.
  ///
  /// * Kleinschreibung,
  /// * Diakritika werden entfernt (`ä` -> `a`), damit `scheiße` und
  ///   `scheisse` denselben Treffer ergeben,
  /// * `ß` wird zu `ss`,
  /// * Leet- und Tastatur-Ersatz wird auf den Klarbuchstaben zurückgeführt
  ///   (`4`/`@` -> `a`, `0` -> `o`, `1`/`!` -> `i`, `3` -> `e`, `5`/`$` -> `s`,
  ///   `7` -> `t`, …),
  /// * alle übrigen Zeichen fallen weg, sodass `f-u-c-k` wie `fuck` aussieht.
  static String normalize(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in _foldLetters(input).runes) {
      buffer.write(String.fromCharCode(rune));
    }
    final String collapsed = buffer.toString();

    // Aus 'fuuuuuck' wird 'fuuck' -> 'fuck': mehr als zwei gleiche Buchstaben
    // hintereinander werden auf zwei reduziert. Das erwischt Dehnungen wie
    // 'scheiiße' oder 'fuuuuck', ohne 'll' oder 'ss' zu zerstören.
    final String squashed = collapsed.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (Match match) => '${match.group(1)}${match.group(1)}',
    );
    return squashed.replaceAll(RegExp('[^a-z]'), '');
  }

  /// Ersetzt Sonderzeichen und Leet-Schreibweisen durch ihre Klarform.
  static String _foldLetters(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.toLowerCase().runes) {
      final String? spelled = _spelledOut[rune];
      if (spelled != null) {
        // Manche Zeichen werden zu mehreren Buchstaben: `ß` ist ein einzelner
        // Rune, aber zwei Konsonten wert (`scheisse`, nicht `scheise`).
        buffer.write(spelled);
        continue;
      }
      // Zeichen ohne Ersatzeintrag bleiben unverändert stehen; was danach
      // keine Kleinbuchstabe ist, fällt in [normalize] weg.
      buffer.writeCharCode(_foldTable[rune] ?? _stripDiacritic[rune] ?? rune);
    }
    return buffer.toString();
  }

  /// Zeichen, die zu mehreren Buchstaben aufgelöst werden.
  static const Map<int, String> _spelledOut = <int, String>{
    0x00DF: 'ss', // ß
    0x1E9E: 'ss', // ẞ
  };

  /// Entfernt die diakritischen Punkte, für die es keine eigene Zeile in
  /// [_foldTable] gibt (z.B. `é`).
  static const Map<int, int> _stripDiacritic = <int, int>{
    0x00E0: 0x61, 0x00E1: 0x61, 0x00E2: 0x61, 0x00E3: 0x61, 0x00E4: 0x61,
    0x00E5: 0x61, // à á â ã ä å
    0x00E7: 0x63, // ç
    0x00E8: 0x65, 0x00E9: 0x65, 0x00EA: 0x65, 0x00EB: 0x65, // è é ê ë
    0x00EC: 0x69, 0x00ED: 0x69, 0x00EE: 0x69, 0x00EF: 0x69, // ì í î ï
    0x00F1: 0x6E, // ñ
    0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F, 0x00F6: 0x6F, 0x00F8: 0x6F, // ò ó ô õ ö ø
    0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75, 0x00FC: 0x75, // ù ú û ü

    0x0153: 0x6F, 0x0152: 0x6F, 0x00E6: 0x61, // œ, œ, æ
  };

  /// true, wenn [term] im normalisierten Namen ein eigenständiges Wort ist.
  static bool _containsWord(String normalized, String term) {
    if (term.isEmpty) return false;
    int index = normalized.indexOf(term);
    while (index != -1) {
      final bool startsClean =
          index == 0 || !_isLetter(_codeAt(normalized, index - 1));
      final int end = index + term.length;
      final bool endsClean =
          end >= normalized.length || !_isLetter(_codeAt(normalized, end));
      if (startsClean && endsClean) return true;
      index = normalized.indexOf(term, index + 1);
    }
    return false;
  }

  /// true, wenn ein Wort des normalisierten Namens mit [term] *beginnt*.
  ///
  /// Damit werden die deutschen Komposita erfasst: `Scheißkopf` enthält
  /// `Scheiße` nicht als eigenständiges Wort, sondern als Vorsilbe.
  static bool _startsWord(String normalized, String term) {
    if (term.isEmpty) return false;
    int index = normalized.indexOf(term);
    while (index != -1) {
      if (index == 0 || !_isLetter(_codeAt(normalized, index - 1))) {
        return true;
      }
      index = normalized.indexOf(term, index + 1);
    }
    return false;
  }

  static int _codeAt(String value, int index) => value.codeUnitAt(index);

  static bool _isLetter(int code) => code >= 0x61 && code <= 0x7A;

  /// Ersetztabelle für Leet-Schrift. Zeichen, die sie nicht ersetzt, werden
  /// später einfach entfernt – `f-u-c-k` wird also ohnehin zu `fuck`.
  static const Map<int, int> _foldTable = <int, int>{
    0x30: 0x6F, // 0 -> o
    0x31: 0x69, // 1 -> i
    0x33: 0x65, // 3 -> e
    0x34: 0x61, // 4 -> a
    0x35: 0x73, // 5 -> s
    0x37: 0x74, // 7 -> t
    0x38: 0x62, // 8 -> b
    0x40: 0x61, // @ -> a
    0x21: 0x69, // ! -> i
    0x24: 0x73, // $ -> s
    0x26: 0x61, // & -> a
    0x28: 0x63, 0x29: 0x63, // ( ) -> c
    0x3C: 0x63, 0x3E: 0x63, // < > -> c
    0x2B: 0x74, // + -> t
    0x7C: 0x69, // | -> i
  };

  /// Begriffe, die als **eigenständiges Wort** im Namen vorkommen dürfen nicht.
  ///
  /// Wortweise statt als Teilzeichenfolge, damit `Bass` nicht an `ass`
  /// scheitert. Die Stämme (`dumm`, `scheiss`) stehen in [compoundTerms],
  /// weil sie im Deutschen als Vorsilbe weitergehen.
  ///
  /// Enthalten sind Schimpfwörter (deutsch und englisch), Beleidigungen und
  /// menschenfeindliche Bezeichnungen. *Nicht* enthalten sind Wörter, die
  /// heute von den Betroffenen selbst verwendet werden – sie zu blockieren
  /// wäre selbst diskriminierend.
  static const List<String> blockedTerms = <String>[
    // Beleidigungen (deutsch)
    'arschloch', 'dummkopf', 'hurensohn', 'idioten', 'lügner', 'mörder',
    'vergewaltiger', 'verrat',
    // Schimpfwörter (englisch)
    'arse', 'arsehole', 'asshole', 'bastard', 'bitch', 'bollock', 'bollocks',
    'bugger', 'cunt', 'dickhead', 'dildo', 'jackass', 'motherfucker', 'prick',
    'twat', 'wanker', 'whore',
    // Menschenfeindliche Bezeichnungen
    'faggot', 'nigger', 'nigga', 'retarded', 'spastic',
    // Themen, die in einem offenen Suchverzeichnis nichts verloren haben
    'porn', 'porno', 'naked', 'nackt', 'anus', 'anal', 'tits', 'titten',
    'selbstmord', 'suicide',
    // Nur als eigenständiges Wort, nicht als Vorsilbe: `Sexy Teacher` ist
    // gegenüber `sex` die harmlosere und häufigere Schreibweise, und eine
    // Regel, die `Sexophon` oder `Sexy` mitträfe, wäre unbrauchbar.
    'sex', 'slut',
  ];

  /// Begriffe, die den **Anfang eines Wortes** bilden dürfen nicht.
  ///
  /// Nötig wegen der deutschen Komposita: `Scheißkopf`, `Dreckskerl` und
  /// `Fotzenhocker` enthalten das Schimpfwort als Vorsilbe und würden bei
  /// reiner Wortsuche durchrutschen.
  static const List<String> compoundTerms = <String>[
    'arsch', 'dreck', 'dumb', 'dumm', 'fick', 'fotze', 'fuck', 'hure',
    'idiot', 'nazi', 'porn', 'scheiss', 'schlampe', 'spast', 'spasti',
    'vergewaltig', 'wichser',
    // Englische Wortfamilien, die regelmäßig als Vorsilbe auftreten
    'fag', 'paki', 'retard',
  ];

  /// Mehrwortige Kombinationen, die auch dann abgelehnt werden, wenn die
  /// einzelnen Wörter für sich genommen harmlos wären.
  static const List<String> blockedPhrases = <String>[
    'stupid idiot',
    'verdammt idiot',
    'kill yourself',
    'bring dich um',
  ];

  /// Die intern tatsächlich geprüfte Wortliste – [blockedTerms] und
  /// [blockedPhrases] durch dieselbe Normalisierung geschickt, damit ein
  /// Eintrag mit Umlaut (`scheiße`) genauso greift wie seine Schreibweise
  /// ohne (`scheisse`).
  static final List<String> _normalizedWordTerms = <String>[
    ...blockedTerms.map(normalize).where((String term) => term.isNotEmpty),
  ];

  static final List<String> _normalizedCompoundTerms = <String>[
    ...compoundTerms.map(normalize).where((String term) => term.isNotEmpty),
  ];

  static final List<String> _normalizedPhrases = <String>[
    ...blockedPhrases.map(normalize).where((String phrase) => phrase.isNotEmpty),
  ];
}
