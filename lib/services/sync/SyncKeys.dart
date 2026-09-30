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

  static List<String> _stringList(SharedPreferences prefs, String key) {
    try {
      final List<String>? value = prefs.getStringList(key);
      if (value != null) return value;
    } catch (_) {
      // Unter diesem Schlüssel liegt ein Wert eines anderen Typs (etwa ein
      // Schalter). `SharedPreferences` wirft dann eine TypeError, statt null
      // zu liefern – für uns heißt das: hier gibt es nichts zu lesen.
      return const <String>[];
    }
    // Manche Werte liegen als JSON-Zeichenkette statt als StringList vor –
    // dann ist die gespeicherte Form das JSON-Array.
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((Object? e) => e.toString()).toList();
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
