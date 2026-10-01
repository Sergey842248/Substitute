import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncCredentials.dart';
import 'package:substitute/services/sync/SyncEngine.dart';

/// Prüft, dass der Client gegen eine Supabase-Instanz die richtige Form
/// benutzt: `/functions/v1/<name>` mit Query-Parametern und `apikey`-Header.
///
/// Vorher getestet wurde nur die Form des eigenen Servers (`sync.test`).
/// Genau die hat aber niemand geprüft, und ein Tippfehler darin wäre erst
/// beim ersten Sync auf einem echten Gerät aufgefallen.
void main() {
  /// Jede Anfrage wird hier festgehalten.
  final List<http.BaseRequest> sent = <http.BaseRequest>[];

  http.Client recordingClient([Map<String, dynamic>? cannedResponse]) {
    return MockClient((http.Request request) async {
      sent.add(request);
      return http.Response(
        jsonEncode(cannedResponse ?? <String, dynamic>{
              'chainId': 'c',
              'snapshots': <dynamic>[],
              'devices': <dynamic>[],
              'people': <dynamic>[],
              'id': 's',
              'envelopes': <String, dynamic>{},
            }),
        200,
      );
    });
  }

  SyncApiClient supabase([Map<String, dynamic>? canned]) => SyncApiClient(
        baseUrl: Uri.parse('https://abcxyz.supabase.co'),
        client: recordingClient(canned),
      );

  SyncApiClient own() => SyncApiClient(
        baseUrl: Uri.parse('https://sync.open-nexor.org'),
        client: recordingClient(),
      );

  setUp(sent.clear);

  group('SyncCredentials', () {
    test('erkennt eine Supabase-Adresse', () {
      expect(SyncCredentials.isSupabase(Uri.parse('https://abc.supabase.co')),
          isTrue);
      expect(SyncCredentials.isSupabase(Uri.parse('https://ABC.SUPABASE.CO')),
          isTrue);
    });

    test('erkennt den eigenen Server als solchen', () {
      expect(
        SyncCredentials.isSupabase(Uri.parse('https://sync.open-nexor.org')),
        isFalse,
      );
      expect(
        SyncCredentials.isSupabase(Uri.parse('http://127.0.0.1:8384')),
        isFalse,
      );
      // Eine Domain, die nur so heisst, zaehlt nicht.
      expect(
        SyncCredentials.isSupabase(Uri.parse('https://boese.supabase.co.evil.de')),
        isFalse,
      );
    });

    test('der Schlüssel in der App ist der oeffentliche', () {
      // Der Secret Key darf hier niemals auftauchen. Wenn das kippt, ist er
      // vermutlich in den Quelltext gerutscht.
      expect(SyncCredentials.publishableKey, startsWith('sb_publishable_'));
      expect(SyncCredentials.publishableKey, isNot(contains('sb_secret_')));
    });
  });

  group('Pfadform bei Supabase', () {
    test('setzt den Publishable Key als apikey-Kopf', () async {
      await supabase().fetchChain('c1');
      expect(sent.single.headers['apikey'],
          SyncCredentials.publishableKey);
    });

    test('schickt die Ketten-ID als Query-Parameter, ohne eq.', () async {
      await supabase().fetchChain('meine-kette');
      final Uri uri = sent.single.url;
      expect(uri.path, '/functions/v1/chain-snapshots');
      expect(uri.queryParameters['chain_id'], 'meine-kette');
      // Das 'eq.' gehoert in die Function, die den Wert zerlegt. Mit diesem
      // Praefix bekommt die Kette eine ID, die es nicht gibt.
      expect(uri.queryParameters['chain_id'], isNot(contains('eq.')));
    });

    test('fragt die Geraeteliste ueber devices=1 ab', () async {
      await supabase().fetchDevices('c1');
      final Uri uri = sent.single.url;
      expect(uri.path, '/functions/v1/chain-snapshots');
      expect(uri.queryParameters['devices'], '1');
      expect(uri.queryParameters['chain_id'], 'c1');
    });

    test('schickt einen Snapshot ohne Kette im Pfad', () async {
      await supabase().pushSnapshot(
        'c1',
        deviceId: 'd1',
        deviceName: 'Pixel',
        envelope: <String, dynamic>{'v': 1},
        includesSettings: true,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final http.Request request = sent.single as http.Request;
      expect(request.method, 'PUT');
      expect(request.url.path, '/functions/v1/chain-snapshots');
      // Die Kette steckt im Rumpf, nicht im Pfad.
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['chain_id'], 'c1');
      expect(body['device_id'], 'd1');
    });

    test('nimmt ein Geraet ueber device_id aus der Kette', () async {
      await supabase().leaveChain('c1', 'd1');
      final http.Request request = sent.single as http.Request;
      expect(request.method, 'DELETE');
      expect(request.url.path, '/functions/v1/chain-snapshots');
      expect(request.url.queryParameters['device_id'], 'd1');
      expect(request.url.queryParameters['chain_id'], 'c1');
    });

    test('loescht eine ganze Kette ohne device_id', () async {
      await supabase().deleteChain('c1');
      final Uri uri = sent.single.url;
      expect(uri.queryParameters['chain_id'], 'c1');
      expect(uri.queryParameters.containsKey('device_id'), isFalse);
    });

    test('holt einen Share ueber id', () async {
      await supabase().fetchShare('s1');
      final Uri uri = sent.single.url;
      expect(uri.path, '/functions/v1/shares');
      expect(uri.queryParameters['id'], 's1');
    });

    test('schickt einen Share ohne ID im Pfad', () async {
      await supabase().publishShare(
        shareId: 's1',
        username: 'blue sky',
        schoolNumber: '12345',
        displayName: 'Frau Müller',
        label: 'Pläne',
        envelopes: <String, dynamic>{'byUsername': <String, dynamic>{}},
        searchable: true,
        isGlobal: false,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final http.Request request = sent.single as http.Request;
      expect(request.url.path, '/functions/v1/shares');
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['id'], 's1');
      // Auch hier snake_case, sonst findet die Function die Schule nicht.
      expect((body['owner'] as Map)['school_number'], '12345');
      expect((body['owner'] as Map)['display_name'], 'Frau Müller');
      expect(body['is_global'], isFalse);
      expect(body['updated_at'], isA<String>());
    });

    test('holt das Verzeichnis ueber school_number', () async {
      await supabase().fetchDirectory('12345');
      final Uri uri = sent.single.url;
      expect(uri.path, '/functions/v1/directory');
      expect(uri.queryParameters['school_number'], '12345');
    });

    test('prueft den Status ueber functions/v1/health', () async {
      await supabase().isServerRunning();
      expect(sent.single.url.path, '/functions/v1/health');
      expect(sent.single.headers['apikey'],
          SyncCredentials.publishableKey);
    });
  });

  group('Pfadform beim eigenen Server bleibt unverändert', () {
    test('die Kette steht im Pfad, kein apikey', () async {
      await own().fetchChain('c1');
      final http.Request request = sent.single as http.Request;
      expect(request.url.path, '/v1/chain/c1');
      expect(request.url.query, isEmpty);
      expect(request.headers.containsKey('apikey'), isFalse);
    });

    test('die Geraeteliste hat den eigenen Zusatzpfad', () async {
      await own().fetchDevices('c1');
      expect(sent.single.url.path, '/v1/chain/c1/devices');
    });

    test('ein Snapshot geht an /v1/chain/{id}', () async {
      await own().pushSnapshot(
        'c1',
        deviceId: 'd1',
        deviceName: 'Pixel',
        envelope: <String, dynamic>{'v': 1},
        includesSettings: true,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final http.Request request = sent.single as http.Request;
      expect(request.url.path, '/v1/chain/c1');
    });

    test('ein Geraet verlaesst die Kette ueber devices/{id}', () async {
      await own().leaveChain('c1', 'd1');
      expect(sent.single.url.path, '/v1/chain/c1/devices/d1');
    });

    test('Share und Verzeichnis behalten ihre Pfade', () async {
      await own().fetchShare('s1');
      expect(sent.single.url.path, '/v1/share/s1');

      sent.clear();
      await own().fetchDirectory('12345');
      expect(sent.single.url.path, '/v1/directory/12345');

      sent.clear();
      await own().isServerRunning();
      expect(sent.single.url.path, '/v1/health');
    });
  });

  group('Die Voreinstellung zeigt auf Supabase', () {
    test('und wird erkannt', () async {
      expect(
        SyncCredentials.isSupabase(Uri.parse(SyncEngine.defaultServerUrl)),
        isTrue,
      );
    });

    test('die Adresse lässt sich pro Gerät überschreiben', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        // Ein eigener Server soll weiterhin moeglich sein.
        SyncEngine.serverUrlKey: 'https://sync.open-nexor.org',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(SyncEngine.serverUrl(prefs).host, 'sync.open-nexor.org');
    });

    test('ohne eigene Einstellung gilt die Supabase-Adresse', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(SyncEngine.serverUrl(prefs).host.endsWith('.supabase.co'),
          isTrue);
    });
  });
}
