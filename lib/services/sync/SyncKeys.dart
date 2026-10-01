import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Welche Bestandteile in einen Sync oder einen Share gehören.
///
/// Getrennt von der eigentlichen Zusammenführung, weil die Auswahl eine
/// Produktentscheidung ist und nicht Teil des Merge-Algorithmus:
/// * **Daten** (Klassen, Personen, Kurse, Pläne) – das ist der Kern, warum
///   man überhaupt synchronisiert.
/// * **Einstellungen** (Sprache, Anzeigeoptionen, Planmodus, …) – optional,
///   weil manche lieber auf dem Handy ihre eigenen Einstellungen behalten.
/// * **Zugangsdaten** – nie. Sie sind geheim, geräteübergreifend nutzbar und
///   gehören nicht in eine Kette, die andere mitlesen könnten.
class SyncKeys {
  const SyncKeys._();

  /// Bestandteile, die immer synchronisiert werden, wenn ein Sync läuft.
  ///
  /// Sind genau die Daten, ohne die ein Sync keinen Sinn hätte: was ist auf
  /// welchem Plan, welche Personen und Kurse gibt es, welche Pläne wurden
  /// bereits gesehen (auch die aus der Vergangenheit).
  ///
  /// ## Warum nicht mehr
  ///
  /// `hiddenSubjectsByClass`, `previewHiddenClasses` und `previewHiddenPersons
  /// sind hier **nicht** enthalten, obwohl sie vorher standen. Sie liegen als
  /// JSON-**Map** in den Einstellungen (`{classId: true}`), nicht als Liste –
  /// `SyncPayload` stellt sich jeden Bestandteil aber als Liste vor. Ein Sync
  /// hätte daraus eine `StringList` geschrieben, während `VPlanAPI` dieselben
  /// Schlüssel mit `getString` liest: derselbe Absturz wie bei `persons`, nur
  /// eine Ebene tiefer und beim Blenden einer Vorschau statt beim Start.
  ///
  /// Bisher hat das nichts ausgelöst, weil der Leser eine Map stillschweigend
  /// als „nichts zu lesen" behandelte. Das war Glück, keine Absicht.
  /// Ausgeschlossene Vorschau- und Ausblende-Einstellungen sind ein
  /// überschaubarer Verlust – ein Absturz beim Start ist es nicht.
  static const List<String> dataKeys = <String>[
    'classes',
    'classNames',
    'persons',
    'initializedClasses',
    'teacherShorts',
    'lessontimes',
    'sickTrack',
    'offlineVPData',
    'cachedRooms',
  ];

  /// In welcher Form die App einen Schlüssel speichert.
  ///
  /// **Die einzige verbindliche Stelle.** Wer hier und in `VPlanAPI`
  /// unterschiedliche Angaben macht, bekommt einen Absturz beim Start – der
  /// Leser in `VPlanAPI` ruft `getString`, der Sync-Leser `getStringList`,
  /// und beide werfen, wenn der andere Typ dort steht.
  ///
  /// Deshalb zwei Regeln, die zusammen gelten:
  ///
  /// 1. Ein Sync **schreibt nie um**. Er schreibt in der Form, die hier steht.
  /// 2. Ein Sync **liest verzeihend**. Er akzeptiert beide Formen und
  ///    repariert eine falsche zurück, statt daran zu scheitern.
  static const Map<String, StoredForm> dataKeyForms = <String, StoredForm>{
    'classes': StoredForm.stringList,
    'offlineVPData': StoredForm.stringList,
    'cachedRooms': StoredForm.stringList,
    'persons': StoredForm.jsonArray,
    'classNames': StoredForm.jsonArray,
    'sickTrack': StoredForm.jsonArray,
    'lessontimes': StoredForm.jsonArray,
    'teacherShorts': StoredForm.jsonArray,
    'initializedClasses': StoredForm.jsonArray,
  };

  /// Die Form von [key] – für einen unbekannten Schlüssel `null`.
  static StoredForm? formOf(String key) => dataKeyForms[_bareKey(key)];

  /// Reine Anzeige- und Verhaltenseinstellungen.
  static const List<String> settingKeys = <String>[
    'hideLessonTimes',
    'hideTeacher',
    'hidePersons',
    'hidePreviewClasses',
    'hidePreviewPersons',
    'defaultPlanModeClass',
    'defaultPlanModePerson',
    'defaultPlanModePreviewClass',
    'defaultPlanModePreviewPerson',
    'materialyou',
  ];

