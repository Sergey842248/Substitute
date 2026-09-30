import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ConfigBackup.dart';
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
      final List<Map<String, dynamic>> localItems = _itemsOf(local, key);
      final List<Map<String, dynamic>> remoteItems = _itemsOf(remote, key);
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

    // Schlüssel/Wert-Paare: bei einem Konflikt gewinnt die Seite mit der
    // neueren Gesamtzeit. Bei gleicher Zeit gewinnt das lokale Gerät – das
    // hält das Ergebnis stabil, wenn zwei Geräte gleichzeitig synchronisieren.
    final Map<String, dynamic> settings = <String, dynamic>{...remote.settings};
    final bool remoteIsNewer = remote.updatedAt.isAfter(local.updatedAt);
    for (final MapEntry<String, dynamic> entry in local.settings.entries) {
      if (!remote.settings.containsKey(entry.key)) {
        settings[entry.key] = entry.value;
      } else if (!remoteIsNewer) {
        settings[entry.key] = entry.value;
      }
    }

    return SyncMergeResult(
      parts: mergedParts,
      tombstones: tombstones.values.toList(),
      added: added,
      updated: updated,
      removed: removed,
      tombstonesAdded: addedTombstones,
      settings: settings,
    );
  }

  /// Führt einen einzelnen Bestandteil zusammen.
  static SyncMergeResult _mergePart(
    String key,
    List<Map<String, dynamic>> localItems,
    List<Map<String, dynamic>> remoteItems,
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
    for (final Map<String, dynamic> item in localItems) {
      final String? id = localPart.idOf(item);
      if (id == null || id.isEmpty) continue;
      localIds[id] = id;
      localTimes[id] = _timestampOf(localPart, item);
    }
    final Map<String, String> remoteIds = <String, String>{};
    final Map<String, DateTime> remoteTimes = <String, DateTime>{};
    for (final Map<String, dynamic> item in remoteItems) {
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
    final Map<String, Map<String, dynamic>> winner = <String, Map<String, dynamic>>{};
    for (final String id in allIds) {
      if (dropped.contains(id)) continue;
      final Map<String, dynamic>? local = _pick(localItems, localPart, id);
      final Map<String, dynamic>? remote = _pick(remoteItems, remotePart, id);

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
    final List<Map<String, dynamic>> result = winner.values.toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
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
  static Map<String, dynamic>? _pick(
    List<Map<String, dynamic>> items,
    SyncPart part,
    String id,
  ) {
    for (final Map<String, dynamic> item in items) {
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
  static bool _sameContent(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) =>
      jsonEncode(_stripTimestamp(a)) == jsonEncode(_stripTimestamp(b));

  static Map<String, dynamic> _stripTimestamp(Map<String, dynamic> item) =>
      Map<String, dynamic>.of(item)..remove(SyncPayload.syncTimestampField);

  static DateTime _timestampOf(SyncPart part, Map<String, dynamic> item) =>
      part.timestampOf?.call(item) ?? SyncPayload.epoch;

  static List<Map<String, dynamic>> _itemsOf(SyncPayload payload, String key) {
    for (final SyncPart part in payload.parts) {
      if (part.key == key) return part.items;
    }
    return const <Map<String, dynamic>>[];
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
      final Object? value = _plainValue(entry.value);
      if (value == null) continue;
      await _write(prefs, entry.key, value);
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
  static Object? _encodeForPreferences(SyncPart part) {
    if (ConfigBackup.isCachedPlansKey(part.key)) {
      return part.items.map(jsonEncode).toList();
    }
    return part.items.map(jsonEncode).toList();
  }

  /// Wandelt einen einfachen Wert in etwas, das `setString` annimmt.
  static Object? _plainValue(Object? value) {
    if (value == null) return null;
    if (value is bool || value is int || value is double) return value;
    if (value is List) return value.map((Object? e) => e.toString()).toList();
    return value.toString();
  }

  static Future<void> _write(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List) {
      await prefs.setStringList(
          key, value.map((Object? e) => e.toString()).toList());
    } else {
      await prefs.setString(key, value.toString());
    }
  }
}
