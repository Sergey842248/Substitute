import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/ClassNames.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Bringt die Listen in die Ordnung, die die App inzwischen erwartet.
///
/// ## Wofür das da ist
///
/// Das Update, in dem die Klassen sortiert abgelegt werden, erreicht nicht die
/// Listen, die schon da waren. Sie stammen aus einer Zeit, in der die Reihenfolge
/// der Eingabe folgte – wer `11` vor `06.2` angelegt hatte, hatte danach
/// `11, 06.2`.
///
/// Am Anlegen und Entfernen einer Klasse zu sortieren reicht nicht: Wer die App
/// updated und **nicht** synchronisiert, behält die alte Reihenfolge für immer.
/// Und sie ist nicht nur eine Anzeige – das Krankentracking, die Auswertung und
/// das Teilen lesen dieselbe Liste roh.
///
/// ## Warum über alle Schulen
///
/// Die Listen liegen pro Schule. Wer nur die gerade aktive repariert, lässt die
/// anderen stehen, und sie tauchen wieder auf, sobald jemand umschaltet.
///
/// ## Warum ohne Versionsmerkmal
///
/// Der Durchgang prüft vor dem Schreiben, ob überhaupt etwas zu tun ist. Bei
/// bereits richtigen Listen passiert nichts – kein Schreiben, kein Merkmal, kein
/// Aufwand. Damit heilt er sich selbst, statt nach einem Update nur einmal zu
/// laufen und bei der nächsten neuen Schule wieder zu vergessen. Und wenn ein
/// Fehler eingebaut wird, der wieder etwas verschiebt, ist der Durchgang die
/// Ausheilung, ohne dass jemand daran denken muss.
///
/// Die Reihenfolge ist dieselbe wie überall sonst: [ClassNames] für die
/// Klassen, Datum für die Pläne. Das ist derselbe Aufruf, den der Sync macht
/// (`SyncMerge.canonicalOrder`) – zwei Regeln an zwei Stellen wären die
/// zuverlässigste Art, sie über die Zeit auseinanderlaufen zu lassen.
class ListOrderRepair {
  const ListOrderRepair._();

  /// Die Klassenliste: die Reihenfolge berechnen, den Namen folgend.
  static const String classList = 'classes';

  /// Der Plan-Cache: nach Datum, weil die App darin nach Datum sucht.
  static const String planList = 'offlineVPData';

  /// Repariert die Listen aller Schulen. Gibt die Zahl der geschriebenen
  /// Listen zurück – für eine Meldung, weil ein stiller Reparaturvorgang
  /// schwer zu finden ist.
  static Future<int> repairAll(SharedPreferences prefs) async {
    int repaired = 0;
    for (final String schoolId in SchoolStorage.allSchoolIds(prefs)) {
      if (await repairClassList(prefs, schoolId)) repaired++;
      if (await repairPlanList(prefs, schoolId)) repaired++;
    }
    return repaired;
  }

  /// Repariert die Klassen einer Schule. true, wenn geschrieben wurde.
  static Future<bool> repairClassList(
    SharedPreferences prefs,
    String schoolId,
  ) async {
    final String key = SchoolStorage.keyForSchool(schoolId, classList);
    // Über den Sync-Leser, nicht über `getStringList`: Die Klassen können auch
    // als JSON-Zeichenkette abgelegt sein, und `getStringList` wirft daraufhin
    // einen TypeError. Genau daran ist der Start der App einmal gescheitert.
    final List<Object> items = SyncDataReader.readItems(prefs, key);
    if (items.isEmpty) return false;

    final List<String> namen = <String>[
      for (final Object item in items) item.toString(),
    ];
    final List<String> geordnet = ClassNames.sortiert(namen);
    if (_gleich(namen, geordnet)) return false;

    // Die Form bleibt, in der sie war: `classes` wird als `StringList`
    // abgelegt. Ein Umschreiben als JSON-Zeichenkette wäre der direkte Weg in
    // den Absturz beim Start.
    await prefs.setStringList(key, geordnet);
    return true;
  }

  /// Repariert den Plancache einer Schule. true, wenn geschrieben wurde.
  static Future<bool> repairPlanList(
    SharedPreferences prefs,
    String schoolId,
  ) async {
    final String key = SchoolStorage.keyForSchool(schoolId, planList);
    final List<String> zeilen = SyncDataReader.readLines(prefs, key);
    if (zeilen.length < 2) return false;

    final SyncPart part = SyncPayload.describePart(planList, SyncDataReader.readItems(prefs, key));
    final List<String> ids = part.identityOrder;
    final List<String> geordnet = List<String>.of(ids)..sort();
    if (_gleich(ids, geordnet)) return false;

    // Die Pläne selbst bleiben unangetastet – es wird nur die Reihenfolge der
    // Zeilen verändert, und die Zeilen sind unveränderte JSON-Objekte.
    final Map<String, String> nachId = <String, String>{
      for (int i = 0; i < part.items.length; i++)
        ids[i]: zeilen[i],
    };
    await prefs.setStringList(
      key,
      <String>[for (final String id in geordnet) nachId[id]!],
    );
    return true;
  }

  static bool _gleich(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