  /// Zugangsdaten. Werden **nie** übertragen – weder im Sync noch im Share.
  static const List<String> credentialKeys = <String>[
    'vplanSchoolnumber',
    'vplanUsername',
    'vplanPassword',
    'customUrl',
  ];

  /// Alles, was in [dataKeys] oder [settingKeys] steht, für eine konkrete
  /// Schule.
  ///
  /// [scopedKey] bildet den Schlüssel einer Schule, wie es `SchoolStorage`
  /// macht: für die Standardschule der nackte Schlüssel, sonst
  /// `schools.<id>.<schlüssel>`.
  static List<String> forSchool(
    String Function(String key) scopedKey, {
    required bool includeSettings,
  }) {
    return <String>[
      for (final String key in dataKeys) scopedKey(key),
      if (includeSettings)
        for (final String key in settingKeys) scopedKey(key),
    ];
  }

  /// Nur die Daten-Schlüssel, inklusive der schulbezogenen [scopedKey].
  static List<String> dataKeysOf(String Function(String key) scopedKey) =>
      dataKeys.map(scopedKey).toList();

  /// Nur die Einstellungs-Schlüssel, inklusive der schulbezogenen
  /// [scopedKey].
  static List<String> settingKeysOf(String Function(String key) scopedKey) =>
      settingKeys.map(scopedKey).toList();

  /// Prüft, ob [key] in [SyncKeys] irgendwo vorkommt – auch als
  /// schulbezogene Variante.
  static bool isSyncable(String key) {
    if (credentialKeys.any(key.contains)) return false;
    if (isCacheKey(key)) return false;
    if (isDeviceLocalKey(key)) return false;
    return dataKeys.any((String k) => key.endsWith(k)) ||
        settingKeys.any((String k) => key.endsWith(k));
  }

  /// true, wenn [key] eine Einstellung ist (und damit vom Nutzer
  /// abschaltbar).
  static bool isSetting(String key) {
    final String bare = _bareKey(key);
    return settingKeys.contains(bare);
  }

  /// true, wenn [key] nur auf diesem Gerät etwas bedeutet.
  ///
  /// Sprache und Material-Design sind bewusst **nicht** in [settingKeys]:
  /// Sie hängen an der Bildschirmgröße und dem Gerät, nicht an der Person.
  /// Wer auf dem Tablet Deutsch und auf dem Handy Englisch liest, soll das
  /// können.
  static bool isDeviceLocalKey(String key) {
    // Sowohl der volle als auch der schulbezogene Schlüssel: `sync.tombstones`
    // enthält Punkte, deshalb wäre `_bareKey` hier 'tombstones'.
    if (key == SyncMergeLocalKeys.tombstones ||
        key.endsWith('.${SyncMergeLocalKeys.tombstones}')) {
      return true;
    }
    final String bare = _bareKey(key);
    return bare == 'languageCode' ||
        bare == 'firstTime' ||
        bare == 'overriddenNow' ||
        bare.startsWith('vplan_cache_');
  }

  /// true für den Kurzzeit-Cache der Pläne.
  static bool isCacheKey(String key) =>
      key.contains('vplan_cache_') ||
      (key.endsWith('_time') && key.contains('vplan_cache'));

  /// `schools.<id>.persons` -> `persons`
  static String _bareKey(String key) {
    final int lastDot = key.lastIndexOf('.');
    if (lastDot == -1) return key;
    final String tail = key.substring(lastDot + 1);
    return tail.isEmpty ? key : tail;
  }
}

/// Wie die App einen Bestandteil in den Einstellungen ablegt.
///
/// Zwei Formen, und die Wahl ist nicht frei: Sie ergibt sich daraus, was
/// `VPlanAPI` mit dem Schlüssel macht, und `VPlanAPI` benutzt typisierte
/// Getter, die bei dem falschen Typ eine `TypeError` **werfen** statt `null`
/// zu liefern. Deshalb steht sie hier ausdrücklich, statt sich aus dem
/// gespeicherten Wert zu erraten.
enum StoredForm {
  /// Als `StringList` – für reine Zeichenketten wie die Pläne.
  stringList,

  /// Als `String` mit einem JSON-**Array** darin – für Einträge, die Objekte
  /// sind (`persons`, `sickTrack`, …). `setStringList` nimmt keine Objekte
  /// auf, deshalb ist das die einzig mögliche Form.
  jsonArray,
}

