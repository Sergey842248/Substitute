import 'dart:convert';

import '../ConfigBackup.dart';

/// Aufbau der Daten, die zwischen Geräten und über einen Share übertragen
/// werden.
///
/// Die App speichert alles als flache Schlüssel-/Wert-Paare in
/// `SharedPreferences` (siehe `ConfigBackup`). Für den Sync wird daraus eine
/// Liste von **[Datenbestandteilen]** mit jeweils eigener Identität:
///
/// ```dart
/// SyncPayload(
///   parts: [
///     SyncPart(key: 'persons', items: [...], idOf: (item) => item['id']),
///     SyncPart(key: 'offlineVPData', items: [...], idOf: (item) => item['date']),
///   ],
/// )
/// ```
///
/// Warum nicht ein simpler Schlüssel/Wert-Abgleich? Weil sonst das zuletzt
/// synchronisierte Gerät gewinnt: Wer auf dem Handy eine Person löscht, würde
/// sie auf dem Tablet sofort wiederbekommen. Mit Identitäten pro Eintrag kann
/// der Merge entscheiden:
///
/// * Eintrag nur lokal  -> **behalten** (auf dem anderen Gerät ist er nicht),
/// * Eintrag nur remote -> **übernehmen**,
/// * Eintrag in beiden  -> der mit dem neueren `updatedAt` gewinnt,
/// * gelöscht          -> der Eintrag verschwindt, statt wiederaufzutauchen.
///
/// Für den letzten Punkt braucht es Lösch-Markierungen ([SyncTombstone]).
class SyncPart {
  const SyncPart({
    required this.key,
    required this.items,
    required this.idOf,
    this.timestampOf,
  });

  /// Der `SharedPreferences`-Schlüssel, unter dem die App diesen Bestandteil
  /// ablegt – z.B. `persons` oder `schools.12345.persons`.
  final String key;

  /// Die Einträge als dekodierte Maps (bei Plänen: die dekodierten Plan-JSONs).
  final List<Map<String, dynamic>> items;

  /// Liefert die Identität eines Eintrags. Zwei Einträge mit gleicher Identität
  /// sind derselbe Eintrag.
  final String? Function(Map<String, dynamic> item) idOf;

  /// Liefert die Änderungszeit eines Eintrags. Fehlt sie, wird auf
  /// [SyncPayload.epoch] zurückgefallen, also gewinnt die höhere
  /// Gesamtzeit.
  final DateTime? Function(Map<String, dynamic> item)? timestampOf;

  SyncPart copyWithItems(List<Map<String, dynamic>> newItems) => SyncPart(
        key: key,
        items: newItems,
        idOf: idOf,
        timestampOf: timestampOf,
      );
}

/// Eine Lösch-Markierung: "Diesen Eintrag gab es, er ist aber weg".
///
/// Ohne sie würde ein gelöschter Eintrag beim nächsten Sync von einem Gerät
/// zurückkommen, das ihn noch hatte – der klassische "Zombie-Eintrag".
class SyncTombstone {
  const SyncTombstone({required this.key, required this.id, required this.deletedAt});

  final String key;
  final String id;
  final DateTime deletedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'id': id,
        'at': deletedAt.toUtc().toIso8601String(),
      };

  static SyncTombstone? fromJson(Map<String, dynamic> json) {
    final String key = json['key']?.toString() ?? '';
    final String id = json['id']?.toString() ?? '';
    final DateTime? at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (key.isEmpty || id.isEmpty || at == null) return null;
    return SyncTombstone(key: key, id: id, deletedAt: at);
  }
}

/// Das Ergebnis eines Zusammenführens.
class SyncMergeResult {
  const SyncMergeResult({
    required this.parts,
    required this.tombstones,
    required this.added,
    required this.updated,
    required this.removed,
    required this.tombstonesAdded,
    this.settings,
  });

  final List<SyncPart> parts;
  final List<SyncTombstone> tombstones;

