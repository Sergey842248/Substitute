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
/// Wie ein Schlüssel übertragen wird.
///
/// [items] wird einzeln zusammengeführt, mit Lösch-Markierungen – richtig für
/// alles, was einzeln angelegt, geändert oder gelöscht wird (Klassen,
/// Personen, Pläne). [value] wird **als Ganzes** übernommen, der mit der
/// neueren Änderungszeit gewinnt – richtig für alles, was man als Ganzes setzt
/// (ein Schalter, eine Karte von Vorschau-Ausnahmen).
enum SyncKeyKind {
  items,
  value,
  excluded,
}

class SyncKeys {
  const SyncKeys._();

  /// Die Schlüssel, die als **Array** gespeichert werden und deshalb einzeln
  /// zusammengeführt werden – mit Identität je Eintrag und Lösch-Markierungen.
  ///
  /// Richtig für alles, was einzeln angelegt, geändert oder gelöscht wird: die
  /// Klassen, die Personen, die Pläne, das Krankentracking, die Kürzel und die
  /// Zeiten.
  ///
  /// **Diese Liste ist die einzige handgepflegte im Sync**, und sie muss es
  /// sein: Sie sagt zugleich, in welcher Form die App ablegt ([dataKeyForms]),
  /// und das lässt sich nicht am Typ erkennen – `classes` und `persons` sind
  /// beide Arrays, liegen aber verschieden ab.
  ///
  /// Alles, was **kein** Array ist, braucht hier nichts: Es wird als Wert
  /// übertragen ([classify]) und die Form folgt aus dem Typ. Das war der
  /// eigentliche Zweck des Umbaus – vorher stand in `settingKeys` eine
  /// handgepflegte Positivliste, die nicht vollständig bleiben konnte, und
  /// deshalb kamen `languageCode`, `newsfeeds` und sämtliche
  /// Plan-Einstellungen nie an.
  static const List<String> itemKeys = <String>[
    'classes',
    'persons',
    'offlineVPData',
    'sickTrack',
    'teacherShorts',
    'lessontimes',
    'cachedRooms',
  ];

  /// Die Daten-Schlüssel, die als **Karte** gespeichert werden:
  /// `classNames` (Favoriten-Klassen mit benutzerdefiniertem Namen),
  /// `initializedClasses`, `hiddenSubjectsByClass`, `previewHiddenClasses`,
  /// `previewHiddenPersons`.
  ///
  /// Sie werden als Wert übertragen und **einzeln je Eintrag** zusammengeführt.
  ///
  /// `classNames` stand früher in [itemKeys] – als wäre es ein Array. Es ist
  /// eine Karte `{classId: eigenerName}` (`VPlanAPI._decodeClassNames`), und
  /// wurde deshalb nie gelesen: `SyncPayload` stellte sich jeden Bestandteil
  /// als Liste vor, und eine Karte ist keine Liste.
  static const List<String> mapKeys = <String>[
    'classNames',
    'initializedClasses',
    'hiddenSubjectsByClass',
    'previewHiddenClasses',
    'previewHiddenPersons',
  ];

  /// Die vollständige Liste der Schlüssel, die die App für Daten hält.
  ///
  /// Von [classify] und der Anzeige benutzt. [itemKeys] allein genügt nicht,
  /// weil die Karten dazukommen – sie sind übertragbar, aber keine Arrays.
  static const List<String> dataKeys = <String>[
    'classes',
    'classNames',
    'persons',
    'hiddenSubjectsByClass',
    'initializedClasses',
    'teacherShorts',
    'lessontimes',
    'sickTrack',
    'offlineVPData',
    'cachedRooms',
    'previewHiddenClasses',
    'previewHiddenPersons',
  ];

