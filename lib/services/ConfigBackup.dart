import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ergebnis eines Import-Vorgangs.
class ConfigImportResult {
  const ConfigImportResult({
    required this.appliedKeys,
    required this.removedKeys,
    required this.skippedKeys,
  });

  /// Schlüssel, die aus der Datei übernommen wurden.
  final List<String> appliedKeys;

  /// Schlüssel, die zuvor entfernt wurden (nur beim Ersetzen).
  final List<String> removedKeys;

  /// Schlüssel, die bewusst nicht übernommen wurden (z.B. Passwörter).
  final List<String> skippedKeys;

  int get total =>
      appliedKeys.length + removedKeys.length + skippedKeys.length;
}

/// Sichert die gesamte Konfiguration der App (Einstellungen, Klassen,
/// Personen, Kurse, **zwischengespeicherte Vertretungspläne** und
/// **Zugangsdaten**) als JSON – und stellt sie wieder her.
///
/// Enthalten sind bewusst auch die Zugangsdaten, damit ein Import auf einem
/// neuen Gerät die App sofort nutzbar macht. Die Datei enthält damit im
/// Klartext das Passwort und sollte entsprechend behandelt werden – die App
/// weist vor dem Export und beim Teilen darauf hin.
///
/// Die lokal gespeicherten Pläne (`offlineVPData`, je Schule ggf.
/// `schools.<id>.offlineVPData`) gehören ebenfalls dazu: Sie sind der Grund,
/// warum sich in der App auch Tage in der Vergangenheit öffnen lassen, und
/// ohne sie wäre eine Wiederherstellung unvollständig.
///
/// Nicht gesichert werden nur:
///
/// * **Kurzzeit-Cache** (`vplan_cache_*` inkl. Zeitstempel): reiner
///   Zwischenspeicher, der nach wenigen Minuten ohnehin verfällt.
/// * **Entwickler-Overrides** (`overriddenNow`): gerätebezogen.
class ConfigBackup {
  const ConfigBackup._();

  /// Formatversion der Exportdatei. Bei inkompatiblen Änderungen hochzählen,
  /// damit ein Import alter Dateien abgelehnt werden kann.
  static const int schemaVersion = 1;

  static const String _appIdentifier = 'substitute';

  /// Schlüssel, die weder exportiert noch importiert werden.
  static const List<String> sensitiveKeys = <String>[
    'overriddenNow',
  ];

  /// Schlüssel, die Zugangsdaten enthalten. Sie werden mitgesichert (damit ein
  /// Import auf einem neuen Gerät funktioniert), aber die UI warnt davor.
  static const List<String> credentialKeys = <String>[
    'vplanPassword',
    'vplanUsername',
    'vplanSchoolnumber',
  ];

  /// true, wenn [key] eine Zugangsdaten-Angabe ist. Berücksichtigt auch die
  /// schulbezogenen Schlüssel ('schools.<id>.vplanPassword').
  static bool _isCredentialKey(String key) {
    if (credentialKeys.contains(key)) return true;
    for (final String credential in credentialKeys) {
      if (key.endsWith('.$credential')) return true;
    }
    return false;
  }

  /// true, wenn [key] eine Datei mit Zugangsdaten erzeugen kann.
  static bool containsCredentials(Map<String, dynamic> settings) =>
      settings.keys.any(_isCredentialKey);

  /// Präfixe/Pfade, die nicht Teil der Konfiguration sind (Cache & Dev).
  static bool _isExcluded(String key) {
    if (sensitiveKeys.contains(key)) return true;
    // Kurzzeit-Cache der Pläne inkl. seiner Zeitstempel ('…_time'). Auch die
    // schulbezogenen Varianten ('schools.<id>.vplan_cache_…') – sonst würde der
    // Cache einer Nicht-Default-Schule mit exportiert.
    if (key.contains('vplan_cache_')) return true;
    if (key.endsWith('_time') && key.contains('vplan_cache')) return true;
    return false;
  }

  /// Prüft, ob [key] die lokal gespeicherten Pläne enthält – je nach aktiver
  /// Schule `offlineVPData` oder `schools.<id>.offlineVPData`.
  static bool isCachedPlansKey(String key) =>
      key == 'offlineVPData' || key.endsWith('.offlineVPData');