/// Die eine Regel, wie aus den Zeilen eines Bestandteils der gespeicherte
/// Wert wird.
///
/// Sie wird an drei Stellen gebraucht – dem Schreiber des Merge, dem Leser und
/// dem Reparierer – und die drei dürfen sich nicht unterscheiden. Jeder von
/// ihnen baut daraus sonst eine andere Zeichenkette, und die Form kippt
/// zwischen zwei Läufen hin und her.
///
/// Wichtig: Die App legt ein Array von **Objekten** ab
/// (`jsonEncode(persons)` in `VPlanAPI`), nicht ein Array von
/// JSON-Zeichenketten. Beides ist ein gültiges JSON-Array und sieht auf den
/// ersten Blick gleich aus – aber `jsonDecode` liefert beim einen
/// `List<Map>`, beim anderen `List<String>`, und die zweite Varienz kann die
/// App nicht verwenden.
String encodeJsonArray(List<String> lines) {
  return jsonEncode(<Object>[
    for (final String line in lines) _decodeLine(line),
  ]);
}

/// Dekodiert eine Zeile zu einem Objekt – sonst bleibt sie, wie sie ist.
Object _decodeLine(String line) {
  try {
    final Object? decoded = jsonDecode(line);
    if (decoded is Map) return decoded;
  } catch (_) {}
  return line;
}

/// Repariert einen Schlüssel auf die Form, die die App erwartet.
///
/// Ein Sync, der einen Schlüssel in der falschen Form zurückschreibt, macht
/// die App beim nächsten Start **unbenutzbar**: `main()` wirft, `runApp` wird
/// nie erreicht, und die App startet nie wieder. Genau das ist geschehen –
/// der Sync hatte `persons` als `StringList` geschrieben, während
/// `VPlanAPI.loadDisplayCache` sie mit `getString` liest.
///
/// Deshalb liest [SyncDataReader.readLines] nicht nur verzeihend, sondern
/// **repariert**: Findet es einen Schlüssel in der falschen Form, schreibt es
/// ihn einmalig in die richtige um. Der erste Start danach ist der langsame,
/// danach ist die Form stabil – und zwar ohne, dass jemand die App
/// neu installieren muss.
class StorageHealer {
  const StorageHealer._();

  /// Repariert alle [keys], die in [SyncKeys.dataKeyForms] stehen.
  ///
  /// Ein Durchgang beim Start, aus zwei Gründen:
  ///
  /// * Ein Gerät, das eine frühere App-Version beschädigt hat, ist sonst
  ///   **dauerhaft** tot – der Schlüssel steht ja weiterhin falsch da, und der
  ///   Aufruf, der daran scheitert, ist bei `main()` einer vor `runApp`.
  /// * Ein einmaliger Durchgang ist billig: Die Form ist danach stabil, und
  ///   spätere Läufe finden nichts zu tun.
  ///
  /// Gibt die Zahl der reparierten Schlüssel zurück – für eine Meldung im Log,
  ///   weil ein stiller Reparaturvorgang schwer zu finden ist.
  static Future<int> healAll(
    SharedPreferences prefs, [
    List<String> keys = SyncKeys.dataKeys,
  ]) async {
    int repaired = 0;
    for (final String key in keys) {
      if (await heal(prefs, key)) repaired++;
    }
    return repaired;
  }

