import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncMerge.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Die **Reihenfolge** der Klassen muss mitwandern.
///
/// Ein Gerät, auf dem die Klassen in der Reihenfolge `XYZ, ABC` angelegt
/// wurden, hat sie nach einem Sync in der Reihenfolge `ABC, XYZ` bekommen –
/// alphabetisch, weil der Merge nach Identität sortiert hat. Die Anordnung ist
/// in der App aber benutzersichtbar: Sie ist das, woran sich jemand gewöhnt
/// hat, und sie ist bei den Klassen nicht nur Kosmetik, weil die Reihenfolge in
/// Listen und Auswahlen wiederkehrt.
///
/// Die Reihenfolge gehört zum **Bestandteil**, nicht zum einzelnen Eintrag:
/// „XYZ vor ABC" ist eine Aussage über die Liste und aus keinem Eintrag
/// errechenbar. Sie wird deshalb wie ein Wert behandelt – wer sie zuletzt
/// geändert hat, gibt sie vor.
void main() {
  /// Baut einen Bestandteil aus einfachen Namen, wie die App sie ablegt.
  SyncPart classesOf(
    List<String> names, {
    DateTime? orderAt,
  }) =>
      SyncPayload.describePart('classes', names.cast<Object>(), orderAt: orderAt);

  List<String> idsOf(SyncPart part) => part.identityOrder;

  group('Die Reihenfolge bleibt, wie sie ist', () {
    test('eine umgeordnete Liste wird nicht alphabetisch sortiert', () {
      // Das war der Fehler: `XYZ, ABC` wurde zu `ABC, XYZ`.
      final SyncPart a = classesOf(<String>['XYZ', 'ABC'], orderAt: DateTime.utc(2026, 10, 1));
      final SyncPart b = classesOf(<String>['ABC', 'XYZ'], orderAt: DateTime.utc(2026, 10, 1));

      final SyncMergeResult ergebnis = SyncMerge.merge(
        SyncPayload(
          parts: <SyncPart>[a],
          tombstones: const <SyncTombstone>[],
          settings: const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
        SyncPayload(
          parts: <SyncPart>[b],
          tombstones: const <SyncTombstone>[],
          settings: const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      );

      // `b` hat `ABC, XYZ` – alphabetisch – und ist genauso alt. Der Merge muss
      // sich für eine der beiden Anordnungen entscheiden, aber **nicht** für
      // eine dritte, die vorher gar niemand hatte.
      final List<String> ergebnisIds = idsOf(ergebnis.parts.single);
      expect(
        ergebnisIds,
        anyOf(
          equals(<String>['XYZ', 'ABC']),
          equals(<String>['ABC', 'XYZ']),
        ),
        reason: 'eine der beiden Anordnungen muss gelten, nicht eine dritte, '
            'die vorher niemand hatte',
      );
    });

    test('die Reihenfolge wandert auf ein leeres Gerät', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SyncPayload fremd = SyncPayload(
        parts: <SyncPart>[classesOf(<String>['XYZ', 'ABC'],
            orderAt: DateTime.utc(2026, 10, 1))],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final SyncPayload eigen = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart(
              'classes', SyncDataReader.readItems(prefs, 'classes')),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );

      final SyncMergeResult ergebnis = SyncMerge.merge(eigen, fremd);
      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: ergebnis.parts,
          tombstones: ergebnis.tombstones,
          settings: ergebnis.settings ?? const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      );

      expect(prefs.getStringList('classes'), <String>['XYZ', 'ABC'],
          reason: 'die Reihenfolge des anderen Geräts ist nicht angekommen');
    });
  });

  group('Wer die Anordnung zuletzt geändert hat, gibt sie vor', () {
    test('das neuere Gerät entscheidet', () {
      final SyncPart a = classesOf(<String>['XYZ', 'ABC'],
          orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart b = classesOf(<String>['ABC', 'XYZ'],
          orderAt: DateTime.utc(2026, 10, 1, 11));

      expect(
        idsOf(SyncMerge.merge(_wrap(a), _wrap(b)).parts.single),
        <String>['ABC', 'XYZ'],
      );
      // Und in der Gegenrichtung dasselbe – die Reihenfolge ist keine
      // Einbahnstraße.
      expect(
        idsOf(SyncMerge.merge(_wrap(b), _wrap(a)).parts.single),
        <String>['ABC', 'XYZ'],
      );
    });

    test('und nicht das Gerät, das nur zufällig später dran war', () {
      // Beide haben ihre Reihenfolge unverändert gelassen – es hat also
      // niemand umsortiert. Wer hier gewinnt, darf nicht davon abhängen, wer
      // gerade rechnet.
      final SyncPart a = classesOf(<String>['ABC', 'XYZ'],
          orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart b = classesOf(<String>['XYZ', 'ABC'],
          orderAt: DateTime.utc(2026, 10, 1, 10));

      expect(
        idsOf(SyncMerge.merge(_wrap(a), _wrap(b)).parts.single),
        idsOf(SyncMerge.merge(_wrap(b), _wrap(a)).parts.single),
        reason: 'die beiden Geräte sind sich uneinig und würden endlos tauschen',
      );
    });
  });

  group('Neue Einträge behalten ihren Platz', () {
    test('eine nur auf der einen Seite stehende Klasse wird nicht ans Ende '
        'geworfen', () {
      // A hat [XYZ, ABC], B hat [ABC, 9a, XYZ] und hat zuletzt umsortiert.
      // Die `9a` gehört in die Mitte – nicht ans Ende der Liste.
      final SyncPart a =
          classesOf(<String>['XYZ', 'ABC'], orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart b = classesOf(<String>['ABC', '9a', 'XYZ'],
          orderAt: DateTime.utc(2026, 10, 1, 11));

      final List<String> ergebnis =
          idsOf(SyncMerge.merge(_wrap(a), _wrap(b)).parts.single);
      expect(ergebnis, containsAll(<String>['XYZ', 'ABC', '9a']));
      expect(ergebnis.indexOf('9a'), lessThan(ergebnis.indexOf('XYZ')),
          reason: 'die neue Klasse steht nicht am Ende: $ergebnis');
    });

    test('das Ergebnis ist unabhängig von der Reihenfolge der Geräte', () {
      final SyncPart a = classesOf(<String>['XYZ', 'ABC', '7c'],
          orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPart b = classesOf(<String>['ABC', '9a', 'XYZ'],
          orderAt: DateTime.utc(2026, 10, 1, 11));

      expect(
        idsOf(SyncMerge.merge(_wrap(a), _wrap(b)).parts.single),
        idsOf(SyncMerge.merge(_wrap(b), _wrap(a)).parts.single),
      );
    });
  });

  group('Ohne Zeitangabe gilt der Anfang der Zeitachse', () {
    test('ein Paket ohne orderAt ist nicht „frisch"', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncPart a = SyncPayload.describePart('classes', <Object>[]);
      expect(a.orderAt, SyncPayload.epoch);
    });

    test('die Reihenfolge überlebt die Runde durch den Speicher', () async {
      // Der ganze Weg: gesammelt, verschlüsselt, entschlüsselt, zusammengeführt.
      // Bricht die Reihenfolge auf einer dieser Stufen, sieht man es hier.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['XYZ', 'ABC'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Object> items = SyncDataReader.readItems(prefs, 'classes');
      final SyncPart original =
          SyncPayload.describePart('classes', items, orderAt: DateTime.utc(2026, 10, 1));

      final Map<String, dynamic> json = SyncPayload(
        parts: <SyncPart>[original],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      ).toJson();

      final SyncPayload wieder = SyncPayload.fromJson(json);
      expect(wieder.parts.single.identityOrder, <String>['XYZ', 'ABC'],
          reason: 'die Reihenfolge ist auf dem Draht verloren gegangen');
      expect(wieder.parts.single.orderAt, DateTime.utc(2026, 10, 1));
      // Und die Zeit gehört nicht in die Identität eines Eintrags.
      expect(jsonEncode(items.first), isNot(contains('orderAt')));
    });
  });
}

SyncPayload _wrap(SyncPart part) => SyncPayload(
      parts: <SyncPart>[part],
      tombstones: const <SyncTombstone>[],
      settings: const <String, dynamic>{},
      updatedAt: DateTime.utc(2026, 10, 1),
    );
