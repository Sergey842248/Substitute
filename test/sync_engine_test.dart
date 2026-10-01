import 'dart:convert';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/ConfigBackup.dart';
import 'package:substitute/services/crypto/PayloadCrypto.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncMerge.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Ein Speicher-Client, der die Serverantworten in einer Map hält.
///
/// So lässt sich der ganze Sync-Ablauf ohne Netz prüfen – inklusive
/// Verschlüsselung, Merge und Rückschreiben in `SharedPreferences`.
class FakeServer {
  FakeServer();

  final Map<String, List<Map<String, dynamic>>> chains =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, dynamic>> shares =
      <String, Map<String, dynamic>>{};

  /// Jeder schreibende Zugriff wird hier protokolliert.
  final List<String> calls = <String>[];

  /// Wenn true, antwortet der Server mit 503.
  bool offline = false;

  SyncApiClient client() => SyncApiClient(
        baseUrl: Uri.parse('https://sync.test'),
        client: MockClient((http.Request request) async {
          final String path = request.url.path;
          calls.add('${request.method} $path');
          if (offline) return http.Response('{}', 503);

          if (path == '/v1/health') {
            return http.Response(jsonEncode(<String, dynamic>{'status': 'running'}), 200);
          }

          if (request.method == 'GET' && path.startsWith('/v1/chain/')) {
            final String chainId = _segment(path, 2);
            final List<Map<String, dynamic>> stored =
                chains[chainId] ?? const <Map<String, dynamic>>[];
            // Der Anfragerumpf ist snake_case (Spaltennamen), die Antwort
            // camelCase (Domänenmodell der App). Wer hier den gespeicherten
            // Rumpf unveraendert zurueckgibt, liefert `device_id` statt
            // `deviceId` – das Geraet bekommt dann eine leere Kennung,
            // wird nie als eigenes erkannt und laesst fremde Daten doppelt
            // laufen. Der Server baut dieses DTO, also tut der Nachbau hier
            // dasselbe.
            // Beim eigenen Server steht es im Pfad (`/devices`), bei Supabase
            // als Query-Parameter. Dieser Nachbau bedient den eigenen.
            final bool devicesOnly = path.endsWith('/devices');
            final List<Map<String, dynamic>> dto = stored
                .map((Map<String, dynamic> row) => <String, dynamic>{
                      'deviceId': row['device_id'],
                      'deviceName': row['device_name'],
                      'updatedAt': row['updated_at'],
                      'includesSettings': row['includes_settings'],
                      if (!devicesOnly) 'envelope': row['envelope'],
                    })
                .toList();
            return http.Response(
              jsonEncode(<String, dynamic>{
                'chainId': chainId,
                if (devicesOnly) 'devices': dto else 'snapshots': dto,
                'serverTime': '2026-10-01T00:00:00.000Z',
              }),
              200,
            );
          }

          if (request.method == 'PUT' && path.startsWith('/v1/chain/')) {
            final String chainId = _segment(path, 2);
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            final List<Map<String, dynamic>> snapshots =
                chains.putIfAbsent(chainId, () => <Map<String, dynamic>>[]);
            snapshots.removeWhere(
                (Map<String, dynamic> s) => s['device_id'] == body['device_id']);
            snapshots.add(body);
            return http.Response('{}', 200);
          }

          if (request.method == 'DELETE' && path.startsWith('/v1/chain/')) {
            final String chainId = _segment(path, 2);
            if (path.contains('/devices/')) {
              final String deviceId = _segment(path, 4);
              (chains[chainId] ?? const <Map<String, dynamic>>[])
                  .removeWhere((Map<String, dynamic> s) => s['device_id'] == deviceId);
            } else {
              chains.remove(chainId);
            }
            return http.Response('{}', 200);
          }

          if (path.startsWith('/v1/directory/')) {
            return http.Response(jsonEncode(<String, dynamic>{'people': const []}), 200);
          }

          return http.Response('{"error":"unknownEndpoint"}', 404);
        }),
      );

  static String _segment(String path, int index) =>
      path.split('/').where((String s) => s.isNotEmpty).elementAt(index);
}

