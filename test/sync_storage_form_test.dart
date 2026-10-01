import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';
import 'package:substitute/services/sync/SyncPayload.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncMerge.dart';

/// Der Zustand, der die App unstartbar gemacht hat.
///
/// `VPlanAPI.loadDisplayCache` liest `persons` mit `getString`. Ein Sync hatte
/// den Schlüssel als `StringList` zurückgeschrieben. `getString` wirft dafür
/// eine `TypeError` statt `null` zu liefern, `main()` brach ab, `runApp` wurde
/// nie erreicht – und weil der Schlüssel weiterhin als Liste dastand, war das
/// **dauerhaft**: jeder Start endete an derselben Stelle.
///
/// Zwei Dinge müssen also stimmen, und diese Tests halten beide fest:
///
/// 1. Ein Sync **schreibt nie um** (der Schreiber).
/// 2. Ein Sync **repariert**, was ein alter Stand kaputt gemacht hat (der
///    Leser) – sonst bliebe ein bereits beschädigtes Gerät für immer tot.
void main() {
  /// Die Personen, so wie die App sie ablegt.
  List<String> personLines() => <String>[
        jsonEncode(<String, dynamic>{'id': '1', 'name': 'Hans'}),
        jsonEncode(<String, dynamic>{'id': '2', 'name': 'Petra'}),
      ];

  Future<SharedPreferences> prefsWith(String key, Object value) async {
    SharedPreferences.setMockInitialValues(<String, Object>{key: value});
    return SharedPreferences.getInstance();
  }

  group('Der Sync darf die Speicherform nicht ändern', () {
    test('schreibt JSON-Schlüssel als JSON-Zeichenkette', () async {
      // `persons` wird von `VPlanAPI` als String erwartet. Käme es als
      // StringList zurück, starte die App nicht mehr.
      final SharedPreferences prefs =
          await prefsWith('persons', jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'Hans'},
      ]));

      await SyncMerge.applyToPreferences(
        prefs,
        _payload(<String, dynamic>{
          'persons': <Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'name': 'Hans'},
            <String, dynamic>{'id': '2', 'name': 'Petra'},
          ],
        }),
      );

      final String? raw = prefs.getString('persons');
      expect(raw, isNotNull,
          reason: 'als Liste zurückgekommen – das startet die App nicht mehr');
      final List<dynamic> decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded.length, 2);
      expect((decoded.first as Map)['name'], 'Hans');
    });

    test('schreibt Listen-Schlüssel als StringList', () async {
      final SharedPreferences prefs = await prefsWith(
          'offlineVPData', <String>[jsonEncode(<String, dynamic>{'date': 'd1'})]);

      await SyncMerge.applyToPreferences(
        prefs,
        _payload(<String, dynamic>{
          'offlineVPData': <Map<String, dynamic>>[
            <String, dynamic>{'date': 'd1', 'name': 'Plan'},
          ],
        }),
      );

      expect(prefs.getStringList('offlineVPData'), hasLength(1));
    });

    test('schreibt auch dann in die richtige Form, wenn nichts lokal liegt',
        () async {
      // Ein frisches Gerät hat den Schlüssel noch nie gesehen. Es gibt nichts,
      // womit sich die Form erraten ließe – also muss die Angabe aus
      // `SyncKeys.dataKeyForms` kommen, sonst stirbt dieses Gerät beim ersten
      // Sync.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await SyncMerge.applyToPreferences(
        prefs,
        _payload(<String, dynamic>{
          'persons': <Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'name': 'Hans'},
          ],
        }),
      );

      expect(() => prefs.getString('persons'), returnsNormally);
      expect(() => prefs.getStringList('persons'), throwsA(isA<TypeError>()),
          reason: 'die Liste wäre der Absturz beim Start');
    });

    test('jeder Daten-Schlüssel hat eine angegebene Form', () {
      // Sonst fällt ein Schlüssel stillschweigend auf das Typablehen zurück
      // und wird zur StringList – und damit zur Falle.
      for (final String key in SyncKeys.dataKeys) {
        expect(SyncKeys.formOf(key), isNotNull,
            reason: '$key steht in dataKeys, hat aber keine Form');
      }
    });
  });

  group('Der Leser repariert, was ein alter Stand kaputt gemacht hat', () {
    test('eine Liste unter einem JSON-Schlüssel wird zurückverwandelt',
        () async {
      // Genau der Zustand auf dem Gerät, über das gemeldet wurde.
      final SharedPreferences prefs =
          await prefsWith('persons', personLines());

      // Ohne Reparatur wäre das der Endzustand: `getString` wirft, die App
      // startet nicht.
      expect(() => prefs.getString('persons'), throwsA(isA<TypeError>()));

      expect(SyncDataReader.readLines(prefs, 'persons'), hasLength(2));

      // Die Reparatur ist asynchron – sie läuft im Hintergrund weiter.
      // Für den Test wird sie hier einmal abwartbar gemacht.
      await StorageHealer.heal(prefs, 'persons');
      expect(() => prefs.getString('persons'), returnsNormally);
      final String? raw = prefs.getString('persons');
      expect((jsonDecode(raw!) as List).length, 2);
    });

    test('ein JSON-String unter einem Listen-Schlüssel wird zur Liste',
        () async {
      final SharedPreferences prefs = await prefsWith(
          'offlineVPData',
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{'date': 'd1', 'name': 'Plan'},
          ]));
      expect(() => prefs.getStringList('offlineVPData'),
          throwsA(isA<TypeError>()));

      await StorageHealer.heal(prefs, 'offlineVPData');
      expect(prefs.getStringList('offlineVPData'), hasLength(1));
    });

    test('eine bereits richtige Form wird nicht angefasst', () async {
      final SharedPreferences prefs =
          await prefsWith('persons', jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'Hans'},
      ]));
      final bool changed = await StorageHealer.heal(prefs, 'persons');
      expect(changed, isFalse, reason: 'nichts zu tun, also nichts zu schreiben');
      // Und vor allem: nicht in die falsche Form konvertiert.
      expect(() => prefs.getStringList('persons'), throwsA(isA<TypeError>()));
    });

    test('ein unbekannter Schlüssel wird nicht angefasst', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(await StorageHealer.heal(prefs, 'gibt-es-nicht'), isFalse);
    });

    test('die Kette aus Schreiben und Lesen bleibt stabil', () async {
      // Ein Sync, der wiederholt schreibt, darf die Form weder beim ersten
      // noch beim zehnten Mal ändern.
      final SharedPreferences prefs = await prefsWith(
          'persons', jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'Hans'},
      ]));
      for (int i = 0; i < 10; i++) {
        await SyncMerge.applyToPreferences(
          prefs,
          _payload(<String, dynamic>{
            'persons': <Map<String, dynamic>>[
              <String, dynamic>{'id': '1', 'name': 'Hans'},
            ],
          }),
        );
        expect(() => prefs.getString('persons'), returnsNormally,
            reason: 'nach Durchlauf $i ist die Form gekippt');
      }
    });
  });

  group('Der Start der App überlebt einen beschädigten Schlüssel', () {
    test('healAll repariert ein ganz beschädigtes Gerät', () async {
      // Der Zustand, den ein alter Sync-Stand hinterlässt: mehrere
      // Bestandteile in der jeweils falschen Form.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': personLines(),
        'sickTrack': <String>[
          jsonEncode(<String, dynamic>{'id': 's1', 'name': 'Krank'}),
        ],
        'offlineVPData': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'date': 'd1', 'name': 'Plan'},
        ]),
        'classes': <String>[jsonEncode(<String, dynamic>{'id': 'c1'})],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final int repaired = await StorageHealer.healAll(prefs);
      expect(repaired, 3, reason: 'persons, sickTrack und offlineVPData');

      // Und danach liest die App überall so, wie sie es erwartet.
      expect(() => prefs.getString('persons'), returnsNormally);
      expect(() => prefs.getString('sickTrack'), returnsNormally);
      expect(() => prefs.getStringList('offlineVPData'), returnsNormally);
      expect(() => prefs.getStringList('classes'), returnsNormally);
    });

    test('healAll tut auf einem gesunden Gerät nichts', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'Hans'},
        ]),
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(await StorageHealer.healAll(prefs), 0);
    });

    test('loadDisplayCache wirft nicht, wenn persons eine Liste ist',
        () async {
      // Genau der Zustand, über den gemeldet wurde. `loadDisplayCache` wird in
      // `main()` **vor** `runApp` aufgerufen: Ein Wurf hier bedeutet, dass die
      // App nie startet – dauerhaft, weil der Schlüssel ja so bleibt.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': personLines(),
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Plan'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await expectLater(loadDisplayCache(prefs), completes);

      // Und der Vorschau-Cache wurde trotzdem gefüllt – die Reparatur darf die
      // Personen nicht verschwinden lassen.
      expect(
        prefs.getString('persons'),
        isNotNull,
        reason: 'nach der Reparatur muss die Form wieder die erwartete sein',
      );
    });

    test('und funktioniert danach ganz normal', () async {
      // Der Gerätestand, der aus der ersten reparierten Zeile entsteht.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'Hans'},
        ]),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await expectLater(loadDisplayCache(prefs), completes);
    });
  });

  group('Ein voller Sync-Lauf ändert keine Speicherform', () {
    test('über die Engine, mit der die App wirklich startet', () async {
      // Der Weg von `main()` bis hierher: sammeln, verschlüsseln, zusammenführen,
      // zurückschreiben. Nur dieser vollständige Weg zählt – ein Test am
      // Schreiber allein hätte die Hälfte der Wirkung verfehlt.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'Hans'},
        ]),
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Plan'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SyncPayload payload = await SyncEngine(client: _OfflineClient())
          .collect(
        prefs,
        SyncState(
          passphrase: 'blue sky river seven apple candle',
          chainId: 'kette',
          deviceId: 'geraet',
          deviceName: 'Pixel',
          includeSettings: false,
          lastSync: null,
        ),
      );
      // Der Server liefert nichts, also wird nur das zurückgeschrieben, was
      // ohnehin schon lokal war.
      await SyncMerge.applyToPreferences(prefs, payload);

      // Das ist die Behauptung, um die es geht: Die Form, in der die App ihre
      // eigenen Daten erwartet, ist nach einem Sync unverändert.
      expect(() => prefs.getString('persons'), returnsNormally);
      expect(() => prefs.getStringList('offlineVPData'), returnsNormally);
      expect(() => prefs.getStringList('persons'), throwsA(isA<TypeError>()));
    });
  });
}

/// Baut ein [SyncPayload] aus einer einfachen Karte.
SyncPayload _payload(Map<String, dynamic> parts) {
  final Map<String, List<Map<String, dynamic>>> items =
      parts.map((String key, dynamic value) =>
          MapEntry<String, List<Map<String, dynamic>>>(key, _asList(value)));
  return SyncPayload(
    parts: <SyncPart>[
      for (final MapEntry<String, List<Map<String, dynamic>>> entry
          in items.entries)
        SyncPayload.describePart(entry.key, entry.value),
    ],
    tombstones: const <SyncTombstone>[],
    settings: const <String, dynamic>{},
    updatedAt: DateTime.utc(2026, 10, 1),
    deviceName: 'Test',
  );
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is List) {
    return value.cast<Map<String, dynamic>>();
  }
  return <Map<String, dynamic>>[];
}

/// Ein Client, der nichts erreichbar hat – für [SyncEngine.collect] ist das
/// unerheblich, gesammelt wird vor dem ersten Zugriff.
class _OfflineClient extends SyncApiClient {
  _OfflineClient() : super(baseUrl: Uri.parse('https://test.supabase.co'));
}
