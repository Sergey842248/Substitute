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
    DateTime? orderAt,
  }) : _orderAt = orderAt;

  /// Der `SharedPreferences`-Schlüssel, unter dem die App diesen Bestandteil
  /// ablegt – z.B. `persons` oder `schools.12345.persons`.
  final String key;

  /// Die Einträge, dekodiert.
  ///
  /// Ein Eintrag ist entweder ein **Objekt** (`Map<String, dynamic>`) oder ein
  /// **einfacher Name** (`String`). Beides kommt in der App vor:
  ///
  /// * `persons`, `offlineVPData`, `sickTrack` – Zeilen mit JSON-Objekten,
  /// * `classes`, `classNames`, `cachedRooms` – Zeilen, die schlicht ein
  ///   Klassen- oder Raumname sind.
  ///
  /// Vorher war ausschliesslich `Map<String, dynamic>` erlaubt, und der Leser
  /// zerlegte jede Zeile mit `jsonDecode`. Ein Klassenname wie `8a` ist aber
  /// **kein** JSON – `jsonDecode` scheitert daran, und die Zeile fiel
  /// kommentarlos heraus. Damit sind die Klassen nie in einer Kette
  /// angekommen: Der Sync meldete Erfolg, es war nur nichts zu senden.
  final List<Object> items;

  /// Liefert die Identität eines Eintrags. Zwei Einträge mit gleicher Identität
  /// sind derselbe Eintrag.
  final String? Function(Object item) idOf;

  /// Liefert die Änderungszeit eines Eintrags. Fehlt sie, wird auf
  /// [SyncPayload.epoch] zurückgefallen, also gewinnt die höhere
  /// Gesamtzeit.
  final DateTime? Function(Object item)? timestampOf;

  /// Wann die **Reihenfolge** dieses Bestandteils zuletzt geändert wurde.
  ///
  /// Die Reihenfolge gehört zum Bestandteil, nicht zum einzelnen Eintrag:
  /// „8a vor 8b" ist eine Aussage über die Liste und lässt sich aus keinem
  /// Eintrag errechnen. Sie wird deshalb wie ein Wert behandelt – wer sie
  /// zuletzt geändert hat, gibt sie vor.
  ///
  /// Vorher wurde hier einfach nach Identität sortiert. Das war eindeutig und
  /// machte die Reihenfolge **unbrauchbar**: Ein Gerät, auf dem die Klassen in
  /// der Reihenfolge `XYZ, ABC` angelegt waren, bekam sie nach dem Sync
  /// alphabetisch – `ABC, XYZ`. Die Anordnung in der App ist aber
  /// benutzersichtbar, sie ist das, woran sich jemand gewöhnt hat.
  final DateTime? _orderAt;

  /// Siehe [_orderAt]. Ohne Angabe gilt [SyncPayload.epoch]: dann hat sich
  /// niemand die Reihenfolge verdient, und der Gleichstand entscheidet
  /// einheitlich.
  DateTime get orderAt => _orderAt ?? SyncPayload.epoch;

  SyncPart copyWithItems(List<Object> newItems, {DateTime? orderAt}) => SyncPart(
        key: key,
        items: newItems,
        idOf: idOf,
        timestampOf: timestampOf,
        orderAt: orderAt ?? _orderAt,
      );

  /// Die Identitäten in der Reihenfolge, in der sie hier stehen.
  List<String> get identityOrder => <String>[
        for (final Object item in items)
          if ((idOf(item) ?? '').isNotEmpty) idOf(item)!,
      ];
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
    this.settingsAt,
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

  /// Die zusammengeführten Werte.
  ///
  /// [SyncMerge] füllt dieses Feld, die Teilergebnisse nicht – deshalb ist es
  /// hier nullable.
  final Map<String, dynamic>? settings;

  /// Die zusammengeführten Änderungszeiten je Wert.
  ///
  /// Gehören zwingend zu [settings]: Ohne sie ist beim nächsten Lauf nicht mehr
  /// unterscheidbar, ob ein Wert alt ist oder gerade eben übernommen wurde –
  /// und die Kette käme nach einem erfolgreichen Lauf zum Stillstand.
  final Map<String, DateTime>? settingsAt;

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
    this.settingsAt = const <String, DateTime>{},
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

  /// Alle Werte, die als Ganzes übertragen werden: Karten
  /// (`hiddenSubjectsByClass`, `initializedClasses`, `previewHidden*`),
  /// Schalter, Zahlen und Zeichenketten (`languageCode`,
  /// `defaultPlanModeClass`).
  ///
  /// Ohne Identität, deshalb gilt hier "zuletzt geändert gewinnt" – für einen
  /// Schalter genau das richtige Verhalten. **Die** Zeit dafür steht in
  /// [settingsAt], nicht in [updatedAt].
  final Map<String, dynamic> settings;

  /// Die Änderungszeit **je Wert**.
  ///
  /// Vorher stand hierfür ein einziger Zeitstempel für das ganze Paket, gesetzt
  /// auf „jetzt" bei jedem Lauf. Damit war jedes Gerät beim letzten Sync
  /// vermeintlich das neueste, und keine Einstellung wanderte jemals.
  ///
  /// Fehlt ein Eintrag – etwa bei einem Paket aus einer älteren App-Version –
  /// gilt [updatedAt] als Ersatz. So können alte und neue Geräte zeitweise in
  /// derselben Kette stehen, ohne dass etwas verloren geht.
  final Map<String, DateTime> settingsAt;

  /// Die Änderungszeit von [key], mit Rückfall auf [updatedAt].
  DateTime stampOf(String key) => settingsAt[key] ?? updatedAt;

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
        'settingsAt': <String, String>{
          for (final MapEntry<String, DateTime> entry in settingsAt.entries)
            entry.key: entry.value.toUtc().toIso8601String(),
        },
        'tombstones': tombstones
            .map((SyncTombstone t) => t.toJson())
            .toList(growable: false),
        'parts': parts
            .map((SyncPart part) => <String, dynamic>{
                  'key': part.key,
                  'items': part.items,
                  'orderAt': part.orderAt.toUtc().toIso8601String(),
                })
            .toList(growable: false),
      };

  /// Liest die Zeitangaben je Wert.
  ///
  /// Fehlt das Feld ganz – ein Paket aus einer älteren App-Version – kommt eine
  /// leere Map zurück, und [stampOf] fällt dann auf [updatedAt] zurück. So
  /// bleibt ein alter Stand lesbar, statt das Gerät mit einem Formatfehler
  /// auszuschließen.
  static Map<String, DateTime> _readStamps(Object? raw) {
    if (raw is! Map) return <String, DateTime>{};
    final Map<String, DateTime> stamps = <String, DateTime>{};
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      final DateTime? parsed =
          DateTime.tryParse(entry.value.toString())?.toUtc();
      if (parsed != null) stamps[entry.key.toString()] = parsed;
    }
    return stamps;
  }

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
      final List<Object> items = <Object>[];
      for (final Object? item
          in (entry['items'] as List<dynamic>? ?? <dynamic>[])) {
        // Objekte und einfache Zeichenketten sind beide gültige Einträge –
        // siehe [SyncPart.items]. Alles andere wird übergangen.
        if (item is Map) {
          items.add(item.cast<String, dynamic>());
        } else if (item is String) {
          items.add(item);
        }
      }
      parts.add(describePart(
        key,
        items,
        orderAt: DateTime.tryParse(entry['orderAt']?.toString() ?? '')?.toUtc(),
      ));
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
      settingsAt: _readStamps(json['settingsAt']),
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
  static SyncPart describePart(
    String key,
    List<Object> items, {
    DateTime? orderAt,
  }) {
    if (ConfigBackup.isCachedPlansKey(key)) {
      return SyncPart(
        key: key,
        items: items,
        idOf: (Object item) => _planDate(item) ?? '',
        orderAt: orderAt,
      );
    }
    return SyncPart(
      key: key,
      items: items,
      orderAt: orderAt,
      idOf: (Object item) => _identityOf(key, item),
      timestampOf: (Object item) => item is Map
          ? DateTime.tryParse(item['_t']?.toString() ?? '')?.toUtc()
          : null,
    );
  }

  /// Die Identität eines Eintrags in einer Liste (Personen, Krankentracking,
  /// Kürzel, Zeiten, ...).
  ///
  /// Bewusst aus mehreren Feldern gebildet: Eine Kürzel-Liste kennt keine IDs,
  /// da ist das Kürzel selbst die Identität – bei den Zeiten ist es die
  /// Kombination aus Anzahl, Beginn und Ende, weil sich Uhrzeiten ändern.
  ///
  /// Ein einfacher Name – etwa `8a` aus [SyncKeys.itemKeys] `classes` – ist
  /// seine **eigene** Identität. Zwei Geräte, die beide die Klasse `8a`
  /// haben, meinen dasselbe, und nach dem Merge steht sie genau einmal in der
  /// Liste. Ohne diese Regel wäre jeder Name auf beiden Geräten ein eigener
  /// Eintrag, und die Liste enthielte jede Klasse doppelt.
  static String _identityOf(String key, Object item) {
    if (item is String) return item;
    if (item is! Map) return jsonEncode(item);
    final Map<String, dynamic> record = item.cast<String, dynamic>();
    if (record['id'] != null) return record['id'].toString();
    if (record['short'] != null) return record['short'].toString();
    if (record['count'] != null) {
      return '${record['count']}_${record['start']}_${record['end']}';
    }
    if (record['date'] != null) return record['date'].toString();
    // Fällt auf den ganzen Inhalt zurück: zwei wirklich verschiedene
    // Einträge gelten dann als verschieden, gleiche als gleicher Eintrag.
    return jsonEncode(_withoutTimestamp(record));
  }

  /// Das Datum eines Planeintrags – bei verschachtelten Plänen
  /// `data.Kopf.DatumPlan`.
  static String? _planDate(Object item) {
    if (item is! Map) return null;
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

  /// Wandelt einen Eintrag in die Zeile, in der er gespeichert wird.
  ///
  /// Ein Objekt wird als JSON abgelegt, ein einfacher Name **genau wie er
  /// ist**. Das ist keine Feinheit: Die App schreibt die Klassen als
  /// `setStringList(key, ['8a', '8b'])` – ohne JSON. Mit `jsonEncode` stünden
  /// danach die Zeichenketten `"8a"` in der Liste, und die Klassenauswahl
  /// zeigte sie mit Anführungszeichen.
  static String encodeItem(Object item) =>
      item is String ? item : jsonEncode(item);

  /// Der Schlüssel, unter dem ein Listen-Eintrag seine Änderungszeit
  /// mitführt. Mit einem führenden Unterstrich, damit er in der App
  /// nicht versehentlich angezeigt wird.
  static const String syncTimestampField = '_t';
}
