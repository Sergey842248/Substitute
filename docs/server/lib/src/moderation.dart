/// Server-seitige Prüfung von Anzeigenamen.
///
/// Die App prüft Namen mit `NameGuard` bereits vor dem Speichern. Das ist aber
/// nur die erste Instanz: Eine Prüfung, die ausschließlich auf dem Gerät
/// läuft, lässt sich umgehen – jeder kann die HTTP-Schnittstelle direkt
/// ansprechen. Deshalb prüft der Server dieselben Regeln noch einmal.
///
/// Die Liste liegt hier bewusst ein zweites Mal vor: Der Server darf das
/// App-Paket nicht als Abhängigkeit einbinden, und eine gemeinsame Datei müsste
/// zur Laufzeit aus einem Verzeichnis gelesen werden, das auf einem
/// gehärteten Server nicht verlässlich vorhanden ist. Beide Listen sind durch
/// Tests abgedeckt; die des Servers ist der kürzere, grobe Sicherheitsnetz,
/// die der App ist die vollständige.
library;

/// Warum ein Name abgelehnt wurde.
enum NameProblem {
  /// Leer oder nur aus Leerzeichen.
  empty,

  /// Kürzer als zwei Zeichen.
  tooShort,

  /// Länger als 40 Zeichen.
  tooLong,

  /// Enthält unerlaubte Zeichen (Steuerzeichen, HTML/Sonderzeichen).
  invalidCharacters,

  /// Enthält ein blockiertes Wort.
  blocked,
}

class NameCheck {
  const NameCheck._(this.problem, this.term);

  const NameCheck.ok()
      : problem = null,
        term = null;

  final NameProblem? problem;
  final String? term;

  bool get isOk => problem == null;
}

class Moderation {
  const Moderation._();

  static const int minimumLength = 2;
  static const int maximumLength = 40;

  /// Prüft einen Anzeigenamen, wie er im Suchverzeichnis steht.
  static NameCheck checkDisplayName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return const NameCheck._(NameProblem.empty, null);
    if (trimmed.length < minimumLength) {
      return const NameCheck._(NameProblem.tooShort, null);
    }
    if (trimmed.length > maximumLength) {
      return const NameCheck._(NameProblem.tooLong, null);
    }
    // Im Verzeichnis wird nur Text angezeigt, kein Markup: erlaubt sind
    // Buchstaben (inklusive Umlauten), Ziffern, Leerzeichen und ein paar
    // übliche Satzzeichen.
    if (!RegExp(r"^[\p{L}\p{N} .'\-]+$", unicode: true).hasMatch(trimmed)) {
      return const NameCheck._(NameProblem.invalidCharacters, null);
    }