  /// IDs, die nur in den Daten des anderen Geräts vorkamen.
  final List<String> added;

  /// IDs, die es auf beiden Seiten gab und wo die entfernten gewonnen haben.
  final List<String> updated;

  /// IDs, die es nur lokal gaben, aber remote gelöscht wurden.
  final List<String> removed;

  /// Lösch-Markierungen, die neu dazukamen.
  final List<SyncTombstone> tombstonesAdded;

  /// Die zusammengeführten einfachen Einstellungen.
  ///
  /// [SyncMerge] füllt dieses Feld, die Teilergebnisse nicht – deshalb ist es
  /// hier nullable.
  final Map<String, dynamic>? settings;

  bool get hasChanges =>
      added.isNotEmpty || updated.isNotEmpty || removed.isNotEmpty;

  int get totalChanges =>
      added.length + updated.length + removed.length + tombstonesAdded.length;
}

/// Das serialisierbare Paket, das über den Server läuft.
class SyncPayload {
  const SyncPayload({
    required this.parts,
    required this.tombstones,
    required this.settings,
    required this.updatedAt,
    this.deviceName = '',
  });

  /// Formatversion. Bei inkompatiblen Änderungen hochzählen.
  static const int schemaVersion = 1;

  /// Zeitpunkt, an dem ein Eintrag ohne eigene Zeitangabe zuletzt geändert
  /// wurde. Nicht `DateTime.fromMillisecondsSinceEpoch(0)`, sondern der
  /// Start des Unix-Zeitalters: Der Wert taucht alsbeschreibbare Zahl in
  /// alten Sicherungen auf und macht die Zeitachse lesbar.
  static final DateTime epoch = DateTime.utc(1970);

  final List<SyncPart> parts;
  final List<SyncTombstone> tombstones;

  /// Einfache Schlüssel/Wert-Paare (Schalter, Modus, Anzeigenamen). Ohne
  /// Identität, deshalb gilt hier "zuletzt geändert gewinnt" – das ist für
  /// Bool-Schalter genau das richtige Verhalten.
  final Map<String, dynamic> settings;

  /// Wann dieses Gerät den Stand zuletzt zusammengestellt hat.
  final DateTime updatedAt;

  /// Optionaler Gerätename, damit die Geräteliste in der App lesbar ist, ohne
  /// dass der Server etwas entschlüsseln muss.
  final String deviceName;

  bool get isEmpty => parts.every((SyncPart p) => p.items.isEmpty);

