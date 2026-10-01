import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncMerge.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Die Klassen einer Sync-Kette.
///
/// Der Anlass ist eine Meldung: Beim Beitritt auf einem zweiten Gerät bleiben
/// die ausgewählten Klassen lokal und kommen nicht an. Die Ursache ist eine
/// Annahme über das Format, die nicht dem entspricht, was die App schreibt.
///
/// Die App schreibt beim Tippen auf „Klasse auswählen" **kein** JSON-Objekt,
/// sondern den Klassenamen selbst:
///
/// ```dart
/// _classes.add(className);                                       // '8a'
/// instance.setStringList(SchoolStorage.scopedKey(prefs, 'classes'), _classes);
/// ```
///
/// Der Leser zerlegte aber jede Zeile mit `jsonDecode` und ließ nur Zeilen
/// durch, die ein **Objekt** ergaben. Bei `8a` scheitert `jsonDecode` – die
/// Zeile fiel kommentarlos weg. Der Sync übertrug damit nie eine Klasse,
/// meldete aber Erfolg, und die Oberfläche zeigte dauerhaft „Alles ist
/// aktuell". Genau das ist gemeldet worden.
///
/// Betroffen war alles, was als schlichter Name gespeichert wird, nicht nur
/// die Klassen: auch die Räume in `cachedRooms`.
void main() {
  /// So legt die App die Klassen ab – ohne JSON, als reine Zeichenketten.
  const List<String> klassenVonDerApp = <String>['8a', '8b'];

  List<Object> itemsOf(SharedPreferences prefs, String key) =>
      SyncDataReader.readItems(prefs, key);

  group('Der Leser nimmt schlichte Namen an', () {
    test('eine Klasse `8a` ist kein JSON und wird trotzdem gelesen', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': klassenVonDerApp,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final List<Object> items = itemsOf(prefs, 'classes');
      expect(items, hasLength(2), reason: 'die Klassen wurden verworfen');
      expect(items, <Object>['8a', '8b']);
    });

    test('eine Zahl bleibt Text', () async {
      // `123` ist gültiges JSON. Als **Zeichenkette** gespeichert – wie die
      // App es tut – muss es aber `123` bleiben und nicht zur Zahl werden.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['123', '8a'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Object> items = itemsOf(prefs, 'classes');
      expect(items, <Object>['123', '8a']);
    });

    test('und die Zeile kommt genauso wieder zurück', () async {
      // Ohne das stünde in der Liste die Zeichenkette `"8a"` – mit Anführungszeichen,
      // mit Anführungszeichen – die Klassenauswahl zeigt sie dann so.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': klassenVonDerApp,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncPayload payload = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', itemsOf(prefs, 'classes')),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      await SyncMerge.applyToPreferences(prefs, payload);
      expect(prefs.getStringList('classes'), <String>['8a', '8b']);
    });

    test('Objekte werden weiterhin dekodiert', () async {
      // Personen und Pläne sind echte JSON-Objekte – die dürfen nicht zu
      // Zeichenketten verkommen.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'Hans'},
        ]),
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Plan'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(itemsOf(prefs, 'persons').single, isA<Map<String, dynamic>>());
      expect(itemsOf(prefs, 'offlineVPData').single, isA<Map<String, dynamic>>());
      // Und sie werden auch als Objekte zurückgeschrieben.
      final SyncPayload payload = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('persons', itemsOf(prefs, 'persons')),
          SyncPayload.describePart(
              'offlineVPData', itemsOf(prefs, 'offlineVPData')),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      await SyncMerge.applyToPreferences(prefs, payload);
      final List<dynamic> persons =
          jsonDecode(prefs.getString('persons')!) as List<dynamic>;
      expect(persons.single, isA<Map<String, dynamic>>(),
          reason: 'als Zeichenkette geschrieben, kann die App sie nicht lesen');
    });
  });

  group('Klassen werden zusammengeführt', () {
    test('die Namen selbst sind die Identität', () {
      final SyncPayload part = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', <Object>['8a', '8b']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      expect(part.parts.single.idOf('8a'), '8a');
      expect(part.parts.single.idOf('8b'), '8b');
    });

    test('eine auf beiden Geräten vorhandene Klasse bleibt einmal', () {
      // Ohne diese Regel wäre jeder Name auf beiden Geräten ein eigener
      // Eintrag, und nach dem Sync stünde jede Klasse doppelt in der Liste.
      final SyncPayload a = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', <Object>['8a', '8b']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final SyncPayload b = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', <Object>['8a', '8c']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );

      final List<Object> merged = SyncMerge.merge(a, b).parts.single.items;
      expect(merged, hasLength(3), reason: 'eine Klasse steht doppelt drin');
      expect(merged, containsAll(<Object>['8a', '8b', '8c']));
    });

    test('die Klassen des einen Geräts kommen beim anderen an', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['9a'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SyncPayload fremd = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', <Object>['8a', '8b']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final SyncPayload eigen = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', itemsOf(prefs, 'classes')),
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

      final List<String> angekommen = prefs.getStringList('classes') ?? const <String>[];
      expect(angekommen, containsAll(<String>['8a', '8b', '9a']),
          reason: 'die Klassen des anderen Geräts sind nicht angekommen');
      // Die beiden fremden Klassen stehen in **ihrer** Reihenfolge. Vorher
      // wurde hier alphabetisch sortiert, und die Anordnung in der App ist
      // benutzersichtbar.
      expect(angekommen.indexOf('8a'), lessThan(angekommen.indexOf('8b')),
          reason: 'die Reihenfolge der fremden Klassen ist zerschlagen: $angekommen');
    });
  });

  group('Die Formangaben stimmen mit der App überein', () {
    test('jeder Bestandteil hat eine Form, jede Karte keine', () {
      // Ein Eintrag mit falscher Form wird beim Start der App zum Absturz
      // führen, weil `VPlanAPI` typisierte Getter benutzt.
      for (final String key in SyncKeys.itemKeys) {
        expect(SyncKeys.formOf(key), isNotNull, reason: '$key fehlt in dataKeyForms');
      }
      // Karten werden als JSON-Zeichenkette abgelegt; für sie gibt es keine
      // Formangabe, weil der Schreiber sie immer als Objekt erkennt.
      for (final String key in SyncKeys.mapKeys) {
        expect(SyncKeys.itemKeys.contains(key), isFalse,
            reason: '$key ist eine Karte und zugleich Bestandteil');
      }
    });

    test('classNames ist eine Karte, kein Array', () {
      // `VPlanAPI._decodeClassNames` liest `jsonDecode(data) as Map` – es ist
      // also eine Karte `{classId: eigenerName}`. Als Array eingestuft wurde
      // sie nie gelesen, und ein Import hätte sie als Liste überschrieben.
      expect(SyncKeys.mapKeys, contains('classNames'));
      expect(SyncKeys.itemKeys, isNot(contains('classNames')));
    });
  });
}