    final String normalized = normalize(trimmed);
    for (final String term in blockedTerms) {
      if (_containsWord(normalized, normalize(term))) {
        return NameCheck._(NameProblem.blocked, term);
      }
    }
    for (final String term in compoundTerms) {
      if (_startsWord(normalized, normalize(term))) {
        return NameCheck._(NameProblem.blocked, term);
      }
    }
    return const NameCheck.ok();
  }

  /// Bringt einen Namen in die Form, in der verglichen wird – identisch zum
  /// `NameGuard` der App: Kleinschreibung, Diakritika weg, Leet-Schrift
  /// zurückgeführt, alles andere entfernt, Dehnungen zusammengezogen.
  static String normalize(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.toLowerCase().runes) {
      final String? spelled = _spelledOut[rune];
      if (spelled != null) {
        // `ß` ist ein einzelner Rune, aber zwei Konsonten wert.
        buffer.write(spelled);
        continue;
      }
      // Zeichen ohne Ersatzeintrag bleiben unverändert stehen; was danach
      // keine Kleinbuchstabe ist, fällt am Ende der Normalisierung weg.
      buffer.writeCharCode(_foldTable[rune] ?? _diacritics[rune] ?? rune);
    }
    final String collapsed =
        buffer.toString().replaceAllMapped(RegExp(r'(.)\1{2,}'), (Match m) => '${m.group(1)}${m.group(1)}');
    return collapsed.replaceAll(RegExp('[^a-z]'), '');
  }

  /// true, wenn ein Wort des normalisierten Namens mit [term] beginnt –
  /// für die deutschen Komposita (`Scheißkopf` = `Scheiße` + `kopf`).
  static bool _startsWord(String normalized, String term) {
    if (term.isEmpty) return false;
    int index = normalized.indexOf(term);
    while (index != -1) {
      if (index == 0 || !_isLetter(normalized.codeUnitAt(index - 1))) return true;
      index = normalized.indexOf(term, index + 1);
    }
    return false;
  }

  static bool _containsWord(String normalized, String term) {
    if (term.isEmpty) return false;
    int index = normalized.indexOf(term);
    while (index != -1) {
      final bool left = index == 0 || !_isLetter(normalized.codeUnitAt(index - 1));
      final int end = index + term.length;
      final bool right = end >= normalized.length || !_isLetter(normalized.codeUnitAt(end));
      if (left && right) return true;
      index = normalized.indexOf(term, index + 1);
    }
    return false;
  }

  static bool _isLetter(int code) => code >= 0x61 && code <= 0x7A;

  /// Zeichen, die zu mehreren Buchstaben aufgelöst werden.
  static const Map<int, String> _spelledOut = <int, String>{
    0x00DF: 'ss', 0x1E9E: 'ss',
  };

  static const Map<int, int> _foldTable = <int, int>{
    0x30: 0x6F, 0x31: 0x69, 0x33: 0x65, 0x34: 0x61, 0x35: 0x73,
    0x37: 0x74, 0x38: 0x62, 0x40: 0x61, 0x21: 0x69, 0x24: 0x73,
    0x26: 0x61, 0x28: 0x63, 0x29: 0x63, 0x3C: 0x63, 0x3E: 0x63,
    0x2B: 0x74, 0x7C: 0x69,
  };

  static const Map<int, int> _diacritics = <int, int>{
    0x00E0: 0x61, 0x00E1: 0x61, 0x00E2: 0x61, 0x00E3: 0x61, 0x00E4: 0x61,
    0x00E5: 0x61, 0x00E7: 0x63, 0x00E8: 0x65, 0x00E9: 0x65, 0x00EA: 0x65,
    0x00EB: 0x65, 0x00EC: 0x69, 0x00ED: 0x69, 0x00EE: 0x69, 0x00EF: 0x69,
    0x00F1: 0x6E, 0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F, 0x00F6: 0x6F,
    0x00F8: 0x6F, 0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75, 0x00FC: 0x75,
    0x0152: 0x6F, 0x0153: 0x6F, 0x00E6: 0x61,
  };

  /// Grobes Netz gegen die häufigsten Beleidigungen und menschenfeindlichen
  /// Bezeichnungen. Die vollständige Liste steht in der App
  /// (`NameGuard`); dieser Server ist nur die zweite Instanz.
  static const List<String> blockedTerms = <String>[
    'arschloch', 'dummkopf', 'hurensohn', 'idioten', 'mörder', 'verrat',
    'vergewaltiger', 'arse', 'arsehole', 'asshole', 'bastard', 'bitch',
    'bollock', 'bollocks', 'bugger', 'cunt', 'dickhead', 'dildo', 'jackass',
    'motherfucker', 'prick', 'slut', 'twat', 'whore', 'faggot', 'nigger',
    'nigga', 'retarded', 'spastic', 'porn', 'porno', 'naked', 'nackt', 'anus',
    'anal', 'tits', 'selbstmord', 'suicide', 'sex',   ];

  /// Wortstämme, die als Vorsilbe eines Kompositums auftreten können.
  static const List<String> compoundTerms = <String>[
    'arsch', 'dreck', 'dumb', 'dumm', 'fick', 'fuck', 'fotze', 'hure',
    'idiot', 'nazi', 'porn', 'scheiss', 'schlampe', 'spast', 'spasti',
    'vergewaltig', 'wichser',
    'fag', 'paki', 'retard',
  ];
}
