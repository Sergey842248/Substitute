/// Die Reihenfolge der Klassennamen.
///
/// Klassen heißen `06.2`, `11`, `8a` – und genau darin liegt der Grund für
/// eine eigene Ordnung. Ein reiner Zeichenkettenvergleich ergibt
/// `06.2, 08.1, 10, 11, 8a`: `10` und `11` stehen **vor** `8a`, weil `'1'`
/// kleiner ist als `'8'`. Für Menschen ist das falsch, und eine Klassenliste
/// ist genau der Ort, an dem Menschen hinschauen.
///
/// Die Ordnung ist deshalb **natürlich**: Zahlen werden als Zahlen verglichen,
/// nicht als Ziffernfolgen. Also `06.2` vor `11`, und `8a` vor `10`.
///
/// ## Warum sie im Sync und in der App dieselbe ist
///
/// Beide Stellen benutzen [compare], nicht jeweils ihr eigenes Verfahren. Sonst
/// hätte das Gerät, das die Liste zuletzt angefasst hat, eine andere Ordnung
/// als das andere – und die Kette käme nie zur Ruhe. Ein Sortiervorgang, der
/// am Schreibort ein bisschen anders arbeitet als am Leserort, ist die
/// zuverlässigste Art, Daten über die Zeit hinweg zu verderben.
class ClassNames {
  const ClassNames._();

  /// Vergleicht zwei Klassennamen für die Anzeige.
  ///
  /// Ziffernfolgen zählen als Zahlen, alles andere wird ohne Rücksicht auf
  /// Groß- und Kleinschreibung verglichen. Bei Gleichstand entscheidet die
  /// Schreibweise, damit der Vergleich **immer** eine Entscheidung trifft und
  /// nie von der Eingangsreihenfolge abhängt.
  static int compare(String a, String b) {
    final List<String> teileA = _zerlegen(a);
    final List<String> teileB = _zerlegen(b);
    final int n = teileA.length < teileB.length ? teileA.length : teileB.length;
    for (int i = 0; i < n; i++) {
      final int c = _vergleicheTeil(teileA[i], teileB[i]);
      if (c != 0) return c;
    }
    final int laenge = teileA.length.compareTo(teileB.length);
    if (laenge != 0) return laenge;
    // Gleiche Zerlegung: Wer gleich ist, entscheidet die Schreibweise. Ohne
    // das hinge die Reihenfolge von der Eingangsreihenfolge ab, und zwei
    // Geräte könnten sich nicht einigen.
    return a.compareTo(b);
  }

  /// Die Liste in der richtigen Reihenfolge – eine neue Liste, das Original
  /// bleibt unangetastet.
  static List<String> sortiert(List<String> namen) {
    final List<String> kopie = List<String>.of(namen);
    kopie.sort(compare);
    return kopie;
  }

  /// Zerlegt einen Namen in Ziffernfolgen und den Rest dazwischen.
  ///
  /// `06.2` wird zu `['06', '.', '2']`, `8a` zu `['8', 'a']`. Punkt und
  /// Bindestrich bleiben stehen, damit `6.2` nicht wie `62` behandelt wird.
  static List<String> _zerlegen(String name) {
    final List<String> teile = <String>[];
    final StringBuffer puffer = StringBuffer();
    bool istZiffer = false;
    for (final int rune in name.runes) {
      final bool ziffer = _istZiffer(rune);
      if (ziffer != istZiffer && puffer.isNotEmpty) {
        teile.add(puffer.toString());
        puffer.clear();
      }
      istZiffer = ziffer;
      puffer.writeCharCode(rune);
    }
    if (puffer.isNotEmpty) teile.add(puffer.toString());
    return teile;
  }

  static bool _istZiffer(int rune) => rune >= 0x30 && rune <= 0x39;

  /// Vergleicht zwei Teile: Ziffernfolgen als Zahlen, sonst als Text.
  static int _vergleicheTeil(String a, String b) {
    final bool aZiffern = a.isNotEmpty && _istZiffer(a.runes.first);
    final bool bZiffern = b.isNotEmpty && _istZiffer(b.runes.first);
    if (aZiffern && bZiffern) {
      // Führende Nullen allein bringen nichts: `06` und `6` sind dieselbe
      // Zahl, und die Anordnung soll davon nicht abhängen. Erst der Vergleich
      // der Länge entscheidet die Zahl, dann der Text – deshalb `06` vor `6a`
      // und `6` vor `06a`, was zugleich der menschlichen Erwartung entspricht.
      final int? na = int.tryParse(a);
      final int? nb = int.tryParse(b);
      if (na != null && nb != null) {
        final int c = na.compareTo(nb);
        if (c != 0) return c;
        return a.compareTo(b);
      }
    }
    if (aZiffern != bZiffern) {
      // Eine Zahl vor einem Text: `8` vor `8a` ist dabei unerheblich, aber
      // `10` vor `Oberstufe` ist die Lesart, die jemand erwartet.
      return aZiffern ? -1 : 1;
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}