  /// Serialisiert das Paket für die Verschlüsselung.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'app': 'substitute',
        'schema': schemaVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deviceName': deviceName,
        'settings': settings,
        'tombstones': tombstones
            .map((SyncTombstone t) => t.toJson())
            .toList(growable: false),
        'parts': parts
            .map((SyncPart part) => <String, dynamic>{
                  'key': part.key,
                  'items': part.items,
                })
            .toList(growable: false),
      };

  /// Liest ein Paket aus entschlüsseltem JSON.
  ///
  /// Wirft [FormatException] mit einem kurzen Code, wenn die Struktur nicht
  /// passt – die UI übersetzt den Code in eine Meldung.
  static SyncPayload fromJson(Map<String, dynamic> json) {
    if (json['app'] != 'substitute') {
      throw const FormatException('foreignApp');
    }
    final int schema = json['schema'] is int ? json['schema'] as int : 0;
    if (schema > schemaVersion) {
      throw const FormatException('futureSchema');
    }

    final List<SyncPart> parts = <SyncPart>[];
    for (final Object? entry in (json['parts'] as List<dynamic>? ?? <dynamic>[])) {
      if (entry is! Map) continue;
      final String key = entry['key']?.toString() ?? '';
      if (key.isEmpty) continue;
      final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
      for (final Object? item in (entry['items'] as List<dynamic>? ?? <dynamic>[])) {
        if (item is Map) items.add(item.cast<String, dynamic>());
      }
      parts.add(describePart(key, items));
    }

    final List<SyncTombstone> tombstones = <SyncTombstone>[];
    for (final Object? entry
        in (json['tombstones'] as List<dynamic>? ?? <dynamic>[])) {
      if (entry is! Map) continue;
      final SyncTombstone? tombstone =
          SyncTombstone.fromJson(entry.cast<String, dynamic>());
      if (tombstone != null) tombstones.add(tombstone);
    }

    final Map<String, dynamic> settings = <String, dynamic>{};
    final Object? rawSettings = json['settings'];
    if (rawSettings is Map) {
      for (final MapEntry<Object?, Object?> e in rawSettings.entries) {
        final String key = e.key.toString();
        if (key.isEmpty || e.value == null) continue;
        settings[key] = e.value;
      }
    }

    return SyncPayload(
      parts: parts,
      tombstones: tombstones,
      settings: settings,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
              epoch,
      deviceName: json['deviceName']?.toString() ?? '',
    );
  }

  /// Baut für einen Schlüssel die passende [SyncPart]-Beschreibung.
  ///
  /// Die Zuordnung liegt hier zentral, weil sie an zwei Stellen gebraucht wird:
  /// beim Einlesen eines Pakets und beim Anwenden auf `SharedPreferences`.
  static SyncPart describePart(String key, List<Map<String, dynamic>> items) {
    if (ConfigBackup.isCachedPlansKey(key)) {
      return SyncPart(
        key: key,
        items: items,
        idOf: (Map<String, dynamic> item) => _planDate(item) ?? '',
      );
    }
    return SyncPart(
      key: key,
      items: items,
      idOf: (Map<String, dynamic> item) => _identityOf(key, item),
      timestampOf: (Map<String, dynamic> item) =>
          DateTime.tryParse(item['_t']?.toString() ?? '')?.toUtc(),
    );
  }

  /// Die Identität eines Eintrags in einer Liste (Personen, Krankentracking,
  /// Kürzel, Zeiten, ...).
  ///
  /// Bewusst aus mehreren Feldern gebildet: Eine Kürzel-Liste kennt keine IDs,
  /// da ist das Kürzel selbst die Identität – bei den Zeiten ist es die
  /// Kombination aus Anzahl, Beginn und Ende, weil sich Uhrzeiten ändern.
  static String _identityOf(String key, Map<String, dynamic> item) {
    if (item['id'] != null) return item['id'].toString();
    if (item['short'] != null) return item['short'].toString();
    if (item['count'] != null) {
      return '${item['count']}_${item['start']}_${item['end']}';
    }
    if (item['date'] != null) return item['date'].toString();
    // Fällt auf den ganzen Inhalt zurück: zwei wirklich verschiedene
    // Einträge gelten dann als verschieden, gleiche als gleicher Eintrag.
    return jsonEncode(_withoutTimestamp(item));
  }

  /// Das Datum eines Planeintrags – bei verschachtelten Plänen
  /// `data.Kopf.DatumPlan`.
  static String? _planDate(Map<String, dynamic> item) {
    final Object? date = item['date'] ?? _nestedPlanDate(item['data']);
    final String? value = date?.toString();
    return (value == null || value.isEmpty) ? null : value;
  }

  static Object? _nestedPlanDate(Object? data) {
    if (data is! Map) return null;
    final Object? kopf = data['Kopf'];
    return kopf is Map ? kopf['DatumPlan'] : null;
  }

  /// Entfernt das interne Zeitfeld, damit es nicht in die Identität eingeht.
  static Map<String, dynamic> _withoutTimestamp(Map<String, dynamic> item) {
    final Map<String, dynamic> copy = Map<String, dynamic>.of(item)
      ..remove(syncTimestampField);
    return copy;
  }

  /// Der Schlüssel, unter dem ein Listen-Eintrag seine Änderungszeit
  /// mitführt. Mit einem führenden Unterstrich, damit er in der App
  /// nicht versehentlich angezeigt wird.
  static const String syncTimestampField = '_t';
}
