import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncCredentials.dart';
import 'package:substitute/services/sync/SyncEngine.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncMerge.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Redet mit der **echten** Supabase-Instanz.
///
/// Überspringen statt Fehlschlagen, wenn keine erreichbar ist – ein
/// Netzwerkfehler darf einen Offline-Build nicht rot anstreichen. Aufruf:
///
///   flutter test test/sync_live_test.dart
///
/// Voraussetzung: `docs/server-supabase/schema.sql` wurde angewendet und die
/// vier Functions sind deployt.
void main() {
  final String url = SyncEngine.defaultServerUrl;
  final SyncApiClient client =
      SyncApiClient(baseUrl: Uri.parse(url));
  final String chainId =
      'live-test-${DateTime.now().toUtc().millisecondsSinceEpoch}';

  var reachable = false;

  setUpAll(() async {
    reachable = await client.isServerRunning();
    if (!reachable) {
      // ignore: avoid_print
      print('  ⚠ $url ist nicht erreichbar – Live-Tests übersprungen.');
    }
  });

  tearDownAll(() => client.dispose());

  group('Live gegen Supabase', () {
    test('der Server antwortet', () async {
      if (!reachable) return;
      expect(await client.isServerRunning(), isTrue);
    });

    test('ein Snapshot kommt unverändert wieder', () async {
      if (!reachable) return;

      final Map<String, dynamic> envelope = <String, dynamic>{
        'v': 1,
        'iv': 'aXY=',
        'ct': 'Y2lwaGVy',
        'mac': 'bWFj',
        'kdf': <String, dynamic>{'alg': 'pbkdf2-sha256', 'iter': 120000},
      };

      await client.pushSnapshot(
        chainId,
        deviceId: 'live-1',
        deviceName: 'Live-Gerät',
        envelope: envelope,
        includesSettings: true,
        updatedAt: DateTime.now().toUtc(),
      );

      final SyncChainSnapshot snapshot = await client.fetchChain(chainId);
      final ChainSnapshot stored = snapshot.snapshots
          .firstWhere((ChainSnapshot s) => s.deviceId == 'live-1');
      expect(stored.envelope['ct'], 'Y2lwaGVy');
      expect(stored.envelope['v'], 1);

      final List<SyncDevice> devices = await client.fetchDevices(chainId);
      final SyncDevice device =
          devices.firstWhere((SyncDevice d) => d.deviceId == 'live-1');
      expect(device.deviceName, 'Live-Gerät');
      expect(device.includesSettings, isTrue);
    });

    test('der Drahtwert traegt die Zeitzone mit', () async {
      if (!reachable) return;
      // `SyncDevice.fromJson` rechnet bewusst in Ortszeit um – für die
      // Anzeige richtig, aber damit lässt sich nicht prüfen, ob die
      // Übertragung stimmt. Deshalb hier der Rohwert.
      final http.Response response = await http.get(
        Uri.parse('$url/functions/v1/chain-snapshots'
            '?chain_id=eq.$chainId&devices=1'),
        headers: <String, String>{'apikey': SyncCredentials.publishableKey},
      );
      expect(response.statusCode, 200);
      final List<dynamic> devices =
          (jsonDecode(response.body) as Map)['devices'] as List<dynamic>;
      final String raw = (devices.first as Map)['updatedAt'] as String;
      // Ohne Zeitzonenzusatz würde die App die UTC-Zeit als Ortszeit lesen
      // und die Einträge um Stunden verschieben.
      expect(raw, endsWith('Z'));
    });

    test('ein Gerät hat genau einen Snapshot', () async {
      if (!reachable) return;
      for (int i = 0; i < 3; i++) {
        await client.pushSnapshot(
          chainId,
          deviceId: 'live-1',
          deviceName: 'Runde $i',
          envelope: <String, dynamic>{'v': 1, 'iv': 'a', 'ct': 'b', 'mac': 'c', 'kdf': <String, dynamic>{}},
          includesSettings: false,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      final List<SyncDevice> devices = await client.fetchDevices(chainId);
      expect(devices.where((SyncDevice d) => d.deviceId == 'live-1').length, 1);
    });

    test('zwei Geraete teilen sich die Kette, und ein Geraet kann gehen',
        () async {
      if (!reachable) return;
      final String two = '$chainId-zwei';
      for (final String id in <String>['a', 'b']) {
        await client.pushSnapshot(
          two,
          deviceId: id,
          deviceName: 'Gerät $id',
          envelope: <String, dynamic>{'v': 1, 'iv': 'a', 'ct': 'b', 'mac': 'c', 'kdf': <String, dynamic>{}},
          includesSettings: false,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      expect((await client.fetchDevices(two)).length, 2);

      await client.leaveChain(two, 'b');
      final List<SyncDevice> after = await client.fetchDevices(two);
      expect(after.length, 1);
      expect(after.single.deviceId, 'a');

      await client.deleteChain(two);
    });

    test('die Geraeteliste von aussen ist gesperrt', () async {
      if (!reachable) return;
      // Ohne apikey kommt man nicht bis zum Code.
      final http.Response denied = await http.get(
        Uri.parse('$url/rest/v1/chain_snapshots?select=*&limit=1'),
      );
      expect(denied.statusCode, anyOf(401, 403));
    });

    test('das Verzeichnis antwortet und enthaelt keine Hüllen', () async {
      if (!reachable) return;
      final List<ShareOwner> people = await client.fetchDirectory('12345');
      // Der Inhalt darf nicht mitgeliefert werden – daran entscheidet sich,
      // ob der Server blind ist.
      final String raw = jsonEncode(
        people
            .map((ShareOwner p) => p.shares)
            .expand((List<ShareSummary> s) => s)
            .toList(),
      );
      expect(raw.contains('byUsername'), isFalse);
      expect(raw.contains('"ct"'), isFalse);
    });

    test('ein unbekannter Share ist ein 404, kein 500er', () async {
      if (!reachable) return;
      expect(
        () => client.fetchShare('gibt-es-nicht-${chainId.length}'),
        throwsA(isA<SyncException>().having(
          (SyncException e) => e.status,
          'status',
          anyOf(404, 400),
        )),
      );
    });

    test('ein kompletter Sync-Lauf funktioniert', () async {
      if (!reachable) return;

      SharedPreferences.setMockInitialValues(<String, Object>{
        'persons': <String>[
          jsonEncode(<String, dynamic>{'id': '1', 'name': 'Hans live'}),
        ],
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Live'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SyncEngine engine = SyncEngine(client: client);
      final SyncOutcome outcome = await engine.run(
        prefs,
        SyncState(
          passphrase: 'blue sky river seven apple candle',
          chainId: chainId,
          deviceId: 'live-1',
          deviceName: 'Live-Gerät',
          includeSettings: false,
          lastSync: null,
        ),
      );

      expect(outcome.succeeded, isTrue, reason: 'Fehler: ${outcome.error}');
      expect(outcome.pushed, isTrue);

      // Und die Daten sind wieder da, was der Merge geschrieben hat.
      expect(
        (prefs.getStringList(SchoolStorage.scopedKey(prefs, 'persons')) ?? [])
            .length,
        greaterThanOrEqualTo(1),
      );
    });

    test('ein Share legt an, liest und loescht sauber', () async {
      if (!reachable) return;
      final String shareId = 'live-share-${DateTime.now().millisecondsSinceEpoch}';

      await client.publishShare(
        shareId: shareId,
        username: 'blue sky',
        schoolNumber: '12345',
        displayName: 'Frau Müller',
        label: 'Meine Pläne',
        // Eine vollstaendige Huelle. `isValidEnvelope` verlangt alle fuenf
        // Felder – eine halbe wird mit 400 abgewiesen, was beim echten Geraet
        // wie ein Serverfehler aussieht.
        envelopes: <String, dynamic>{
          'byUsername': <String, dynamic>{
            'v': 1,
            'iv': 'aXY=',
            'ct': 'Y2lwaGVy',
            'mac': 'bWFj',
            'kdf': <String, dynamic>{
              'alg': 'pbkdf2-sha256',
              'iter': 120000,
              'salt': 'c2FsdA==',
            },
          },
        },
        searchable: true,
        isGlobal: false,
        updatedAt: DateTime.utc(2026, 10, 1),
      );

      final ShareRecord record = await client.fetchShare(shareId);
      expect(record.id, shareId);
      expect(record.hasPassword, isFalse);
      expect(record.isGlobal, isFalse);
      expect(record.envelopes.keys, contains('byUsername'));

      // Auch das Verzeichnis muss die Person nun finden.
      final List<ShareOwner> people = await client.fetchDirectory('12345');
      final ShareOwner owner = people.firstWhere(
        (ShareOwner p) => p.username == 'blue sky',
        orElse: () => throw StateError('nicht im Verzeichnis'),
      );
      expect(owner.displayName, 'Frau Müller');
      final ShareSummary summary = owner.shares
          .firstWhere((ShareSummary s) => s.id == shareId);
      expect(summary.hasPassword, isFalse);
      expect(summary.label, 'Meine Pläne');

      await client.deleteShare(shareId);
      expect(
        () => client.fetchShare(shareId),
        throwsA(isA<SyncException>()
            .having((SyncException e) => e.status, 'status', 404)),
      );
    });

    test('ein blockierter Anzeigename wird abgewiesen', () async {
      if (!reachable) return;
      // Der zweite Instanz des Filters: die App prueft selbst, aber ein
      // direkter Aufruf der Schnittstelle darf nicht durchkommen.
      await expectLater(
        client.publishShare(
          shareId: 'live-bad-${DateTime.now().millisecondsSinceEpoch}',
          username: 'blue sky',
          schoolNumber: '12345',
          displayName: 'Pornografie',
          label: 'Test',
          envelopes: <String, dynamic>{
            'byUsername': <String, dynamic>{
              'v': 1,
              'iv': 'aXY=',
              'ct': 'Y2lwaGVy',
              'mac': 'bWFj',
              'kdf': <String, dynamic>{},
            },
          },
          searchable: true,
          isGlobal: false,
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
        throwsA(isA<SyncException>()
            .having((SyncException e) => e.status, 'status', 400)),
      );
    });

    test('die Testdaten werden wieder entfernt', () async {
      if (!reachable) return;
      await client.deleteChain(chainId);
      final SyncChainSnapshot after = await client.fetchChain(chainId);
      expect(after.snapshots, isEmpty);
    });
  });
}