  /// Die Schlüssel, die **nie** in eine Kette oder einen Share gehen.
  ///
  /// Bewusst als kurze **Sperrliste** und nicht als Positivliste. Eine
  /// Positivliste muss vollständig sein, und das ist sie nicht: Jede neue
  /// Einstellung, die jemand hinzufügt, wäre in ihr nicht enthalten und würde
  /// ohne jedes Zeichen stillschweigend nicht synchronisiert. Eine Sperrliste
  /// ist nur dann gefährlich, wenn jemand etwas Neues hinzufügt, das nicht in
  /// sie gehört – und dafür stehen hier die eigentlichen Geheimnisse.
  ///
  /// Der Fehler einer zu großen Positivliste (ein vergessenes Geheimnis) ist
  /// außerdem viel teurer als der einer zu kleinen Sperrliste (eine Einstellung
  /// wandert nicht mit). Diese Asymmetrie entscheidet die Ausrichtung.
  static const List<String> neverSync = <String>[
    // Zugangsdaten. Sie sind geräteübergreifend nutzbar und gehören nicht in
    // eine Kette, die andere mitlesen könnten.
    'vplanSchoolnumber',
    'vplanUsername',
    'vplanPassword',
    'customUrl',

    // Der Sync selbst. Sonst überschreiben sich zwei Geräte gegenseitig ihre
    // eigene Kette – und ein Gerät, das den Zustand eines anderen übernimmt,
    // gehört plötzlich zu dessen Kette.
    'sync.state',
    'sync.serverUrl',
    'sync.tombstones',
    'sync.settingsTimestamps',
    'sync.shadowedValues',

    // Der Einstieg in die App und der Schulwechsel.
    'firstTime',
    'activeSchoolId',
    'schoolProfiles',

    // Nur dieses Gerät: eine Developer-Zeitüberschreibung ist per Definition
    // lokal, und sie zu übertragen hieße, die Zeit auf einem anderen Gerät
    // zu verfälschen.
    'overriddenNow',
  ];

  /// In welcher Form die App einen [itemKeys]-Schlüssel speichert.
  ///
  /// **Die einzige handgepflegte Formangabe im Sync.** Sie ist nötig, weil
  /// `VPlanAPI` mit typisierten Gettern liest, die bei falschem Typ eine
  /// `TypeError` **werfen** statt `null` zu liefern – ein Sync, der die Form
  /// vertauscht, macht die App beim nächsten Start unbenutzbar.
  ///
  /// Für alle übrigen Schlüssel gilt: Karten werden als JSON-Zeichenkette
  /// abgelegt, einfache Werte mit ihrem nativen Setter. Das folgt aus dem
  /// Typ und muss nicht mehr nachgetragen werden.
  static const Map<String, StoredForm> dataKeyForms = <String, StoredForm>{
    'classes': StoredForm.stringList,
    'offlineVPData': StoredForm.stringList,
    'cachedRooms': StoredForm.stringList,
    'persons': StoredForm.jsonArray,
    'sickTrack': StoredForm.jsonArray,
    'teacherShorts': StoredForm.jsonArray,
    'lessontimes': StoredForm.jsonArray,
  };

  /// Wie [key] übertragen wird.
  ///
  /// [value] entscheidet der Leser selbst: Ein Array wird einzeln
  /// zusammengeführt, alles andere als Ganzes. Diese Funktion beantwortet nur
  /// die Frage, die sich **ohne** den gespeicherten Wert stellen lässt.
  static SyncKeyKind classify(String key) {
    if (!isSyncable(key)) return SyncKeyKind.excluded;
    if (itemKeys.contains(_bareKey(key))) return SyncKeyKind.items;
    return SyncKeyKind.value;
  }

  /// true, wenn [key] niemals übertragen wird.
  static bool isNeverSync(String key) {
    final String bare = _bareKey(key);
    for (final String blocked in neverSync) {
      if (bare == blocked || key == blocked) return true;
    }
    return false;
  }

  /// Die Form von [key] – für einen unbekannten Schlüssel `null`.
  static StoredForm? formOf(String key) => dataKeyForms[_bareKey(key)];

  /// Zugangsdaten. Werden **nie** übertragen – weder im Sync noch im Share.
  static const List<String> credentialKeys = <String>[
    'vplanSchoolnumber',
    'vplanUsername',
    'vplanPassword',
    'customUrl',
  ];