/// Baut ein Paket aus einfachen Karten.
SyncPayload payloadOf(
  List<Map<String, dynamic>> persons, {
  String key = 'persons',
  DateTime? updatedAt,
  Map<String, dynamic>? settings,
  Map<String, DateTime>? settingsAt,
  List<SyncTombstone> tombstones = const <SyncTombstone>[],
}) =>
    SyncPayload(
      parts: <SyncPart>[SyncPayload.describePart(key, persons)],
      tombstones: tombstones,
      settings: settings ?? const <String, dynamic>{},
      settingsAt: settingsAt ?? const <String, DateTime>{},
      updatedAt: updatedAt ?? DateTime.utc(2026, 9, 30, 12),
    );

Map<String, dynamic> person(String id, String name, {String? at}) => <String, dynamic>{
      'id': id,
      'name': name,
      if (at != null) SyncPayload.syncTimestampField: at,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncPayload – Identitäten', () {
    test('nutzt die id eines Eintrags', () {
      final SyncPart part =
          SyncPayload.describePart('persons', <Map<String, dynamic>>[person('7', 'Hans')]);
      expect(part.idOf(<String, dynamic>{'id': '7'}), '7');
    });

    test('nutzt das Kürzel als Identität von Lehrernamen', () {
      final SyncPart part = SyncPayload.describePart('teacherShorts', <Map<String, dynamic>>[
        <String, dynamic>{'short': 'Ma', 'realName': 'Mustermann'},
      ]);
      expect(part.idOf(<String, dynamic>{'short': 'Ma'}), 'Ma');
    });

    test('kombiniert Anzahl und Zeiten bei den Kurzstunden', () {
      final SyncPart part = SyncPayload.describePart('lessontimes', <Map<String, dynamic>>[
        <String, dynamic>{'count': 6, 'start': '08:00', 'end': '08:45'},
      ]);
      expect(
        part.idOf(<String, dynamic>{'count': 6, 'start': '08:00', 'end': '08:45'}),
        '6_08:00_08:45',
      );
    });

    test('nutzt das Datum eines Plans, auch aus der verschachtelten Form', () {
      expect(
        SyncPayload.describePart('offlineVPData', const <Map<String, dynamic>>[])
            .idOf(<String, dynamic>{'date': '2026-09-30'}),
        '2026-09-30',
      );
      expect(
        SyncPayload.describePart('offlineVPData', const <Map<String, dynamic>>[])
            .idOf(<String, dynamic>{
          'data': <String, dynamic>{
            'Kopf': <String, dynamic>{'DatumPlan': '2026-09-30'}
          },
        }),
        '2026-09-30',
      );
    });

    test('schließt das interne Zeitfeld aus der Identität aus', () {
      final SyncPart part = SyncPayload.describePart('sickTrack', <Map<String, dynamic>>[]);
      final String withoutTime =
          part.idOf(<String, dynamic>{'classId': '5a', 'courses': <String>['De']})!;
      final String withTime = part.idOf(<String, dynamic>{
        'classId': '5a',
        'courses': <String>['De'],
        SyncPayload.syncTimestampField: '2026-09-30T10:00:00Z',
      })!;
      expect(withTime, withoutTime);
    });
  });

  group('SyncPayload – Serialisierung', () {
    test('übersteht einen Rundenlauf', () {
      final SyncPayload original = payloadOf(
        <Map<String, dynamic>>[person('1', 'Hans'), person('2', 'Petra')],
        settings: <String, dynamic>{'hideTeacher': true},
        tombstones: <SyncTombstone>[
          SyncTombstone(
            key: 'persons',
            id: '9',
            deletedAt: DateTime.utc(2026, 9, 29),
          ),
        ],
      );
      final SyncPayload restored = SyncPayload.fromJson(original.toJson());
      expect(restored.parts.single.items, hasLength(2));
      expect(restored.settings['hideTeacher'], true);
      expect(restored.tombstones.single.id, '9');
      expect(restored.updatedAt, original.updatedAt);
    });

    test('lehnt Daten einer anderen App ab', () {
      expect(
        () => SyncPayload.fromJson(<String, dynamic>{'app': 'something-else'}),
        throwsFormatException,
      );
    });

    test('lehnt ein neueres Format ab', () {
      expect(
        () => SyncPayload.fromJson(<String, dynamic>{
          'app': 'substitute',
          'schema': SyncPayload.schemaVersion + 1,
        }),
        throwsFormatException,
      );
    });

    test('nimmt Objekte und einfache Namen, überspringt den Rest', () async {
      // Ein Eintrag ist ein Objekt **oder** ein einfacher Name – die App legt
      // die Klassen als `['8a', '8b']` ab, ohne JSON. Nur echte Namen zählen;
      // alles andere wird übergangen, statt das ganze Paket scheitern zu
      // lassen.
      final SyncPayload restored = SyncPayload.fromJson(<String, dynamic>{
        'app': 'substitute',
        'schema': 1,
        'parts': <dynamic>[
          <String, dynamic>{
            'key': 'persons',
            'items': <dynamic>[
              '8a',
              <String, dynamic>{'id': '1', 'name': 'Hans'},
              42,
            ],
          },
        ],
      });
      expect(restored.parts.single.items, hasLength(2));
      expect(restored.parts.single.items.first, '8a');
      expect(restored.parts.single.items.last, isA<Map<String, dynamic>>());
    });
  });

  group('SyncMerge', () {
    test('übernimmt Einträge, die nur entfernt vorhanden sind', () {
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans')]),
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans'), person('2', 'Petra')]),
      );
      final List<Object> merged = result.parts.single.items;
      expect(merged, hasLength(2));
      expect(result.added, <String>['2']);
    });

    test('behält Einträge, die nur lokal vorhanden sind', () {
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans'), person('2', 'Petra')]),
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans')]),
      );
      expect(result.parts.single.items, hasLength(2));
      expect(result.added, isEmpty);
    });

    test('übernimmt die entfernte Änderung, wenn sie neuer ist', () {
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans', at: '2026-09-30T10:00:00Z')]),
        payloadOf(<Map<String, dynamic>>[person('1', 'Renate', at: '2026-09-30T11:00:00Z')]),
      );
      expect((result.parts.single.items.single as Map)['name'], 'Renate');
      expect(result.updated, <String>['1']);
    });

    test('behält die lokale Änderung, wenn sie neuer ist', () {
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans', at: '2026-09-30T11:00:00Z')]),
        payloadOf(<Map<String, dynamic>>[person('1', 'Renate', at: '2026-09-30T10:00:00Z')]),
      );
      expect((result.parts.single.items.single as Map)['name'], 'Hans');
    });

    test('lässt eine gelöschte Person auch dann verschwunden, wenn ein '
        'anderes Gerät sie noch hat', () {
      final SyncTombstone deleted = SyncTombstone(
        key: 'persons',
        id: '2',
        deletedAt: DateTime.utc(2026, 9, 30, 12),
      );
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans')]),
        payloadOf(
          <Map<String, dynamic>>[
            person('1', 'Hans'),
            person('2', 'Petra', at: '2026-09-30T10:00:00Z'),
          ],
          tombstones: <SyncTombstone>[deleted],
        ),
      );
      expect(
        result.parts.single.items.map((Object i) => (i as Map)['id']),
        <String>['1'],
      );
      expect(result.removed, <String>['2']);
    });

    test('bringt eine gelöschte Person nicht zurück, wenn sie danach geändert '
        'wurde', () {
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[
          person('1', 'Hans'),
          person('2', 'Petra neu', at: '2026-09-30T13:00:00Z'),
        ]),
        payloadOf(
          <Map<String, dynamic>>[person('2', 'Petra')],
          tombstones: <SyncTombstone>[
            SyncTombstone(
              key: 'persons',
              id: '2',
              deletedAt: DateTime.utc(2026, 9, 30, 12),
            ),
          ],
        ),
      );
      expect(
        result.parts.single.items
            .firstWhere((Object i) => (i as Map)['id'] == '2'),
        containsPair('name', 'Petra neu'),
        reason: 'Eine Änderung nach dem Löschen ist eine neue Person.',
      );
    });

    test('ist symmetrisch: die Reihenfolge der Geräte ändert nichts', () {
      final SyncPayload a = payloadOf(
        <Map<String, dynamic>>[
          person('1', 'Hans', at: '2026-09-30T10:00:00Z'),
          person('2', 'Petra'),
        ],
      );
      final SyncPayload b = payloadOf(
        <Map<String, dynamic>>[
          person('1', 'Hans', at: '2026-09-30T11:00:00Z'),
          person('3', 'Sven'),
        ],
      );
      List<String> idsOf(SyncMergeResult result) => result.parts.single.items
          .map((Object i) => '${(i as Map)['id']}:${(i as Map)['name']}')
          .toList();

      expect(idsOf(SyncMerge.merge(a, b)), idsOf(SyncMerge.merge(b, a)));
    });

    test('führt Pläne nach Datum zusammen', () {
      final SyncPart local = SyncPayload.describePart('offlineVPData', <Object>[
        <String, dynamic>{'date': '2026-09-28', 'name': 'A'},
        <String, dynamic>{'date': '2026-09-29', 'name': 'B'},
      ]);
      final SyncPart remote = SyncPayload.describePart('offlineVPData', <Object>[
        <String, dynamic>{'date': '2026-09-29', 'name': 'B'},
        <String, dynamic>{'date': '2026-09-30', 'name': 'C'},
      ]);
      final SyncMergeResult result = SyncMerge.merge(
        SyncPayload(
          parts: <SyncPart>[local],
          tombstones: const <SyncTombstone>[],
          settings: const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 9, 30, 12),
        ),
        SyncPayload(
          parts: <SyncPart>[remote],
          tombstones: const <SyncTombstone>[],
          settings: const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 9, 30, 12),
        ),
      );
      expect(
        result.parts.single.items.map((Object i) => (i as Map)['date']),
        <String>['2026-09-28', '2026-09-29', '2026-09-30'],
      );
    });

    test('nimmt bei Einstellungen die neuere Seite', () {
      final SyncPayload older = payloadOf(
        const <Map<String, dynamic>>[],
        updatedAt: DateTime.utc(2026, 9, 30, 10),
        settings: <String, dynamic>{'hideTeacher': true},
      );
      final SyncPayload newer = payloadOf(
        const <Map<String, dynamic>>[],
        updatedAt: DateTime.utc(2026, 9, 30, 11),
        settings: <String, dynamic>{'hideTeacher': false},
      );
      expect(SyncMerge.merge(older, newer).settings!['hideTeacher'], false);
      expect(SyncMerge.merge(newer, older).settings!['hideTeacher'], false);
    });

    test('behält eine Einstellung, die nur lokal existiert', () {
      final SyncPayload local = payloadOf(
        const <Map<String, dynamic>>[],
        settings: <String, dynamic>{'materialyou': true},
      );
      final SyncPayload remote =
          payloadOf(const <Map<String, dynamic>>[]);
      expect(SyncMerge.merge(local, remote).settings!['materialyou'], true);
    });
  });

  group('SyncKeys', () {
    test('die Bestandteile sind die Arrays, der Rest sind Werte', () {
      // Der Schalter in den Einstellungen entscheidet nur noch, ob die
      // **Werte** mitgehen. Er bestimmt nicht mehr *welche* – dafür gibt es
      // keine Liste mehr, und genau daran scheiterte es vorher: Eine
      // Positivliste von Einstellungen kann nicht vollständig sein, also kamen
      // `languageCode`, `newsfeeds` und die Plan-Einstellungen nie an.
      final List<String> items =
          SyncKeys.forSchool((String k) => k, includeSettings: false);
      expect(items, containsAll(<String>['persons', 'offlineVPData', 'classes']));
      expect(items, isNot(contains('hideTeacher')),
          reason: 'ein Schalter ist kein Bestandteil');

      // Alles, was kein Array ist, ist übertragbar – ohne eingetragen zu sein.
      for (final String key in <String>[
        'hideTeacher',
        'languageCode',
        'defaultPlanModeClass',
        'newsfeeds',
        'initializedClasses',
        'hiddenSubjectsByClass',
        'previewHiddenClasses',
      ]) {
        expect(SyncKeys.isSyncable(key), isTrue,
            reason: '$key wird nicht übertragen');
        expect(SyncKeys.classify(key), SyncKeyKind.value);
      }
      // Die Arrays dagegen sind Bestandteile und werden einzeln geführt.
      for (final String key in SyncKeys.itemKeys) {
        expect(SyncKeys.classify(key), SyncKeyKind.items, reason: key);
      }
    });

    test('schließt die Zugangsdaten immer aus', () {
      for (final String key in SyncKeys.credentialKeys) {
        expect(SyncKeys.isSyncable(key), isFalse, reason: key);
        expect(SyncKeys.forSchool((String k) => k, includeSettings: true)
            .contains(key), isFalse);
      }
    });

    test('schließt den Kurzzeit-Cache aus', () {
      expect(SyncKeys.isSyncable('vplan_cache_2026-09-30'), isFalse);
      expect(SyncKeys.isSyncable('vplan_cache_2026-09-30_time'), isFalse);
    });

    test('hält gerätebezogene Angaben lokal', () {
      expect(SyncKeys.isDeviceLocalKey('firstTime'), isTrue);
      expect(SyncKeys.isDeviceLocalKey('overriddenNow'), isTrue);
      expect(SyncKeys.isDeviceLocalKey('sync.tombstones'), isTrue);
      // Sprache ist eine Vorliebe der **Person**, nicht des Geräts, und wird
      // deshalb übertragen. Sie stand hier früher als geräteübergreifend auf der
      // Sperrliste – mit der Begründung, sie hänge an der Bildschirmgröße. Das
      // war eine Annahme, und sie hat eine Einstellung aus der Kette gehalten,
      // die jeder erwartet, dass sie wandert.
      expect(SyncKeys.isDeviceLocalKey('languageCode'), isFalse);
      expect(SyncKeys.isSyncable('languageCode'), isTrue);
    });

    test('erkennt schulbezogene Schlüssel', () {
      expect(SyncKeys.isSyncable('schools.12345.persons'), isTrue);
      expect(SyncKeys.isSetting('schools.12345.hideTeacher'), isTrue);
      expect(SyncKeys.isSetting('persons'), isFalse);
    });

    test('jeder Array-Schlüssel hat eine angegebene Form', () {
      // Die Form steht nicht am gespeicherten Wert, sondern in einer Liste –
      // `classes` und `persons` sind beide Arrays, liegen aber verschieden ab.
      // Fehlt ein Eintrag, fällt der Schreiber auf `setStringList` zurück und
      // macht die App beim Start unbenutzbar.
      for (final String key in SyncKeys.itemKeys) {
        expect(SyncKeys.formOf(key), isNotNull, reason: '$key fehlt in dataKeyForms');
      }
      // Und umgekehrt: keine Form für etwas, das kein Bestandteil ist.
      expect(SyncKeys.formOf('hideTeacher'), isNull);
    });
  });

  group('Passphrase', () {
    test('eine Passphrase ergibt eine stabile Kette', () {
      const String phrase = 'blue sky river seven apple candle dolphin';
      expect(SyncEngine.chainIdFor(phrase), SyncEngine.chainIdFor(phrase));
      expect(SyncEngine.chainIdFor(phrase), isNotEmpty);
    });

    test('Groß- und Kleinschreibung sowie Trennzeichen sind egal', () {
      expect(
        SyncEngine.chainIdFor('Blue  Sky, River'),
        SyncEngine.chainIdFor('blue-sky river'),
      );
    });

    test('verschiedene Passphrasen ergeben verschiedene Ketten', () {
      expect(
        SyncEngine.chainIdFor('blue sky river seven apple'),
        isNot(SyncEngine.chainIdFor('blue sky river seven candle')),
      );
    });

    test('ein Sync-Schlüssel ist kein Share-Schlüssel', () {
      final DerivedKey sync = SyncEngine.keyFor('blue sky river seven apple');
      final DerivedKey share = PayloadCrypto.deriveKey(
        'blue sky river seven apple',
        salt: 'substitute/share/v1',
      );
      expect(sync.encryptionKey, isNot(share.encryptionKey));
    });

    test('die Prüfung meldet unbekannte Wörter im Klartext', () {
      final PassphraseCheck good =
          SyncEngine.checkPassphrase('blue sky river seven apple candle');
      expect(good.isValid, isTrue);

      final PassphraseCheck typo = SyncEngine.checkPassphrase('blue appel sky');
      expect(typo.isValid, isFalse);
      expect(typo.errorCode, 'unknownWords');
      expect(typo.detail, contains('appel'));
    });

    test('die Prüfung verlangt mehrere Wörter', () {
      expect(SyncEngine.checkPassphrase('blue sky').errorCode, 'tooFewWords');
      expect(SyncEngine.checkPassphrase('').isEmpty, isTrue);
    });
  });

  group('SyncEngine – vollständiger Lauf', () {
    late FakeServer server;
    late SyncApiClient client;
    late SyncEngine engine;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'person1': jsonEncode(<String, dynamic>{'id': '1', 'name': 'Hans'}),
        'persons': <String>[jsonEncode(<String, dynamic>{'id': '1', 'name': 'Hans'})],
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-09-29', 'name': 'Plan A'}),
        ],
        'hideTeacher': false,
        'materialyou': true,
        'vplanPassword': 'super-geheim',
      });
      server = FakeServer();
      client = server.client();
      engine = SyncEngine(client: client);
    });

    SyncState stateFor(String passphrase, {bool includeSettings = true}) =>
        SyncState(
          passphrase: passphrase,
          chainId: SyncEngine.chainIdFor(passphrase),
          deviceId: 'device-1',
          deviceName: 'Pixel 8',
          includeSettings: includeSettings,
          lastSync: null,
        );

    test('schickt die eigenen Daten hoch', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncOutcome outcome = await engine.run(
        prefs,
        stateFor('blue sky river seven apple candle'),
      );
      expect(outcome.succeeded, isTrue);
      expect(outcome.pushed, isTrue);
      expect(
        server.chains[SyncEngine.chainIdFor('blue sky river seven apple candle')],
        hasLength(1),
      );
    });

    test('holt die Daten eines anderen Geräts und führt sie zusammen', () async {
      const String passphrase = 'blue sky river seven apple candle';
      final String chainId = SyncEngine.chainIdFor(passphrase);

      // Ein zweites Gerät hat eine zusätzliche Person hochgeladen.
      final DerivedKey key = SyncEngine.keyFor(passphrase);
      server.chains[chainId] = <Map<String, dynamic>>[
        <String, dynamic>{
          'deviceId': 'device-2',
          'deviceName': 'Tablet',
          'updatedAt': DateTime.utc(2026, 9, 30, 11).toIso8601String(),
          'includesSettings': true,
          'envelope': PayloadCrypto.encryptJson(
            key,
            payloadOf(<Map<String, dynamic>>[
              person('1', 'Hans'),
              person('2', 'Petra'),
            ]).toJson(),
          ),
        },
      ];

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncOutcome outcome = await engine.run(prefs, stateFor(passphrase));

      expect(outcome.pulled, 1);
      expect(outcome.merged, greaterThan(0));
      expect(outcome.devices, hasLength(2));

      final List<String> persons = SyncDataReader.readLines(prefs, 'persons');
      expect(persons, hasLength(2));
      expect(
        persons.map((String p) => (jsonDecode(p) as Map)['name']),
        containsAll(<String>['Hans', 'Petra']),
      );
    });

    test('übernimmt Einstellungen nur, wenn sie Teil der Kette sind', () async {
      const String passphrase = 'blue sky river seven apple candle';
      final String chainId = SyncEngine.chainIdFor(passphrase);
      final DerivedKey key = SyncEngine.keyFor(passphrase);

      // Das andere Gerät hat einen Schalter umgestellt, den dieses Gerät gar
      // nicht kennt – das ist der Fall, in dem die Einstellungen überhaupt
      // übernommen werden müssen.
      server.chains[chainId] = <Map<String, dynamic>>[
        <String, dynamic>{
          'deviceId': 'device-2',
          'deviceName': 'Tablet',
          'updatedAt': DateTime.utc(2030, 1, 1).toIso8601String(),
          'includesSettings': true,
          'envelope': PayloadCrypto.encryptJson(
            key,
            payloadOf(
              const <Map<String, dynamic>>[],
              settings: <String, dynamic>{'hidePreviewPersons': true},
            ).toJson(),
          ),
        },
      ];

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await engine.run(prefs, stateFor(passphrase, includeSettings: false));
      expect(prefs.getBool('hidePreviewPersons'), isNull,
          reason: 'Ohne Einstellungen in der Kette wird nichts übernommen');

      await engine.run(prefs, stateFor(passphrase, includeSettings: true));
      expect(prefs.getBool('hidePreviewPersons'), isTrue);
    });

    test('behält eine Einstellung, die es nach dem Start der Kette selbst '
        'geändert hat', () async {
      const String passphrase = 'blue sky river seven apple candle';
      final String chainId = SyncEngine.chainIdFor(passphrase);
      final DerivedKey key = SyncEngine.keyFor(passphrase);

      // Das andere Gerät behauptet seit 2020 das Gegenteil.
      server.chains[chainId] = <Map<String, dynamic>>[
        <String, dynamic>{
          'deviceId': 'device-2',
          'deviceName': 'Tablet',
          'updatedAt': DateTime.utc(2020, 1, 1).toIso8601String(),
          'includesSettings': true,
          'envelope': PayloadCrypto.encryptJson(
            key,
            payloadOf(
              const <Map<String, dynamic>>[],
              settings: <String, dynamic>{'hideTeacher': true},
              // Die Zeit des **Wertes**, nicht die des Pakets. Genau hier ist
              // vorher der Fehler passiert: Ein einziger Paket-Zeitstempel, auf
              // "jetzt" bei jedem Lauf, ließ jedes Gerät das neueste sein –
              // und damit keine Einstellung jemals ankommen.
              settingsAt: <String, DateTime>{
                'hideTeacher': DateTime.utc(2020, 1, 1),
              },
            ).toJson(),
          ),
        },
      ];

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Der Wert muss **vor** dem ersten Lauf existieren. Ein Wert, den das
      // Gerät zum ersten Mal sieht, bekommt den Anfang der Zeitachse – das ist
      // keine Änderung, sondern ein Erstsehen, und genau so soll es behandelt
      // werden.
      await prefs.setBool('hideTeacher', true);
      await engine.run(prefs, stateFor(passphrase, includeSettings: true));

      // Und jetzt die eigene Änderung – die ist jünger als 2020.
      await prefs.setBool('hideTeacher', false);
      await engine.run(prefs, stateFor(passphrase, includeSettings: true));

      expect(prefs.getBool('hideTeacher'), isFalse,
          reason: 'eine eigene, nachweislich spätere Änderung darf nicht von '
              'einem uralten Wert überschrieben werden');
    });

    test('überträgt niemals das Schulpasswort', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await engine.run(prefs, stateFor('blue sky river seven apple candle'));

      final String raw = jsonEncode(
        server.chains[SyncEngine.chainIdFor('blue sky river seven apple candle')]!,
      );
      expect(raw.contains('super-geheim'), isFalse);
      expect(raw.contains('vplanPassword'), isFalse);
    });

    test('übernimmt die Pläne aus der Vergangenheit mit', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await engine.run(prefs, stateFor('blue sky river seven apple candle'));
      expect(SyncDataReader.readLines(prefs, 'offlineVPData'), hasLength(1));
    });

    test('meldet einen Ausfall des Servers, ohne zu verlieren', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      server.offline = true;
      final SyncOutcome outcome = await engine.run(
        prefs,
        stateFor('blue sky river seven apple candle'),
      );
      expect(outcome.succeeded, isFalse);
      // Die lokalen Daten sind unangetastet.
      expect(SyncDataReader.readLines(prefs, 'persons'), hasLength(1));
    });

    test('findet einen fremden Snapshot mit falschem Schlüssel nicht', () async {
      const String passphrase = 'blue sky river seven apple candle';
      final String chainId = SyncEngine.chainIdFor(passphrase);
      server.chains[chainId] = <Map<String, dynamic>>[
        <String, dynamic>{
          'deviceId': 'device-2',
          'deviceName': 'Fremd',
          'updatedAt': DateTime.utc(2026, 9, 30, 11).toIso8601String(),
          'includesSettings': true,
          'envelope': <String, dynamic>{'v': 1, 'iv': 'aXY=', 'ct': 'Y2lwaGVy', 'mac': 'eA=='},
        },
      ];
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncOutcome outcome = await engine.run(prefs, stateFor(passphrase));
      // Ein kaputter Snapshot darf den Rest nicht blockieren.
      expect(outcome.pushed, isTrue);
      expect(SyncDataReader.readLines(prefs, 'persons'), hasLength(1));
    });
  });

  group('Verlassen der Kette', () {
    test('löscht den eigenen Snapshot, behält aber die Daten', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': <String>[
          jsonEncode(<String, dynamic>{'id': '1', 'name': 'Hans'}),
        ],
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-09-29', 'name': 'Plan A'}),
        ],
        'hideTeacher': true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final FakeServer server = FakeServer();
      final SyncApiClient client = server.client();

      const String passphrase = 'blue sky river seven apple candle';
      final SyncState state = SyncState(
        passphrase: passphrase,
        chainId: SyncEngine.chainIdFor(passphrase),
        deviceId: 'device-1',
        deviceName: 'Pixel 8',
        includeSettings: true,
        lastSync: null,
      );
      await SyncEngine.saveState(prefs, state);
      await SyncEngine(client: client)
          .run(prefs, state);

      expect(server.chains[state.chainId], hasLength(1));

      await SyncEngine.leaveChain(prefs, state, client);

      // Der Snapshot ist weg, die Daten sind es nicht.
      expect(server.chains[state.chainId], isEmpty);
      expect(SyncDataReader.readLines(prefs, 'persons'), hasLength(1));
      expect(SyncDataReader.readLines(prefs, 'offlineVPData'), hasLength(1));
      expect(prefs.getBool('hideTeacher'), isTrue);
      // Und die Kette ist lokal beendet.
      expect(await SyncEngine.loadState(prefs), isNull);
    });
  });

  group('SyncMerge.applyToPreferences', () {
    test('schreibt Personen als JSON-Array von Objekten', () async {
      // So legt `VPlanAPI` sie ab – und nur so. Der Test hieß früher
      // "schreibt Listen als StringList" und beschrieb damit genau die Form,
      // die die App nicht starten ließ.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await SyncMerge.applyToPreferences(
        prefs,
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans')]),
      );

      // Die **Form** ist hier die eigentliche Zusicherung. Als `StringList`
      // gespeichert wirft `VPlanAPI.loadDisplayCache` beim Start einen
      // TypeError, `main()` bricht ab, und die App startet nie wieder – das
      // ist keine theoretische Sorge, sondern genau so geschehen.
      final String? raw = prefs.getString('persons');
      expect(raw, isNotNull, reason: 'als StringList gespeichert: Absturz beim Start');
      final List<dynamic> decoded = jsonDecode(raw!) as List<dynamic>;
      // Ein **Objekt**, nicht eine Zeichenkette, die ein Objekt enthält.
      expect(decoded.single, isA<Map<String, dynamic>>());
      expect((decoded.single as Map)['name'], 'Hans');
    });

    test('schreibt Pläne als StringList', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: <SyncPart>[
            SyncPayload.describePart('offlineVPData', <Object>[
              <String, dynamic>{'date': '2026-09-30', 'name': 'Plan'},
            ]),
          ],
          tombstones: const <SyncTombstone>[],
          settings: const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 9, 30),
        ),
      );

      final List<String>? written = SyncDataReader.readLines(prefs, 'offlineVPData');
      expect(written, isNotNull);
      expect((jsonDecode(written!.single) as Map)['name'], 'Plan');
    });

    test('speichert Lösch-Markierungen, damit sie weitergegeben werden',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncTombstone deleted = SyncTombstone(
        key: 'persons',
        id: '9',
        deletedAt: DateTime.utc(2026, 9, 30),
      );
      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: const <SyncPart>[],
          tombstones: <SyncTombstone>[deleted],
          settings: const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 9, 30),
        ),
      );
      expect(SyncMerge.readTombstones(prefs).single.id, '9');
    });

    test('schreibt keine Einstellungen, die als sensibel gelten', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: const <SyncPart>[],
          tombstones: const <SyncTombstone>[],
          settings: <String, dynamic>{'overriddenNow': '2030-01-01'},
          updatedAt: DateTime.utc(2026, 9, 30),
        ),
      );
      expect(prefs.getString('overriddenNow'), isNull);
    });
  });

  group('SyncApiClient', () {
    test('erkennt einen laufenden Server', () async {
      final FakeServer server = FakeServer();
      expect(await server.client().isServerRunning(), isTrue);
      server.offline = true;
      expect(await server.client().isServerRunning(), isFalse);
    });

    test('übersetzt Fehlercodes', () async {
      final SyncApiClient client = SyncApiClient(
        baseUrl: Uri.parse('https://sync.test'),
        client: MockClient(
          (http.Request request) async =>
              http.Response('{"error":"notFound"}', 404),
        ),
      );
      expect(
        () => client.fetchChain('abc'),
        throwsA(
          isA<SyncException>()
              .having((SyncException e) => e.code, 'code', 'notFound')
              .having((SyncException e) => e.status, 'status', 404),
        ),
      );
    });

    test('meldet einen Netzausfall als transient', () async {
      final SyncApiClient client = SyncApiClient(
        baseUrl: Uri.parse('https://sync.test'),
        client: MockClient((http.Request request) async =>
            throw const SocketException('no route')),
      );
      try {
        await client.fetchChain('abc');
        fail('expected a SyncException');
      } on SyncException catch (error) {
        expect(error.code, 'network');
        expect(error.isTransient, isTrue);
      }
    });
  });
}