  /// Stellt [key] auf die in [SyncKeys.dataKeyForms] angegebene Form um.
  ///
  /// Gibt true zurück, wenn etwas repariert wurde.
  static Future<bool> heal(SharedPreferences prefs, String key) async {
    final StoredForm? wanted = SyncKeys.formOf(key);
    if (wanted == null) return false;

    // Was liegt tatsächlich dort? Beide typisierten Getter werfen, wenn der
    // Typ nicht passt – deshalb einzeln und im try/catch.
    List<String>? raw;
    try {
      raw = prefs.getStringList(key);
    } catch (_) {
      raw = null;
    }
    String? asString;
    try {
      asString = prefs.getString(key);
    } catch (_) {
      asString = null;
    }

    if (wanted == StoredForm.jsonArray && asString != null && asString.isNotEmpty) {
      return false; // passt bereits
    }
    if (wanted == StoredForm.stringList && raw != null) {
      return false; // passt bereits
    }

    // Die falsche Form: aus der einen in die andere überführen.
    final List<String> lines = raw ?? const <String>[];
    if (wanted == StoredForm.jsonArray) {
      if (lines.isEmpty) return false;
      await prefs.setString(key, encodeJsonArray(lines));
      return true;
    }
    if (asString == null || asString.isEmpty) return false;
    try {
      final Object? decoded = jsonDecode(asString);
      if (decoded is! List) return false;
      await prefs.setStringList(
        key,
        decoded.map((Object? e) => e is String ? e : jsonEncode(e)).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Lokale Schlüssel des Sync-Selbstverwaltung – nie übertragen.
class SyncMergeLocalKeys {
  const SyncMergeLocalKeys._();

  /// Lösch-Markierungen (siehe `SyncMerge.tombstoneStorageKey`).
  static const String tombstones = 'sync.tombstones';
}

/// Liest die aktuell gespeicherten Daten für einen Sync/Share zusammen.
///
/// Anders als `ConfigBackup` (das *alle* Schlüssel exportiert) wird hier
/// bewusst nur ausgewählt, was in eine Kette oder einen Share gehört.
class SyncDataReader {
  const SyncDataReader._();

  /// Liest alle synchronisierbaren Bestandteile für [keys].
  ///
  /// Listen werden als `StringList` erwartet (so speichert die App sie) und
  /// Zeile für Zeile dekodiert. Beschädigte Zeilen werden übersprungen: Ein
  /// einzelner kaputter Eintrag darf einen Sync nicht verhindern, aber er
  /// darf auch nicht überschrieben werden – er fliegt einfach nicht mit.
  static Future<Map<String, List<Map<String, dynamic>>>> readParts(
    SharedPreferences prefs,
    List<String> keys,
  ) async {
    final Map<String, List<Map<String, dynamic>>> parts =
        <String, List<Map<String, dynamic>>>{};
    for (final String key in keys) {
      final List<String> raw = _stringList(prefs, key);
      if (raw.isEmpty) continue;
      final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
      for (final String entry in raw) {
        final Map<String, dynamic>? decoded = _decode(entry);
        if (decoded == null) continue;
        items.add(decoded);
      }
      if (items.isEmpty) continue;
      parts[key] = items;
    }
    return parts;
  }

  /// Liest die einfachen Einstellungen für [keys].
  static Future<Map<String, dynamic>> readSettings(
    SharedPreferences prefs,
    List<String> keys,
  ) async {
    final Map<String, dynamic> settings = <String, dynamic>{};
    for (final String key in keys) {
      final Object? value = _rawValue(prefs, key);
      if (value == null) continue;
      settings[key] = value is List ? value.map((Object? e) => e.toString()).toList() : value;
    }
    return settings;
  }

  /// Zählt, wie viele Einträge ein Sync von [key] übertragen würde.
  ///
  /// Bewusst über [_stringList] und nicht über `prefs.getStringList`: Die App
  /// speichert die Hälfte dieser Schlüssel als **JSON-Zeichenkette**, nicht als
  /// Liste – `persons`, `classNames`, `sickTrack`, `lessontimes` und
  /// `teacherShorts` etwa. `getStringList` wirft daraufhin einen TypeError, und
  /// der ganze Bildschirm stirbt an einer Zahl, die nur eine Anzeige tragen
  /// soll. Ein Aufruf von `getStringList` über `dataKeys` ist deshalb ein
  /// Fehler – auch in einer Kachel.
  ///
  /// Gezählt werden nur die Zeilen, die auch wirklich als Objekt lesbar sind.
  /// Sonst würde die Anzeige eine Zahl nennen, die der Sync nicht liefert.
  static int countItems(SharedPreferences prefs, String key) {
    int count = 0;
    for (final String entry in _stringList(prefs, key)) {
      if (_decode(entry) != null) count++;
    }
    return count;
  }

  /// Die Summe über mehrere [keys] – die Zahl, die die Oberfläche anzeigt.
  static int countItemsOf(SharedPreferences prefs, List<String> keys) {
    int total = 0;
    for (final String key in keys) {
      total += countItems(prefs, key);
    }
    return total;
  }

  /// Die verfügbaren Personen- und Klassen-Namen für die Oberfläche.
  static List<String> readClassNames(SharedPreferences prefs) {
    final List<String> raw = _stringList(prefs, 'classes');
    return raw
        .map(_decode)
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => item['name']?.toString() ?? '')
        .where((String name) => name.isNotEmpty)
        .toList();
  }

  /// Liest einen Schlüssel als Liste von JSON-Zeichenketten.
  ///
  /// Die App speichert ihre Bestandteile auf **zwei** Arten, und der Leser
  /// muss beide bedienen:
  ///
  /// * als `StringList` – so liegen die Pläne (`offlineVPData`) und einige
  ///   Auswahllisten vor,
  /// * als `String` mit einem JSON-Array darin – so liegen `persons`,
  ///   `classes`, `classNames` und `sickTrack` vor, weil sie Objekte
  ///   enthalten und `setStringList` keine aufnehmen würde.
  ///
  /// Deshalb wird der zweite Weg **immer** versucht, wenn der erste scheitert.
  /// Ein `return` im `catch` – so stand es hier früher – hat sämtliche
  /// JSON-gespeicherten Bestandteile übersprungen: `persons`, `classes`,
  /// `classNames`, `sickTrack`, `lessontimes` und `teacherShorts` waren für
  /// den Sync unsichtbar, ohne jeden Fehler. Ein Sync übertrug damit nur noch
  /// die Pläne und meldete trotzdem Erfolg.
  /// Die rohen Zeilen eines Bestandteils, unabhängig davon, ob er als
  /// `StringList` oder als JSON-Zeichenkette gespeichert ist.
  ///
  /// Öffentlich, weil dieselbe Frage an mehreren Stellen gestellt wird – und
  /// weil jede Stelle, die stattdessen `prefs.getStringList` aufruft, bei der
  /// Hälfte der Daten-Schlüssel abstürzt.
  static List<String> readLines(SharedPreferences prefs, String key) =>
      _stringList(prefs, key);

  static List<String> _stringList(SharedPreferences prefs, String key) {
    try {
      final List<String>? value = prefs.getStringList(key);
      if (value != null) {
        // Steht hier eine Liste, obwohl die App eine JSON-Zeichenkette
        // erwartet, ist das der Zustand, an dem die App beim Start stirbt.
        // Der Wert wird zurückgegeben – und im Hintergrund repariert.
        if (SyncKeys.formOf(key) == StoredForm.jsonArray) {
          StorageHealer.heal(prefs, key);
        }
        return value;
      }
    } catch (_) {
      // Unter diesem Schlüssel liegt ein Wert eines anderen Typs.
      // `SharedPreferences` wirft dafür eine TypeError, statt `null` zu
      // liefern. **Weitergehen ist hier zwingend**: Der Wert ist vorhanden,
      // nur nicht als Liste – typischerweise als JSON-Zeichenkette.
    }
    // Auch `getString` wirft, statt `null` zu liefern, wenn unter dem
    // Schlüssel etwas anderes liegt – ein Boolean etwa. Das ist keine
    // Ausnahme, sondern der Normalfall bei den Einstellungs-Schlüsseln, die
    // `dataKeys` absichtlich *nicht* enthält, aber mit denen derselbe Aufruf
    // rechnen muss.
    String? raw;
    try {
      raw = prefs.getString(key);
    } catch (_) {
      return const <String>[];
    }
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        // Jedes Element muss am Ende eine **JSON-Zeichenkette** sein, weil
        // [_decode] genau das erwartet. Ein Objekt aus dieser Liste mit
        // `toString()` zu nehmen ergibt `{id: 1, name: Hans}` – das ist
        // kein JSON, `jsonDecode` scheitert daran, und der Eintrag fällt
        // kommentarlos heraus. Auch das ist hier einmal passiert.
        return decoded
            .map((Object? e) => e is String
                ? e
                : (e is Map ? jsonEncode(e) : e.toString()))
            .toList();
      }
    } catch (_) {
      // Kein JSON – dann eben nichts lesen.
    }
    return const <String>[];
  }

  static Map<String, dynamic>? _decode(String entry) {
    try {
      final Object? decoded = jsonDecode(entry);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Liest einen Wert unabhängig von seinem Typ.
  static Object? _rawValue(SharedPreferences prefs, String key) {
    for (final Object? Function() read in <Object? Function()>[
      () => prefs.getString(key),
      () => prefs.getBool(key),
      () => prefs.getInt(key),
      () => prefs.getDouble(key),
      () => prefs.getStringList(key),
    ]) {
      try {
        final Object? value = read();
        if (value != null) return value;
      } catch (_) {
        // Typ passt nicht – nächsten probieren.
      }
    }
    return null;
  }
}
