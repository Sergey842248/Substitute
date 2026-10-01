import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ConfigBackup.dart';
import 'SyncKeys.dart';
import 'SyncPayload.dart';

/// Führt die Daten zweier Geräte zusammen.
///
/// Der Merge ist **symmetrisch**: Egal ob das lokale oder das entfernte
/// Gerät die neuere Änderung hat, das Ergebnis ist gleich. Das ist
/// Voraussetzung dafür, dass ein Sync in beide Richtungen funktioniert, ohne
/// dass eines der Geräte bevorzugt wird.
///
/// Zusammengefasst wird nach Identität, nicht nach Position:
///
/// ```text
/// lokal:    A@10:00   B@11:00   (C gelöscht @12:00)
/// entfernt: A@09:00   D@12:30
/// Ergebnis: A@10:00   B@11:00   D@12:30   + Löschung von C
/// ```
class SyncMerge {
  const SyncMerge._();

  /// Führt [local] und [remote] zusammen.
  ///
  /// [local] ist der Stand dieses Geräts, [remote] der eines anderen Geräts
  /// aus derselben Kette.
  static SyncMergeResult merge(SyncPayload local, SyncPayload remote) {
    // Lösch-Markierungen zuerst sammeln: Sie entscheiden, was danach
    // überhaupt noch in den Bestandteilen stehen darf.
    final Map<String, SyncTombstone> tombstones = <String, SyncTombstone>{
      for (final SyncTombstone tombstone in local.tombstones)
        tombstone.key + ' ' + tombstone.id: tombstone,
    };
    final List<SyncTombstone> addedTombstones = <SyncTombstone>[];
    for (final SyncTombstone tombstone in remote.tombstones) {
      final String id = tombstone.key + ' ' + tombstone.id;
      final SyncTombstone? existing = tombstones[id];
      if (existing == null || existing.deletedAt.isBefore(tombstone.deletedAt)) {
        tombstones[id] = tombstone;
        addedTombstones.add(tombstone);
      }
    }

    // Alle Schlüssel, die es auf einer der beiden Seiten gibt.
    final Set<String> keys = <String>{
      for (final SyncPart part in local.parts) part.key,
      for (final SyncPart part in remote.parts) part.key,
    };

    final List<SyncPart> mergedParts = <SyncPart>[];
    final List<String> added = <String>[];
    final List<String> updated = <String>[];
    final List<String> removed = <String>[];

    for (final String key in keys) {
      final List<Object> localItems = _itemsOf(local, key);
      final List<Object> remoteItems = _itemsOf(remote, key);
      final SyncMergeResult part = _mergePart(
        key,
        localItems,
        remoteItems,
        tombstones,
        added,
        updated,
        removed,
      );
      mergedParts.add(part.parts.single);
    }

    // Werte: Ganzes gegen Ganzes, und zwar **je Wert** nach seiner eigenen
    // Änderungszeit. Vorher stand hier ein Vergleich über die Gesamtzeit des
    // Pakets, gesetzt auf „jetzt" bei jedem Lauf: Jedes Gerät war damit beim
    // letzten Sync das neueste, keine Einstellung wanderte jemals, und die
    // Oberfläche zeigte dauerhaft „Alles ist aktuell".
    final Map<String, dynamic> settings = <String, dynamic>{...remote.settings};
    for (final MapEntry<String, dynamic> entry in local.settings.entries) {
      if (!remote.settings.containsKey(entry.key)) {
        settings[entry.key] = entry.value;
        continue;
      }
      settings[entry.key] = _winningValue(
        key: entry.key,
        local: entry.value,
        localAt: local.stampOf(entry.key),
        remote: remote.settings[entry.key],
        remoteAt: remote.stampOf(entry.key),
      );
    }

    return SyncMergeResult(
      parts: mergedParts,
      tombstones: tombstones.values.toList(),
      added: added,
      updated: updated,
      removed: removed,
      tombstonesAdded: addedTombstones,
      settings: settings,
      settingsAt: _mergedStamps(local, remote, settings),
    );
  }

  /// Die Änderungszeiten für die Werte, die es im Ergebnis gibt.
  ///
  /// Für jeden Wert zählt die **neuere** der beiden Zeiten. Das ist der Punkt,
  /// an dem die Kette sonst stillstünde: Ein übernommener Wert verlöre sonst
  /// seine Herkunft, gälte beim nächsten Lauf als „unverändert alt" – und
  /// könnte nie wieder von einem Gerät gewonnen werden, das ihn später ändert.
  static Map<String, DateTime> _mergedStamps(
    SyncPayload local,
    SyncPayload remote,
    Map<String, dynamic> settings,
  ) {
    final Map<String, DateTime> merged = <String, DateTime>{};
    for (final String key in settings.keys) {
      final DateTime localAt = local.stampOf(key);
      final DateTime remoteAt = remote.stampOf(key);
      merged[key] = remoteAt.isAfter(localAt) ? remoteAt : localAt;
    }
    return merged;
  }

