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
            return http.Response(
              jsonEncode(<String, dynamic>{
                'chainId': chainId,
                'snapshots': chains[chainId] ?? const <Map<String, dynamic>>[],
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
                (Map<String, dynamic> s) => s['deviceId'] == body['deviceId']);
            snapshots.add(body);
            return http.Response('{}', 200);
          }

          if (request.method == 'DELETE' && path.startsWith('/v1/chain/')) {
            final String chainId = _segment(path, 2);
            if (path.contains('/devices/')) {
              final String deviceId = _segment(path, 4);
              (chains[chainId] ?? const <Map<String, dynamic>>[])
                  .removeWhere((Map<String, dynamic> s) => s['deviceId'] == deviceId);
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
  List<SyncTombstone> tombstones = const <SyncTombstone>[],
}) =>
    SyncPayload(
      parts: <SyncPart>[SyncPayload.describePart(key, persons)],
      tombstones: tombstones,
      settings: settings ?? const <String, dynamic>{},
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

    test('überspringt beschädigte Einträge statt zu scheitern', () {
      final SyncPayload restored = SyncPayload.fromJson(<String, dynamic>{
        'app': 'substitute',
        'schema': 1,
        'parts': <dynamic>[
          <String, dynamic>{
            'key': 'persons',
            'items': <dynamic>[
              'kein map',
              <String, dynamic>{'id': '1', 'name': 'Hans'},
            ],
          },
        ],
      });
      expect(restored.parts.single.items, hasLength(1));
    });
  });

  group('SyncMerge', () {
    test('übernimmt Einträge, die nur entfernt vorhanden sind', () {
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans')]),
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans'), person('2', 'Petra')]),
      );
      final List<Map<String, dynamic>> merged = result.parts.single.items;
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
      expect(result.parts.single.items.single['name'], 'Renate');
      expect(result.updated, <String>['1']);
    });

    test('behält die lokale Änderung, wenn sie neuer ist', () {
      final SyncMergeResult result = SyncMerge.merge(
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans', at: '2026-09-30T11:00:00Z')]),
        payloadOf(<Map<String, dynamic>>[person('1', 'Renate', at: '2026-09-30T10:00:00Z')]),
      );
      expect(result.parts.single.items.single['name'], 'Hans');
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
        result.parts.single.items.map((Map<String, dynamic> i) => i['id']),
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
            .firstWhere((Map<String, dynamic> i) => i['id'] == '2')['name'],
        'Petra neu',
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
          .map((Map<String, dynamic> i) => '${i['id']}:${i['name']}')
          .toList();

      expect(idsOf(SyncMerge.merge(a, b)), idsOf(SyncMerge.merge(b, a)));
    });

    test('führt Pläne nach Datum zusammen', () {
      final SyncPart local = SyncPayload.describePart('offlineVPData', <Map<String, dynamic>>[
        <String, dynamic>{'date': '2026-09-28', 'name': 'A'},
        <String, dynamic>{'date': '2026-09-29', 'name': 'B'},
      ]);
      final SyncPart remote = SyncPayload.describePart('offlineVPData', <Map<String, dynamic>>[
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
        result.parts.single.items.map((Map<String, dynamic> i) => i['date']),
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
    test('nimmt die Daten immer, die Einstellungen nur auf Wunsch', () {
      final List<String> without =
          SyncKeys.forSchool((String k) => k, includeSettings: false);
      final List<String> withSettings =
          SyncKeys.forSchool((String k) => k, includeSettings: true);
      expect(without, contains('persons'));
      expect(without, contains('offlineVPData'));
      expect(without, isNot(contains('hideTeacher')));
      expect(withSettings, contains('hideTeacher'));
      expect(withSettings.length, greaterThan(without.length));
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

    test('hält gerätebezogene Einstellungen lokal', () {
      expect(SyncKeys.isDeviceLocalKey('languageCode'), isTrue);
      expect(SyncKeys.isDeviceLocalKey('firstTime'), isTrue);
      expect(SyncKeys.isDeviceLocalKey('overriddenNow'), isTrue);
      expect(SyncKeys.isDeviceLocalKey('sync.tombstones'), isTrue);
      // Sprache ist absichtlich nicht synchronisierbar: Wer auf dem Tablet
      // Deutsch und auf dem Handy Englisch liest, soll das können.
      expect(SyncKeys.settingKeys, isNot(contains('languageCode')));
    });

    test('erkennt schulbezogene Schlüssel', () {
      expect(SyncKeys.isSyncable('schools.12345.persons'), isTrue);
      expect(SyncKeys.isSetting('schools.12345.hideTeacher'), isTrue);
      expect(SyncKeys.isSetting('persons'), isFalse);
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

      final List<String> persons =
          prefs.getStringList('persons') ?? const <String>[];
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

    test('behält die Einstellungen des Geräts, die es selbst gesetzt hat',
        () async {
      const String passphrase = 'blue sky river seven apple candle';
      final String chainId = SyncEngine.chainIdFor(passphrase);
      final DerivedKey key = SyncEngine.keyFor(passphrase);

      // Das andere Gerät ist älter und sagt das Gegenteil.
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
            ).toJson(),
          ),
        },
      ];

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await engine.run(prefs, stateFor(passphrase, includeSettings: true));
      expect(prefs.getBool('hideTeacher'), isFalse);
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
      expect(prefs.getStringList('offlineVPData'), hasLength(1));
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
      expect(prefs.getStringList('persons'), hasLength(1));
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
      expect(prefs.getStringList('persons'), hasLength(1));
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
      expect(prefs.getStringList('persons'), hasLength(1));
      expect(prefs.getStringList('offlineVPData'), hasLength(1));
      expect(prefs.getBool('hideTeacher'), isTrue);
      // Und die Kette ist lokal beendet.
      expect(await SyncEngine.loadState(prefs), isNull);
    });
  });

  group('SyncMerge.applyToPreferences', () {
    test('schreibt Listen als StringList mit JSON pro Eintrag', () async {
      // Genau so erwarten es VPlanAPI und die Plan-Ansicht.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await SyncMerge.applyToPreferences(
        prefs,
        payloadOf(<Map<String, dynamic>>[person('1', 'Hans')]),
      );

      final List<String>? written = prefs.getStringList('persons');
      expect(written, isNotNull);
      expect(jsonDecode(written!.single), isA<Map<String, dynamic>>());
    });

    test('schreibt Pläne als StringList', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: <SyncPart>[
            SyncPayload.describePart('offlineVPData', <Map<String, dynamic>>[
              <String, dynamic>{'date': '2026-09-30', 'name': 'Plan'},
            ]),
          ],
          tombstones: const <SyncTombstone>[],
          settings: const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 9, 30),
        ),
      );

      final List<String>? written = prefs.getStringList('offlineVPData');
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
