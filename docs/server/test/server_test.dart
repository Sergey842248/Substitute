import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:substitute_sync_server/src/api.dart';
import 'package:substitute_sync_server/src/limits.dart';
import 'package:substitute_sync_server/src/store.dart';
import 'package:test/test.dart';

/// Antwort einer Testanfrage.
class Response {
  Response(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;

  String get error => body['error']?.toString() ?? '';
}

void main() {
  late Directory dataDir;
  late Store store;
  late SyncApi api;
  late HttpServer server;
  late String base;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('substitute-sync-test');
    store = Store(dataDir);
    await store.open();
    api = SyncApi(store);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.address}:${server.port}';
    unawaited(serveRequests(server, api));
  });

  tearDown(() async {
    await server.close(force: true);
    if (dataDir.existsSync()) await dataDir.delete(recursive: true);
  });

  Future<Response> call(
    String method,
    String path, {
    Object? body,
  }) async {
    final HttpClient client = HttpClient();
    final HttpClientRequest request =
        await client.openUrl(method, Uri.parse('$base$path'));
    if (body != null) {
      request.headers.contentType = ContentType.json;
      // Ausdrücklich als UTF-8 schicken: `HttpClientRequest.write` kodiert
      // einen String ansonsten in Latin-1, sobald kein Charset genannt ist –
      // ein "ä" käme dann als einzelnes Byte an und der Server könnte den
      // Text nicht lesen. Genau diesen Fall gibt es in der echten App nicht
      // (das http-Paket sendet immer UTF-8), aber der Test soll es nicht
      // zufällig verstecken.
      request.add(utf8.encode(jsonEncode(body)));
    }
    final HttpClientResponse response = await request.close();
    final String raw = await utf8.decoder.bind(response).join();
    client.close();
    return Response(
      response.statusCode,
      raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Gültige Hülle – der Server darf sie nicht lesen, also reicht Struktur.
  Map<String, dynamic> envelope() => <String, dynamic>{
        'v': 1,
        'iv': 'aXY=',
        'ct': 'Y2lwaGVy',
        'mac': 'bWFj',
        'kdf': <String, dynamic>{'alg': 'pbkdf2-sha256', 'iter': 120000},
      };

  Map<String, dynamic> snapshot({String device = 'device-a'}) => <String, dynamic>{
        'deviceId': device,
        'deviceName': 'Pixel 8',
        'updatedAt': '2026-09-30T10:00:00.000Z',
        'includesSettings': true,
        'envelope': envelope(),
      };

  Map<String, dynamic> share({
    String id = 'share-1',
    String username = 'blue-sky-river-seven',
    String school = '12345',
    String displayName = 'Frau Muster',
    bool searchable = true,
    bool global = false,
    Map<String, dynamic>? envelopes,
  }) =>
      <String, dynamic>{
        'id': id,
        'owner': <String, dynamic>{
          'username': username,
          'schoolNumber': school,
          'displayName': displayName,
        },
        'label': 'Vertretungspläne',
        'searchable': searchable,
        'isGlobal': global,
        'updatedAt': '2026-09-30T10:00:00.000Z',
        'envelopes': envelopes ??
            <String, dynamic>{'byUsername': envelope(), 'bySchool': envelope()},
      };

  group('GET /v1/health', () {
    test('reports that the server is running', () async {
      final Response response = await call('GET', '/v1/health');
      expect(response.status, 200);
      expect(response.body['status'], 'running');
    });

    test('allows cross-origin reads so the status page can ask', () async {
      final HttpClient client = HttpClient();
      final HttpClientRequest request =
          await client.openUrl('GET', Uri.parse('$base/v1/health'));
      final HttpClientResponse response = await request.close();
      await response.drain<void>();
      expect(
        response.headers.value('access-control-allow-origin'),
        '*',
        reason: 'GitHub Pages fragt den Endpunkt aus dem Browser ab',
      );
      client.close();
    });
  });

  group('Sync chain', () {
    test('stores a snapshot and returns it', () async {
      final Response put = await call('PUT', '/v1/chain/abc', body: snapshot());
      expect(put.status, 200);

      final Response get = await call('GET', '/v1/chain/abc');
      expect(get.status, 200);
      final List<dynamic> snapshots = get.body['snapshots'] as List<dynamic>;
      expect(snapshots, hasLength(1));
      expect((snapshots.first as Map<String, dynamic>)['deviceId'], 'device-a');
    });

    test('returns an empty list for an unknown chain', () async {
      final Response get = await call('GET', '/v1/chain/unknown');
      expect(get.status, 200);
      expect(get.body['snapshots'], isEmpty);
    });

    test('keeps one snapshot per device', () async {
      await call('PUT', '/v1/chain/abc', body: snapshot(device: 'a'));
      await call(
        'PUT',
        '/v1/chain/abc',
        body: <String, dynamic>{
          ...snapshot(device: 'a'),
          'updatedAt': '2026-09-30T11:00:00.000Z',
        },
      );
      final Response get = await call('GET', '/v1/chain/abc');
      expect(get.body['snapshots'], hasLength(1));
      final Map<String, dynamic> only =
          (get.body['snapshots'] as List<dynamic>).first as Map<String, dynamic>;
      expect(only['updatedAt'], '2026-09-30T11:00:00.000Z');
    });

    test('orders snapshots oldest first', () async {
      await call(
        'PUT',
        'v1'.startsWith('v1') ? '/v1/chain/abc' : '',
        body: <String, dynamic>{
          ...snapshot(device: 'a'),
          'updatedAt': '2026-09-30T10:00:00.000Z',
        },
      );
      await call(
        'PUT',
        '/v1/chain/abc',
        body: <String, dynamic>{
          ...snapshot(device: 'b'),
          'updatedAt': '2026-09-30T09:00:00.000Z',
        },
      );
      final List<dynamic> snapshots =
          (await call('GET', '/v1/chain/abc')).body['snapshots'] as List<dynamic>;
      expect((snapshots.first as Map<String, dynamic>)['deviceId'], 'b');
    });

    test('lists the devices in a chain', () async {
      await call('PUT', '/v1/chain/abc', body: snapshot(device: 'a'));
      await call('PUT', '/v1/chain/abc', body: snapshot(device: 'b'));
      final Response devices = await call('GET', '/v1/chain/abc/devices');
      expect(devices.status, 200);
      expect(devices.body['devices'], hasLength(2));
    });

    test('lets a device leave the chain', () async {
      await call('PUT', '/v1/chain/abc', body: snapshot(device: 'a'));
      await call('PUT', '/v1/chain/abc', body: snapshot(device: 'b'));

      final Response removed = await call('DELETE', '/v1/chain/abc/devices/a');
      expect(removed.status, 200);
      expect(removed.body['removed'], isTrue);

      final List<dynamic> left =
          (await call('GET', '/v1/chain/abc')).body['snapshots'] as List<dynamic>;
      expect(left, hasLength(1));
      expect((left.first as Map<String, dynamic>)['deviceId'], 'b');
    });

    test('reports a device that was not in the chain', () async {
      final Response removed = await call('DELETE', '/v1/chain/abc/devices/zz');
      expect(removed.status, 404);
    });

    test('rejects a snapshot without a device id', () async {
      final Response response = await call('PUT', '/v1/chain/abc',
          body: <String, dynamic>{'envelope': envelope()});
      expect(response.status, 400);
      expect(response.error, 'invalidSnapshot');
    });

    test('rejects a snapshot without an envelope', () async {
      final Response response = await call('PUT', '/v1/chain/abc',
          body: <String, dynamic>{'deviceId': 'a'});
      expect(response.status, 400);
    });

    test('refuses more devices than the limit allows', () async {
      for (int i = 0; i < Limits.maxDevicesPerChain; i++) {
        final Response response =
            await call('PUT', '/v1/chain/abc', body: snapshot(device: 'd$i'));
        expect(response.status, 200, reason: 'device $i');
      }
      final Response tooMany =
          await call('PUT', '/v1/chain/abc', body: snapshot(device: 'overflow'));
      expect(tooMany.status, 409);
      expect(tooMany.error, 'tooManyDevices');
    });

    test('deletes a whole chain', () async {
      await call('PUT', '/v1/chain/abc', body: snapshot());
      expect((await call('DELETE', '/v1/chain/abc')).status, 200);
      expect((await call('GET', '/v1/chain/abc')).body['snapshots'], isEmpty);
    });

    test('does not let an id escape the data directory', () async {
      // Der Bezeichner wird bereinigt statt als Pfad interpretiert.
      final Response response = await call('GET', '/v1/chain/..%2F..%2Fetc%2Fpasswd');
      expect(response.status, 200);
      expect(response.body['snapshots'], isEmpty);
    });
  });

  group('Shares', () {
    test('stores and returns a share', () async {
      expect((await call('PUT', '/v1/share/share-1', body: share())).status, 200);
      final Response get = await call('GET', '/v1/share/share-1');
      expect(get.status, 200);
      expect(get.body['id'], 'share-1');
      expect(get.body['hasPassword'], isFalse);
      expect(get.body['unlockableWithSchoolCredentials'], isTrue);
    });

    test('marks a password protected share', () async {
      final Response response = await call(
        'PUT',
        '/v1/share/share-1',
        body: share(
          envelopes: <String, dynamic>{
            'byPassword': envelope(),
            'bySchool': envelope(),
          },
        ),
      );
      expect(response.status, 200);
      final Map<String, dynamic> stored =
          (await call('GET', '/v1/share/share-1')).body;
      expect(stored['hasPassword'], isTrue);
      // Ohne Passwort-Slot darf der Nutzername allein den Share nicht öffnen.
      expect(stored['envelopes'].toString().contains('byUsername'), isFalse);
    });

    test('stores the envelope opaquely', () async {
      final Map<String, dynamic> secret = envelope();
      secret['ct'] = 'SEHRGEHEIMERPLAN';
      await call('PUT', '/v1/share/share-1', body: share(envelopes: <String, dynamic>{'byUsername': secret}));
      final Map<String, dynamic> stored = (await call('GET', '/v1/share/share-1')).body;
      // Der Server legt die Hülle als Zeichenkette ab, ohne sie zu öffnen –
      // der Inhalt bleibt genau das, was die App hineingeschrieben hat.
      expect((stored['envelopes'] as Map<String, dynamic>)['byUsername'],
          isA<String>());
    });

    test('rejects a share without an owner', () async {
      final Response response = await call('PUT', '/v1/share/share-1',
          body: <String, dynamic>{'envelopes': <String, dynamic>{'byUsername': envelope()}});
      expect(response.status, 400);
    });

    test('rejects a share without any envelope', () async {
      final Response response = await call('PUT', '/v1/share/share-1',
          body: <String, dynamic>{'owner': share()['owner'], 'envelopes': <String, dynamic>{}});
      expect(response.status, 400);
    });

    test('rejects a share whose display name is offensive, even if the app let it through', () async {
      for (final String name in <String>['Arschloch', 'f-u-c-k', 'Scheißkopf', 'SCHEISS', 'n1gger']) {
        final Response response = await call(
          'PUT',
          'v1' == 'v1' ? '/v1/share/share-x' : '',
          body: share(displayName: name),
        );
        expect(response.status, 400, reason: 'display name "$name" must be rejected');
      }
    });

    test('rejects a share with a markup display name', () async {
      final Response response = await call(
          'PUT', '/v1/share/share-1', body: share(displayName: '<script>x</script>'));
      expect(response.status, 400);
    });

    test('accepts ordinary names including umlauts', () async {
      for (final String name in <String>['Frau Muster', 'Herr Müller-Schmidt', "O'Brien", 'Anna 5b']) {
        final Response response = await call(
            'PUT', '/v1/share/share-ok', body: share(displayName: name));
        expect(response.status, 200, reason: 'display name "$name" must be accepted');
      }
    });

    test('rejects an empty display name', () async {
      final Response response =
          await call('PUT', '/v1/share/share-1', body: share(displayName: '  '));
      expect(response.status, 400);
    });

    test('deletes a share', () async {
      await call('PUT', '/v1/share/share-1', body: share());
      expect((await call('DELETE', '/v1/share/share-1')).status, 200);
      expect((await call('GET', '/v1/share/share-1')).status, 404);
    });

    test('reports an unknown share', () async {
      expect((await call('GET', '/v1/share/nope')).status, 404);
    });
  });

  group('Directory (search menu)', () {
    test('only lists shares that were explicitly made searchable', () async {
      await call('PUT', '/v1/share/s1', body: share(id: 's1'));
      await call('PUT', '/v1/share/s2',
          body: share(id: 's2', searchable: false, username: 'other-user'));

      final Response directory = await call('GET', '/v1/directory/12345');
      final List<dynamic> people = directory.body['people'] as List<dynamic>;
      final List<dynamic> shares =
          (people.single as Map<String, dynamic>)['shares'] as List<dynamic>;
      expect(shares, hasLength(1));
      expect((shares.single as Map<String, dynamic>)['id'], 's1');
    });

    test('only lists people of the same school number', () async {
      await call('PUT', '/v1/share/s1', body: share(id: 's1', school: '12345'));
      await call('PUT', '/v1/share/s2',
          body: share(id: 's2', school: '99999', username: 'someone-else'));

      final Response own = await call('GET', '/v1/directory/12345');
      expect(own.body['people'], hasLength(1));
      final Response other = await call('GET', '/v1/directory/99999');
      expect(other.body['people'], hasLength(1));
    });

    test('a global share is still not listed in a foreign school', () async {
      // "Global" heißt: jeder kann ihn per Nutzername verwenden. Es heißt
      // nicht, dass er in fremden Schulen auftaucht.
      await call('PUT', '/v1/share/s1',
          body: share(id: 's1', school: '12345', global: true));
      expect((await call('GET', '/v1/directory/99999')).body['people'], isEmpty);
    });

    test('a global share can be read by its id from anywhere', () async {
      await call('PUT', '/v1/share/s1',
          body: share(id: 's1', school: '12345', global: true));
      final Response get = await call('GET', '/v1/share/s1');
      expect(get.status, 200);
      expect(get.body['isGlobal'], isTrue);
    });

    test('groups all shares of one person under that person', () async {
      await call('PUT', '/v1/share/s1', body: share(id: 's1'));
      await call(
        'PUT',
        '/v1/share/s2',
        body: <String, dynamic>{...share(id: 's2'), 'label': 'Krankentracking'},
      );

      final List<dynamic> people =
          (await call('GET', '/v1/directory/12345')).body['people'] as List<dynamic>;
      expect(people, hasLength(1));
      expect(
        (people.single as Map<String, dynamic>)['shares'],
        hasLength(2),
      );
    });

    test('never exposes the encrypted envelopes in the directory', () async {
      await call('PUT', '/v1/share/s1', body: share());
      final String raw = jsonEncode((await call('GET', '/v1/directory/12345')).body);
      expect(raw.contains('byUsername'), isFalse);
      expect(raw.contains('ct'), isFalse);
    });

    test('is empty for a school nobody shares in', () async {
      final Response directory = await call('GET', '/v1/directory/00000');
      expect(directory.status, 200);
      expect(directory.body['people'], isEmpty);
    });
  });

  group('Store', () {
    test('survives a restart', () async {
      await call('PUT', '/v1/chain/abc', body: snapshot());
      await call('PUT', '/v1/share/share-1', body: share());

      final Store reopened = Store(dataDir);
      await reopened.open();
      expect(reopened.chain('abc'), hasLength(1));
      expect(reopened.share('share-1'), isNotNull);
    });

    test('rejects an id that would break out of the data directory', () async {
      final Store fresh = Store(dataDir);
      await fresh.open();
      await fresh.putShare(<String, dynamic>{'id': '../../escape'});
      // Bereinigt gespeichert – es liegt keine Datei außerhalb von dataDir.
      final List<String> written = dataDir
          .listSync(recursive: true)
          .whereType<File>()
          .map((File f) => f.path)
          .toList();
      expect(written.every((String path) => path.startsWith(dataDir.path)), isTrue);
    });

    test('a corrupt file does not take the server down', () async {
      await call('PUT', '/v1/chain/abc', body: snapshot());
      final File file = File('${dataDir.path}/chains/abc.json');
      await file.writeAsString('{kaputt');

      final Response get = await call('GET', '/v1/chain/abc');
      expect(get.status, 200);
      expect(get.body['snapshots'], isEmpty);
    });
  });

  group('Unknown routes', () {
    test('answer with 404', () async {
      expect((await call('GET', '/')).status, 404);
      expect((await call('GET', '/v1/nope')).status, 404);
      expect((await call('GET', '/nope')).status, 404);
    });
  });

  group('Rate limiting', () {
    test('blocks writes after the limit is reached', () async {
      final RateLimiter limiter = RateLimiter();
      for (int i = 0; i < Limits.writeRequestsPerMinute; i++) {
        expect(limiter.allow('10.0.0.1', writes: true), isTrue, reason: 'request $i');
      }
      expect(limiter.allow('10.0.0.1', writes: true), isFalse);
      // Andere IPs sind unberührt.
      expect(limiter.allow('10.0.0.2', writes: true), isTrue);
    });

    test('allows more reads than writes', () {
      final RateLimiter limiter = RateLimiter();
      for (int i = 0; i < Limits.readRequestsPerMinute; i++) {
        limiter.allow('10.0.0.3', writes: false);
      }
      expect(limiter.allow('10.0.0.3', writes: false), isFalse);
    });
  });

  group('Write token', () {
    test('is required for writes when configured', () async {
      final SyncApi protected = SyncApi(store, apiToken: 'geheim');
      final HttpServer local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(serveRequests(local, protected));
      final String localBase =
          'http://${local.address.address}:${local.port}';

      final HttpClient client = HttpClient();

      HttpClientRequest noToken =
          await client.openUrl('PUT', Uri.parse('$localBase/v1/share/s1'));
      noToken.add(utf8.encode(jsonEncode(share())));
      HttpClientResponse denied = await noToken.close();
      await denied.drain<void>();
      expect(denied.statusCode, 401);

      HttpClientRequest withToken =
          await client.openUrl('PUT', Uri.parse('$localBase/v1/share/s1'));
      withToken.headers.set('x-api-token', 'geheim');
      withToken.add(utf8.encode(jsonEncode(share())));
      HttpClientResponse allowed = await withToken.close();
      await allowed.drain<void>();
      expect(allowed.statusCode, 200);

      client.close();
      await local.close(force: true);
    });
  });
}

/// Beantwortet alle eingehenden Anfragen im Hintergrund.
Future<void> serveRequests(HttpServer server, SyncApi api) async {
  await for (final HttpRequest request in server) {
    await api.handle(request, remoteAddress: '127.0.0.1');
  }
}