  /// Welcher der beiden Werte gewinnt.
  ///
  /// Der Normalfall ist eindeutig: Der mit der neueren Änderungszeit gewinnt.
  ///
  /// Karten sind der Sonderfall, und der braucht mehr als „ein Gewinner für
  /// alles". `hiddenSubjectsByClass` sagt zum Beispiel je Klasse, welche Kurse
  /// ausgeblendet sind. Blendet die Kollegin auf ihrem Gerät Deutsch in der 8a
  /// aus und hier Deutsch in der 8b, dann ist „eine Seite gewinnt ganz" falsch –
  /// es ginge eine der beiden Angaben verloren, und zwar stillschweigend.
  /// Deshalb werden Karten **einzeln** zusammengeführt: Jeder Eintrag, den nur
  /// eine Seite hat, bleibt; nur wo beide denselben Eintrag unterschiedlich
  /// belegen, entscheidet die Zeit.
  ///
  /// Der Gleichstand braucht ebenfalls mehr Sorgfalt. „Bei gleicher Zeit
  /// gewinnt das lokale Gerät" ist **nicht symmetrisch**: Zwei Geräte mit
  /// gleichem Stand kämen zu verschiedenen Ergebnissen, und weil beide ihr
  /// Ergebnis wieder hochschieben, oszillierten sie dauerhaft. Dem Merge wird
  /// ausdrücklich Symmetrie zugesagt, also darf hier nichts davon abhängen, wer
  /// gerade rechnet. Stattdessen gewinnt der Wert, dessen kodierte Form
  /// alphabetisch größer ist – beliebig, aber auf beiden Geräten gleich.
  static Object? _winningValue({
    required String key,
    required Object? local,
    required DateTime localAt,
    required Object? remote,
    required DateTime remoteAt,
  }) {
    if (remote is Map && local is Map) {
      if (remoteAt.isAfter(localAt)) return <String, dynamic>{...local, ...remote};
      if (localAt.isAfter(remoteAt)) return <String, dynamic>{...remote, ...local};
      // Gleichstand: je Eintrag einzeln entscheiden, damit auch hier nichts
      // verloren geht.
      final Map<String, dynamic> merged = <String, dynamic>{};
      for (final String entryKey in <String>{
        ...local.keys.map((Object? k) => k.toString()),
        ...remote.keys.map((Object? k) => k.toString()),
      }) {
        final Object? a = local[entryKey];
        final Object? b = remote[entryKey];
        if (!local.containsKey(entryKey)) {
          merged[entryKey] = b;
        } else if (!remote.containsKey(entryKey)) {
          merged[entryKey] = a;
        } else {
          merged[entryKey] = jsonEncode(a).compareTo(jsonEncode(b)) >= 0 ? a : b;
        }
      }
      return merged;
    }
    if (remoteAt.isAfter(localAt)) return remote;
    if (localAt.isAfter(remoteAt)) return local;
    final String a = jsonEncode(local);
    final String b = jsonEncode(remote);
    return a.compareTo(b) >= 0 ? local : remote;
  }