  /// Die item-Schlüssel, inklusive der schulbezogenen [scopedKey].
  ///
  /// [scopedKey] bildet den Schlüssel einer Schule, wie es `SchoolStorage`
  /// macht: für die Standardschule der nackte Schlüssel, sonst
  /// `schools.<id>.<schlüssel>`.
  static List<String> forSchool(
    String Function(String key) scopedKey, {
    required bool includeSettings,
  }) =>
      dataKeysOf(scopedKey);

  /// Nur die item-Schlüssel, inklusive der schulbezogenen [scopedKey].
  static List<String> dataKeysOf(String Function(String key) scopedKey) =>
      itemKeys.map(scopedKey).toList();

  /// Prüft, ob [key] überhaupt übertragen werden darf.
  ///
  /// Entscheidet **nur** anhand des Schlüssels, nicht anhand des gespeicherten
  /// Werts: Geheimnisse und Gerätelokales stehen in [neverSync], der Rest ist
  /// übertragbar. Wie ein übertragbarer Schlüssel behandelt wird – einzeln
  /// oder als Ganzes –, entscheidet der Leser anhand des Typs.
  static bool isSyncable(String key) =>
      !isNeverSync(key) &&
      !isCacheKey(key) &&
      !isDeviceLocalKey(key) &&
      !key.startsWith('sync.');

  /// true, wenn [key] eine Einstellung ist – also kein Bestandteil, sondern
  /// ein Wert, der als Ganzes gesetzt wird.
  ///
  /// Ohne den gespeicherten Wert lässt sich das nicht entscheiden; deshalb
  /// nehmen die Aufrufer den Typ dazu (siehe [SyncEngine.collect]).
  static bool isSetting(String key) => classify(key) == SyncKeyKind.value;

  /// true, wenn [key] nur auf diesem Gerät etwas bedeutet.
  ///
  /// ## `languageCode` steht hier nicht mehr
  ///
  /// Es stand hier mit der Begründung, Sprache hänge an der Bildschirmgröße
  /// und nicht an der Person. Das war eine **Annahme**, keine Beobachtung –
  /// und sie hat eine Einstellung aus der Kette gehalten, die jeder erwartet,
  /// dass sie wandert. Sprache ist eine Vorliebe der Person; sie wird
  /// übertragen wie jede andere Einstellung.
  ///
  /// Wer sie auf einem Gerät anders will, schaltet die Einstellungen in der
  /// Kette ab – dafür ist der Schalter da, und der ist geräteübergreifend
  /// wirksam, statt einzelne Werte auszunehmen.
  static bool isDeviceLocalKey(String key) {
    // Sowohl der volle als auch der schulbezogene Schlüssel: `sync.tombstones`
    // enthält Punkte, deshalb wäre `_bareKey` hier 'tombstones'.
    if (key == SyncMergeLocalKeys.tombstones ||
        key.endsWith('.${SyncMergeLocalKeys.tombstones}')) {
      return true;
    }
    final String bare = _bareKey(key);
    return bare == 'firstTime' ||
        bare == 'overriddenNow' ||
        bare.startsWith('vplan_cache_');
  }

  /// true für den Kurzzeit-Cache der Pläne.
  static bool isCacheKey(String key) =>
      key.contains('vplan_cache_') ||
      (key.endsWith('_time') && key.contains('vplan_cache'));

