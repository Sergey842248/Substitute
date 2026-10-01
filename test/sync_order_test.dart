import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncMerge.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Die **Reihenfolge** muss mitwandern – dort, wo sie eine ist.
///
/// Für die **Klassen** gilt das nicht mehr: Sie sind immer sortiert, weil es
/// dafür genau eine richtige Antwort gibt – `06.2` vor `11`. Siehe
/// [sync_class_order_test.dart].
///
/// Die Personenliste ist der andere Fall, und der ist ein echter: Sie ist
/// benutzersichtbar, und jemand kann sie von Hand in eine bestimmte Reihenfolge
/// gebracht haben. Ihre Anordnung wandert deshalb mit, wer sie zuletzt geändert
/// hat.
///
/// Vorher wurde im Merge schlicht nach Identität sortiert. Das war eindeutig,
/// machte die Reihenfolge aber unbrauchbar – und für die Klassen war es ohnehin
/// die falsche Antwort.
void main() {
  const String key = 'persons';

  Map<String, dynamic> person(String id) =>
      <String, dynamic>{'id': id, 'name': 'Person $id'};

  SyncPart partOf(List<String> ids, {DateTime? orderAt}) =>
      SyncPayload.describePart(
        key,
        ids.map(person).toList().cast<Object>(),
        orderAt: orderAt,
      );

  List<String> orderOf(SyncPart part) => <String>[
        for (final Object item in part.items) (item as Map)['id'].toString(),
      ];

  SyncPayload wrapped(SyncPart part) => SyncPayload(
        parts: <SyncPart>[part],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );

  group('Die Reihenfolge bleibt, wie sie ist', () {
    test('eine umgeordnete Liste wird nicht alphabetisch sortiert', () {
      // Vorher stand hier `ABC, XYZ` nach dem Sync – alphabetisch, weil
      // pauschal nach Identität sortiert wurde.
      final SyncMergeResult a = SyncMerge.merge(
        wrapped(partOf(<String>['XYZ', 'ABC'], orderAt: DateTime.utc(2026, 10, 1))),
        wrapped(partOf(<String>['ABC', 'XYZ'], orderAt: DateTime.utc(2026, 10, 1))),
      );
      final List<String> ids = orderOf(a.parts.single);
      expect(ids, hasLength(2));
      expect(
        ids,
        anyOf(
          equals(<String>['XYZ', 'ABC']),
          equals(<String>['ABC', 'XYZ']),
        ),
        reason: 'eine der beiden Anordnungen muss gelten, nicht eine dritte',
      );
    });

    test('die Reihenfolge wandert auf ein Gerät, das noch nichts hat',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SyncMergeResult ergebnis = SyncMerge.merge(
        wrapped(SyncPayload.describePart(
            key, SyncDataReader.readItems(prefs, key))),
        wrapped(partOf(<String>['XYZ', 'ABC'], orderAt: DateTime.utc(2026, 10, 1))),
      );
      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: ergebnis.parts,
          tombstones: ergebnis.tombstones,
          settings: ergebnis.settings ?? const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      );

      final List<String> ids = SyncDataReader.readItems(prefs, key)
          .map((Object i) => (i as Map)['id'].toString())
          .toList();
      expect(ids, <String>['XYZ', 'ABC'],
          reason: 'die Reihenfolge des anderen Geräts ist nicht angekommen');
    });
  });

  group('Wer die Anordnung zuletzt geändert hat, gibt sie vor', () {
    test('das neuere Gerät entscheidet', () {
      final SyncPart frueh = partOf(<String>['XYZ', 'ABC'],
          orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart spaet = partOf(<String>['ABC', 'XYZ'],
          orderAt: DateTime.utc(2026, 10, 1, 11));

      expect(orderOf(SyncMerge.merge(wrapped(frueh), wrapped(spaet)).parts.single),
          <String>['ABC', 'XYZ']);
      // Und in der Gegenrichtung dasselbe – die Reihenfolge ist keine
      // Einbahnstraße.
      expect(orderOf(SyncMerge.merge(wrapped(spaet), wrapped(frueh)).parts.single),
          <String>['ABC', 'XYZ']);
    });

    test('und nicht das Gerät, das nur zufällig später dran war', () {
      // Beide haben ihre Reihenfolge unverändert gelassen – niemand hat
      // umsortiert. Wer hier gewinnt, darf nicht davon abhängen, wer gerade
      // rechnet, sonst drehen sie sich endlos.
      final SyncPart a =
          partOf(<String>['ABC', 'XYZ'], orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart b =
          partOf(<String>['XYZ', 'ABC'], orderAt: DateTime.utc(2026, 10, 1, 10));

      expect(orderOf(SyncMerge.merge(wrapped(a), wrapped(b)).parts.single),
          orderOf(SyncMerge.merge(wrapped(b), wrapped(a)).parts.single));
    });
  });

  group('Neue Einträge behalten ihren Platz', () {
    test('eine nur auf der einen Seite stehende Person wird nicht ans Ende '
        'geworfen', () {
      final SyncPart a = partOf(<String>['XYZ', 'ABC'],
          orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart b = partOf(<String>['ABC', 'N', 'XYZ'],
          orderAt: DateTime.utc(2026, 10, 1, 11));

      final List<String> ergebnis =
          orderOf(SyncMerge.merge(wrapped(a), wrapped(b)).parts.single);
      expect(ergebnis, containsAll(<String>['XYZ', 'ABC', 'N']));
      expect(ergebnis.indexOf('N'), lessThan(ergebnis.indexOf('XYZ')),
          reason: 'die neue Person steht nicht am Ende: $ergebnis');
    });

    test('das Ergebnis ist unabhängig von der Reihenfolge der Geräte', () {
      final SyncPart a = partOf(<String>['XYZ', 'ABC', 'P'],
          orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart b = partOf(<String>['ABC', 'N', 'XYZ'],
          orderAt: DateTime.utc(2026, 10, 1, 11));

      expect(orderOf(SyncMerge.merge(wrapped(a), wrapped(b)).parts.single),
          orderOf(SyncMerge.merge(wrapped(b), wrapped(a)).parts.single));
    });
  });

  group('Ohne Zeitangabe gilt der Anfang der Zeitachse', () {
    test('ein Paket ohne orderAt ist nicht „frisch"', () {
      expect(
        SyncPayload.describePart(key, <Object>[]).orderAt,
        SyncPayload.epoch,
      );
    });

    test('die Reihenfolge überlebt die Runde durch den Speicher', () async {
      // Der ganze Weg: gesammelt, serialisiert, eingelesen. Bricht die
      // Reihenfolge auf einer dieser Stufen, sieht man es hier.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': <String>[
          jsonEncode(<String, dynamic>{'id': 'X', 'name': 'X'}),
          jsonEncode(<String, dynamic>{'id': 'A', 'name': 'A'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncPart original = SyncPayload.describePart(
        key,
        SyncDataReader.readItems(prefs, key),
        orderAt: DateTime.utc(2026, 10, 1),
      );

      final Map<String, dynamic> json = SyncPayload(
        parts: <SyncPart>[original],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      ).toJson();

      final SyncPayload wieder = SyncPayload.fromJson(json);
      expect(orderOf(wieder.parts.single), <String>['X', 'A'],
          reason: 'die Reihenfolge ist auf dem Draht verloren gegangen');
      expect(wieder.parts.single.orderAt, DateTime.utc(2026, 10, 1));
    });
  });
}