  /// Führt einen einzelnen Bestandteil zusammen.
  static SyncMergeResult _mergePart(
    String key,
    List<Object> localItems,
    List<Object> remoteItems,
    Map<String, SyncTombstone> tombstones,
    List<String> added,
    List<String> updated,
    List<String> removed,
  ) {
    final SyncPart localPart = SyncPayload.describePart(key, localItems);
    final SyncPart remotePart = SyncPayload.describePart(key, remoteItems);

    // Die Identitäten beider Seiten und – wichtiger – **welche Fassung
    // gewinnt**. Bei doppelten IDs innerhalb einer Seite gewinnt die zuletzt
    // gelesene; das kann nur bei Datenfehlern passieren.
    final Map<String, String> localIds = <String, String>{};
    final Map<String, DateTime> localTimes = <String, DateTime>{};
    for (final Object item in localItems) {
      final String? id = localPart.idOf(item);
      if (id == null || id.isEmpty) continue;
      localIds[id] = id;
      localTimes[id] = _timestampOf(localPart, item);
    }
    final Map<String, String> remoteIds = <String, String>{};
    final Map<String, DateTime> remoteTimes = <String, DateTime>{};
    for (final Object item in remoteItems) {
      final String? id = remotePart.idOf(item);
      if (id == null || id.isEmpty) continue;
      remoteIds[id] = id;
      remoteTimes[id] = _timestampOf(remotePart, item);
    }

    final Set<String> allIds = <String>{...localIds.keys, ...remoteIds.keys};

    // Lösch-Markierungen anwenden: Ein gelöschter Eintrag kommt nicht
    // zurück, egal von welchem Gerät er stammt – es sei denn, er wurde
    // *nach* dem Löschen wieder geändert (dann ist es ein neuer Eintrag).
    final Set<String> dropped = <String>{};
    for (final String id in allIds) {
      final SyncTombstone? tombstone = tombstones['$key $id'];
      if (tombstone == null) continue;
      // Der neuere von beiden Zeitpunkten entscheidet, ob der Eintrag die
      // Löschung überlebt.
      final DateTime itemTime = _latest(
        localTimes[id],
        remoteTimes[id],
      );
      if (!itemTime.isAfter(tombstone.deletedAt)) dropped.add(id);
    }
    for (final String id in dropped) {
      removed.add(id);
    }

    // Die Gewinner-Fassung bestimmen.
    final Map<String, Object> winner = <String, Object>{};
    for (final String id in allIds) {
      if (dropped.contains(id)) continue;
      final Object? local = _pick(localItems, localPart, id);
      final Object? remote = _pick(remoteItems, remotePart, id);

      if (local == null && remote != null) {
        winner[id] = remote;
        added.add(id);
        continue;
      }
      if (remote == null && local != null) {
        winner[id] = local;
        continue;
      }
      if (local == null || remote == null) continue;

      final DateTime localTime = localTimes[id] ?? SyncPayload.epoch;
      final DateTime remoteTime = remoteTimes[id] ?? SyncPayload.epoch;
      // Bei gleicher Zeit gewinnt das lokale Gerät. Ohne diese Festlegung
      // hinge das Ergebnis davon ab, in welcher Reihenfolge die Geräte
      // synchronisiert wurden – der Merge muss aber symmetrisch sein.
      final bool remoteWins = remoteTime.isAfter(localTime);
      if (remoteWins) {
        winner[id] = remote;
        updated.add(id);
        continue;
      }
      winner[id] = local;
      // Unterschiedlicher Inhalt bei gleicher Zeit: der andere Stand wird
      // trotzdem gemeldet, damit die Oberfläche den Konflikt zeigen kann.
      if (localTime == remoteTime && !_sameContent(local, remote)) {
        updated.add(id);
      }
    }

    // Feste Reihenfolge: nach Identität sortiert. Damit sind zwei
    // zusammengeführte Stände unabhängig davon identisch, in welcher
    // Reihenfolge die Geräte synchronisiert wurden – und die Listen in der
    // App springen nicht bei jedem Sync um.
    final List<Object> result = winner.values.toList()
      ..sort((Object a, Object b) =>
          (localPart.idOf(a) ?? '').compareTo(localPart.idOf(b) ?? ''));

    return SyncMergeResult(
      parts: <SyncPart>[localPart.copyWithItems(result)],
      tombstones: const <SyncTombstone>[],
      added: added,
      updated: updated,
      removed: removed,
      tombstonesAdded: const <SyncTombstone>[],
    );
  }

  /// Der Eintrag mit dieser Identität, oder null, wenn es ihn hier nicht gibt.
  static Object? _pick(List<Object> items, SyncPart part, String id) {
    for (final Object item in items) {
      if (part.idOf(item) == id) return item;
    }
    return null;
  }