  /// `schools.<id>.persons` -> `persons`
  ///
  /// Oeffentlich, weil Aufrufer ausserhalb der Klasse den nackten Schluessel
  /// brauchen (z.B. um einen item-Schluessel wiederzuerkennen).
  static String bareKeyOf(String key) => _bareKey(key);

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
  /// Die Zeilen sind entweder ein **Objekt** oder ein **einfacher Name**.
  ///
  /// Beides kommt vor, und der Unterschied entscheidet sich am Inhalt, nicht an
  /// der Speicherform:
  ///
  /// | Schlüssel | Zeile |
  /// |---|---|
  /// | `persons`, `offlineVPData`, `sickTrack`, `teacherShorts`, `lessontimes` | JSON-Objekt |
  /// | `classes`, `cachedRooms` | schlicht ein Name, etwa `8a` |
  ///
  /// Vorher wurde **jede** Zeile mit `jsonDecode` zerlegt und jede Zeile
  /// verworfen, die kein Objekt ergab. Bei `8a` scheitert `jsonDecode` – und
  /// damit sind die Klassen nie in einer Kette angekommen. Der Sync meldete
  /// Erfolg, es war nur nichts zu senden, und die Oberfläche zeigte dauerhaft
  /// „Alles ist aktuell".
  ///
  /// Eine Zahl wie `123` ist zwar gültiges JSON, wäre aber als *Zeichenkette*
  /// gespeichert. Deshalb wird nur dekodiert, was auch ein Objekt oder eine
  /// Zeichenkette ergibt – alles andere bleibt der rohe Text.
  static Future<Map<String, List<Object>>> readParts(
    SharedPreferences prefs,
    List<String> keys,
  ) async {
    final Map<String, List<Object>> parts = <String, List<Object>>{};
    for (final String key in keys) {
      final List<String> raw = _stringList(prefs, key);
      if (raw.isEmpty) continue;
      final List<Object> items = <Object>[];
      for (final String entry in raw) {
        final Object? decoded = _decode(entry);
        if (decoded == null) continue;
        items.add(decoded);
      }
      if (items.isEmpty) continue;
      parts[key] = items;
    }
    return parts;
  }

  /// Die übertragbaren Werte, die **keine** Bestandteile sind.
  ///
  /// Also alles, was kein Array von Einträgen ist: Karten
  /// (`hiddenSubjectsByClass`, `initializedClasses`, `previewHidden*`),
  /// Schalter (`hideTeacher`, `hidePersons`), Zahlen, Zeichenketten
  /// (`languageCode`, `defaultPlanModeClass`, …).
  ///
  /// Der Unterschied zu [readParts] ist nicht die Herkunft, sondern die
  /// Zusammenführung: Hier wird der **ganze** Wert übernommen, wenn das andere
  /// Gerät den neueren Stand hat. Eine Karte von Vorschau-Ausnahmen einzeln
  /// zusammenzuführen wäre sinnlos – sie wird als Ganzes gesetzt.
  ///
  /// Eine **Positivliste** wäre hier genau der Fehler, der die Einstellungen
  /// bisher ausgeschlossen hat: Sie kann nicht vollständig sein, und jede neue
  /// Einstellung bliebe ohne jedes Zeichen auf diesem Gerät. Deshalb wird
  /// über die tatsächlich vorhandenen Schlüssel entschieden, gefiltert nur
  /// nach [SyncKeys.isSyncable].
  static Map<String, dynamic> readValues(
    SharedPreferences prefs, {
    Set<String> exclude = const <String>{},
  }) {
    final Map<String, dynamic> values = <String, dynamic>{};
    // Sortiert, damit die Reihenfolge im Paket stabil bleibt. Ohne das wäre
    // der verschlüsselte Text bei gleicher Datenlage jedes Mal ein anderer.
    final List<String> keys = prefs.getKeys().toList()..sort();
    for (final String key in keys) {
      if (exclude.contains(key)) continue;
      if (!SyncKeys.isSyncable(key)) continue;
      // Die Bestandteile aus [SyncKeys.itemKeys] sind **keine** Werte. Ohne
      // diesen Ausschluss stuende `classes` doppelt im Paket: einmal als Liste
      // von Eintraegen und einmal als Ganzes. Beide werden getrennt
      // zusammengefuehrt, und das zweite Schreiben ueberschreibt das erste –
      // die Folge waere, dass Klassen stillschweigend verloren gehen.
      if (SyncKeys.itemKeys.contains(SyncKeys.bareKeyOf(key))) continue;
      final Object? value = _rawValue(prefs, key);
      if (value == null) continue;
      values[key] = _plainValue(value);
    }
    return values;
  }