  /// Liest die Konfiguration und baut daraus den Inhalt der Exportdatei.
  ///
  /// [includeCredentials] == false lässt die Zugangsdaten weg – für Dateien,
  /// die weitergegeben werden, ohne das Passwort preiszugeben. Ein solcher
  /// Export kann später trotzdem importiert werden; die Zugangsdaten werden
  /// dann nur nicht überschrieben, sofern nicht ["Ersetzen"] gewählt wird.
  static Future<Map<String, dynamic>> buildExport(
    SharedPreferences prefs, {
    bool includeCredentials = true,
  }) async {
    final Map<String, dynamic> settings = <String, dynamic>{};
    final List<String> keys = prefs.getKeys().toList()..sort();
    for (final String key in keys) {
      if (_isExcluded(key)) continue;
      if (!includeCredentials && _isCredentialKey(key)) continue;
      final Object? value = _getValue(prefs, key);
      if (value == null) continue;
      settings[key] = value;
    }
    return <String, dynamic>{
      'app': _appIdentifier,
      'schema': schemaVersion,
      'cachedPlans': countCachedPlans(settings),
      'settings': settings,
    };
  }

  /// Anzahl der in [settings] enthaltenen Pläne – steht als Metadatum in der
  /// Exportdatei, damit man sieht, was im Backup steckt.
  static int countCachedPlans(Map<String, dynamic> settings) {
    int count = 0;
    for (final MapEntry<String, dynamic> entry in settings.entries) {
      if (!isCachedPlansKey(entry.key)) continue;
      final Object? value = entry.value;
      if (value is List) count += value.length;
    }
    return count;
  }