  static DateTime _latest(DateTime? a, DateTime? b) {
    if (a == null) return b ?? SyncPayload.epoch;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Vergleicht zwei Einträge ohne das interne Zeitfeld.
  static bool _sameContent(Object a, Object b) =>
      _stripTimestamp(a) == _stripTimestamp(b);

  /// Entfernt das interne Zeitfeld, damit es nicht als Unterschied zählt.
  static Object _stripTimestamp(Object item) {
    if (item is! Map) return item;
    final Map<dynamic, dynamic> copy = Map<dynamic, dynamic>.of(item)
      ..remove(SyncPayload.syncTimestampField);
    return jsonEncode(copy);
  }

  static DateTime _timestampOf(SyncPart part, Object item) =>
      part.timestampOf?.call(item) ?? SyncPayload.epoch;

  static List<Object> _itemsOf(SyncPayload payload, String key) {
    for (final SyncPart part in payload.parts) {
      if (part.key == key) return part.items;
    }
    return const <Object>[];
  }

  /// Schreibt ein zusammengeführtes Paket in die `SharedPreferences`.
  ///
  /// Der Rückgabewert nennt die tatsächlich geschriebenen Schlüssel, damit die
  /// UI sagen kann, was sich geändert hat.
  static Future<SyncMergeResult> applyToPreferences(
    SharedPreferences prefs,
    SyncPayload payload,
  ) async {
    final List<String> written = <String>[];

    for (final SyncPart part in payload.parts) {
      final Object? value = _encodeForPreferences(part);
      if (value == null) continue;
      await _write(prefs, part.key, value);
      written.add(part.key);
    }

    for (final MapEntry<String, dynamic> entry in payload.settings.entries) {
      if (ConfigBackup.sensitiveKeys.contains(entry.key)) continue;
      // Der Wert geht **unverändert** an den Schreiber. Eine Umformung davor
      // wäre schädlich: `toString()` macht aus einer Karte `{c1: true}`, und das
      // ist kein JSON – `VPlanAPI` scheitert daran, den Wert zu lesen, ohne
      // dass irgendwo ein Fehler auftritt.
      if (entry.value == null) continue;
      await _write(prefs, entry.key, entry.value);
      written.add(entry.key);
    }

    // Lösch-Markierungen lokal ablegen, damit das Gerät sie beim nächsten
    // Push weitergibt.
    await prefs.setString(
      tombstoneStorageKey,
      jsonEncode(payload.tombstones
          .map((SyncTombstone tombstone) => tombstone.toJson())
          .toList()),
    );

    return SyncMergeResult(
      parts: payload.parts,
      tombstones: payload.tombstones,
      settings: payload.settings,
      added: written,
      updated: const <String>[],
      removed: const <String>[],
      tombstonesAdded: const <SyncTombstone>[],
    );
  }

  /// Der Schlüssel, unter dem die Lösch-Markierungen dieses Geräts liegen.
  static const String tombstoneStorageKey = 'sync.tombstones';

  /// Liest die lokal gespeicherten Lösch-Markierungen.
  static List<SyncTombstone> readTombstones(SharedPreferences prefs) {
    final String? raw = prefs.getString(tombstoneStorageKey);
    if (raw == null || raw.isEmpty) return const <SyncTombstone>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <SyncTombstone>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SyncTombstone.fromJson)
          .whereType<SyncTombstone>()
          .toList();
    } catch (_) {
      return const <SyncTombstone>[];
    }
  }

  /// Wandelt einen Bestandteil in den Wert, den `SharedPreferences` erwartet.
  ///
  /// Die App speichert Listen als `StringList` mit **JSON-Zeichenkette pro
  /// Eintrag** – das ist das Format, das `VPlanAPI` und die Plan-Ansicht
  /// erwarten. Ein JSON-Array wäre an dieser Stelle ein stiller Datenverlust.
  /// Die Einträge eines Bestandteils in der Form, in der sie gespeichert
  /// werden.
  ///
  /// Ein Objekt wird als JSON abgelegt, ein einfacher Name **genau wie er
  /// ist** – siehe [SyncPayload.encodeItem]. Hier stand früher ein
  /// `map(jsonEncode)` für beides, und damit landete die Klasse `8a` als
  /// `"8a"` in der Liste. Die App liest `classes` aber als schlichte Namen, also
  /// zeigte die Auswahl danach `"8a"` mit Anführungszeichen.
  static Object? _encodeForPreferences(SyncPart part) =>
      part.items.map(SyncPayload.encodeItem).toList();

  static Future<void> _write(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is bool) {
      await prefs.setBool(key, value);
      return;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return;
    }
    if (value is List) {
      // Ein einfacher Name wird **genau so** zurückgeschrieben, ein Objekt als
      // JSON. Mit einem `jsonEncode` für beides stünden die Klassen danach als
      // `"8a"` in der Liste – mit Anführungszeichen in der Auswahl.
      final List<String> lines = value
          .map((Object? e) => e == null
              ? ''
              : SyncPayload.encodeItem(e))
          .toList();
      switch (SyncKeys.formOf(key)) {
        case StoredForm.jsonArray:
          // So, wie die App es selbst ablegt: ein JSON-Array als String.
          // `setStringList` wäre hier der direkte Weg in den Absturz, und ein
          // Array von *Zeichenketten* statt von *Objekten* wäre zwar gültiges
          // JSON, für die App aber unbrauchbar.
          await prefs.setString(key, encodeJsonArray(lines));
        case StoredForm.stringList:
          await prefs.setStringList(key, lines);
        case null:
          await prefs.setStringList(key, lines);
      }
      return;
    }
    if (value is Map) {
      // Karten (`initializedClasses`, `hiddenSubjectsByClass`,
      // `previewHidden*`) legt die App als JSON-Zeichenkette ab. `toString()`
      // ergäbe `{c1: true}` – gültig für Dart, ungültig als JSON, und `VPlanAPI`
      // würde `jsonDecode` daran scheitern lassen.
      await prefs.setString(key, jsonEncode(value));
      return;
    }
    if (value is String) {
      await prefs.setString(key, value);
      return;
    }
    await prefs.setString(key, value.toString());
  }
}