  /// Die Karten-Schlüssel, dekodiert.
  ///
  /// Nötig, weil die App sie als **JSON-Zeichenkette** ablegt
  /// (`setString(key, jsonEncode(map))`). Ohne das Dekodieren reiste
  /// `initializedClasses` als Zeichenkette `"{\"c1\":true}"` – und der Merge
  /// könnte sie nur als Ganzes behandeln. Damit ginge jede Angabe verloren,
  /// die nur auf einem Gerät steht: Blendet die Kollegin auf ihrem Gerät
  /// Deutsch in der 8a aus und hier jemand in der 8b, wäre nach dem Sync nur
  /// noch eine der beiden Angaben da, ohne jede Meldung.
  ///
  /// Zurückgeschrieben wird wieder als JSON-Zeichenkette – siehe
  /// [SyncMerge] –, also ist die Form für die App dieselbe wie vorher.
  static Map<String, dynamic> readMaps(
    SharedPreferences prefs, {
    Set<String> exclude = const <String>{},
  }) {
    final Map<String, dynamic> maps = <String, dynamic>{};
    final List<String> keys = prefs.getKeys().toList()..sort();
    for (final String key in keys) {
      if (exclude.contains(key)) continue;
      if (!SyncKeys.isSyncable(key)) continue;
      if (SyncKeys.itemKeys.contains(SyncKeys.bareKeyOf(key))) continue;
      final String? raw = _tryString(prefs, key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final Object? decoded = jsonDecode(raw);
        // Nur echte Objekte. Ein Array gehört zu den Bestandteilen, und eine
        // gewöhnliche Zeichenkette wie `de` ist keine Karte.
        if (decoded is Map) maps[key] = decoded.cast<String, dynamic>();
      } catch (_) {
        // Kein JSON – dann ist es eine ganz gewöhnliche Zeichenkette.
      }
    }
    return maps;
  }

  /// Wandelt einen gelesenen Wert in etwas, das über JSON und wieder zurück
  /// seine Form behält.
  ///
  /// `SharedPreferences` kennt fünf Typen, JSON kennt drei. Ein `StringList`
  /// wird zu einer Liste von Zeichenketten – das ist genau die Form, in der
  /// die App `classes` und `offlineVPData` ablegt, und für `readValues`
  /// uninteressant, weil Arrays ohnehin Bestandteile sind.
  static Object? _plainValue(Object? value) {
    if (value is List) {
      return value.map((Object? e) => e is String ? e : jsonEncode(e)).toList();
    }
    return value;
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

  /// Die Zeilen eines Bestandteils, dekodiert – als Einträge, nicht als Text.
  ///
  /// Für alles, was einen Bestandteil ausgeben will: die Vorschau im Menü, der
  /// Share-Import, die Anzeige in den Einstellungen. Wer stattdessen `prefs`
  /// liest, bekommt bei `classes` eine Liste mit JSON-Zeichenketten und
  /// übersieht, dass dort schlichte Namen stehen.
  static List<Object> readItems(SharedPreferences prefs, String key) {
    final List<Object> items = <Object>[];
    for (final String entry in _stringList(prefs, key)) {
      final Object? decoded = _decode(entry);
      if (decoded != null) items.add(decoded);
    }
    return items;
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

  /// Zerlegt eine Zeile – oder lässt sie stehen, wenn sie kein JSON ist.
  ///
  /// Gibt null zurück, wenn die Zeile leer ist; das ist der einzige Fall, in
  /// dem eine Zeile wirklich verloren geht.
  static Object? _decode(String entry) {
    if (entry.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(entry);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      // `"Deutsch"` – ein als JSON notierter Name. Kommt vor, wenn eine Liste
      // als JSON-Zeichenkette abgelegt wurde.
      if (decoded is String) return decoded;
      // Eine Zahl oder ein Wahrheitswert: Als **Zeichenkette** gespeichert,
      // also der rohe Text nehmen. Ein Klassenname `123` darf nicht zur Zahl
      // 123 werden.
    } catch (_) {
      // Kein JSON – dann ist es schlicht ein Name wie `8a`.
    }
    return entry;
  }

  /// Liest einen Wert als Zeichenkette, ohne bei falschem Typ zu werfen.
  static String? _tryString(SharedPreferences prefs, String key) {
    try {
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  /// Liest einen Wert unabhängig von seinem Typ.
  static Object? _rawValue(SharedPreferences prefs, String key) {    for (final Object? Function() read in <Object? Function()>[
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