  /// Serialisiert den Export (mit Zeitstempel) als JSON-Text.
  static String encodeExport(
    Map<String, dynamic> export, {
    DateTime? exportedAt,
    String? appVersion,
  }) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      ...export,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      if (appVersion != null) 'appVersion': appVersion,
    });
  }

  /// Liest die Schlüssel-/Wert-Paare aus einem JSON-Text.
  ///
  /// Wirft [FormatException], wenn die Datei kein gültiger Export dieser App
  /// ist – der Aufrufer zeigt dann eine verständliche Fehlermeldung.
  static Map<String, dynamic> parseExport(String content) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw const FormatException('invalidJson');
    }
    if (decoded is! Map) throw const FormatException('invalidJson');

    final Map<String, dynamic> map = decoded.cast<String, dynamic>();
    if (map['app'] != _appIdentifier) throw const FormatException('foreignApp');
    final int schema = map['schema'] is int ? map['schema'] as int : 0;
    if (schema > schemaVersion) throw const FormatException('futureSchema');

    final dynamic settings = map['settings'];
    if (settings is! Map) throw const FormatException('invalidSettings');
    return settings.cast<String, dynamic>().map(
      // Nur einfache, JSON-fähige Werte zulassen.
      (String key, dynamic value) => MapEntry<String, dynamic>(
        key,
        value is Map || value == null ? null : _sanitize(value),
      ),
    );
  }

  /// Schreibt eine zuvor mit [parseExport] gelesene Konfiguration zurück.
  ///
  /// [replace] == true entfernt vorher alle vorhandenen Konfigurationsschlüssel
  /// (die nicht exportiert werden), sonst werden nur die Schlüssel der Datei
  /// überschrieben.
  static Future<ConfigImportResult> applyImport(
    SharedPreferences prefs,
    Map<String, dynamic> settings, {
    bool replace = false,
  }) async {
    final List<String> applied = <String>[];
    final List<String> skipped = <String>[];
    final List<String> removed = <String>[];

    if (replace) {
      for (final String key in prefs.getKeys().toList()) {
        if (_isExcluded(key)) continue;
        if (settings.containsKey(key)) continue;
        await prefs.remove(key);
        removed.add(key);
      }
    }

    for (final String key in settings.keys) {
      if (_isExcluded(key) || settings[key] == null) {
        skipped.add(key);
        continue;
      }
      Object? value = settings[key];
      if (isCachedPlansKey(key)) {
        value = _onlyValidPlans(value);
        if (value == null) {
          skipped.add(key);
          continue;
        }
        // Beim Ergänzen werden die lokalen Pläne nicht ersetzt, sondern mit den
        // Plänen der Datei vereinigt – sonst gingen gerade auf dem neuen Gerät
        // nachgeladene Tage verloren.
        if (!replace) value = _mergePlans(prefs, key, value as List<String>);
      }
      await _setValue(prefs, key, value);
      applied.add(key);
    }

    return ConfigImportResult(
      appliedKeys: applied,
      removedKeys: removed,
      skippedKeys: skipped,
    );
  }

  /// Vereinigt die lokal gespeicherten Pläne mit denen aus der Datei.
  ///
  /// Gleiche Tage werden nicht doppelt übernommen: Der Eintrag der Datei gewinnt
  /// (er ist die gewünschte Wiederherstellung), die Reihenfolge bleibt
  /// chronologisch nach dem Datum des Plans.
  static List<String> _mergePlans(
      SharedPreferences prefs, String key, List<String> imported) {
    final List<String> existing = _onlyValidPlans(_getValue(prefs, key)) ??
        <String>[];
    if (existing.isEmpty) return imported;

    final Map<String, String> byDate = <String, String>{};
    final List<String> withoutDate = <String>[];
    for (final String plan in <String>[...existing, ...imported]) {
      final String? date = _planDate(plan);
      if (date == null || date.isEmpty) {
        // Plan ohne lesbares Datum: nicht zusammenfassen, aber behalten.
        withoutDate.add(plan);
        continue;
      }
      byDate[date] = plan;
    }

    final List<String> merged = byDate.values.toList()
      ..sort((String a, String b) =>
          (_planDate(a) ?? '').compareTo(_planDate(b) ?? ''));
    return <String>[...merged, ...withoutDate];
  }

  /// Das Datum eines Plan-Eintrags (`dd.MM.yyyy` o.ä.), null wenn keins
  /// gefunden wird.
  static String? _planDate(String plan) {
    try {
      final dynamic decoded = jsonDecode(plan);
      if (decoded is! Map) return null;
      final Object? date = decoded['date'] ?? _nestedPlanDate(decoded['data']);
      return date?.toString();
    } catch (_) {
      return null;
    }
  }

  /// `data.Kopf.DatumPlan` – der Ort, an dem die API das Plantag ablegt.
  static Object? _nestedPlanDate(Object? data) {
    if (data is! Map) return null;
    final Object? kopf = data['Kopf'];
    return kopf is Map ? kopf['DatumPlan'] : null;
  }

  /// Filtert beschädigte Pläne aus einer Importdatei heraus.
  ///
  /// Die Pläne werden beim Laden als JSON dekodiert; ein einzelner unlesbarer
  /// Eintrag (etwa weil die Datei von Hand bearbeitet wurde) würde sonst beim
  /// Anzeigen der Vergangenheit bzw. im Krankentracking einen Fehler
  /// auslösen. Defekte Einträge werden deshalb stillschweigend verworfen.
  static List<String>? _onlyValidPlans(Object? value) {
    if (value is! List) return null;
    final List<String> valid = <String>[];
    for (final Object? entry in value) {
      if (entry is! String) continue;
      try {
        if (jsonDecode(entry) is Map<String, dynamic>) valid.add(entry);
      } catch (_) {
        continue;
      }
    }
    return valid;
  }

  /// Liest einen Wert typisiert – [SharedPreferences] bietet keine
  /// generische Getter-Variante, daher hier der Reihe nach probieren.
  static Object? _getValue(SharedPreferences prefs, String key) {
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
        // Typ passt nicht – nächsten Typ probieren.
      }
    }
    return null;
  }

  static Future<void> _setValue(
      SharedPreferences prefs, String key, dynamic value) async {
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List) {
      await prefs.setStringList(
          key, value.map((dynamic e) => e.toString()).toList());
    } else {
      await prefs.setString(key, value.toString());
    }
  }

  /// Wandelt verschachtelte Strukturen in einfache Strings um – die App
  /// speichert alles als String/Bool/Int/Double/StringList.
  static dynamic _sanitize(dynamic value) {
    if (value is List) {
      return value.map((dynamic e) => e.toString()).toList();
    }
    if (value is Map) return value.toString();
    return value;
  }
}
