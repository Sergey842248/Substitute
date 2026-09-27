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
/// Personen, Kurse **und Zugangsdaten**) als JSON – und stellt sie wieder her.
///
/// Enthalten sind bewusst auch die Zugangsdaten, damit ein Import auf einem
/// neuen Gerät die App sofort nutzbar macht. Die Datei enthält damit im
/// Klartext das Passwort und sollte entsprechend behandelt werden – die App
/// weist vor dem Export und beim Teilen darauf hin.
///
/// Nicht gesichert werden nur:
///
/// * **Zwischengespeicherte Pläne** (`offlineVPData`, `vplan_cache_*`):
///   Sie sind reine Datenmüll, den die App jederzeit neu laden kann, und
///   würden die Datei unnötig aufblähen.
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
    'offlineVPData',
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
    // Plan-Cache inkl. seiner Zeitstempel ('…_time').
    if (key.startsWith('vplan_cache_')) return true;
    if (key.endsWith('_time') && key.contains('vplan_cache')) return true;
    return false;
  }

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
      'settings': settings,
    };
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
      await _setValue(prefs, key, settings[key]);
      applied.add(key);
    }

    return ConfigImportResult(
      appliedKeys: applied,
      removedKeys: removed,
      skippedKeys: skipped,
    );
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
