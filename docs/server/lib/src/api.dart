import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'limits.dart';
import 'moderation.dart';
import 'store.dart';

/// Die HTTP-Schnittstelle des Sync-Servers.
///
/// Grundsatz: Der Server ist **blind**. Er sieht verschlüsselte Hüllen, keine
/// Pläne, keine Namen von Personen, keine Einstellungen. Alles, was er im
/// Klartext kennt, ist das, was für das Suchverzeichnis zwingend nötig ist:
/// Nutzername, Schulnummer, Anzeigename und die Liste der Shares.
class SyncApi {
  SyncApi(this.store, {this.apiToken, RateLimiter? rateLimiter})
      : _rateLimiter = rateLimiter ?? RateLimiter();

  final Store store;

  /// Optionales Geheimnis, das alle schreibenden Anfragen im Header
  /// `x-api-token` mitbringen müssen. Für den Betrieb mit dem Nginx nicht
  /// nötig (die App kennt kein Geheimnis, das sicher zu verteilen wäre), aber
  /// sinnvoll, wenn der Server ohne Reverse-Proxy erreichbar ist.
  final String? apiToken;

  final RateLimiter _rateLimiter;

  static const String jsonContentType = 'application/json; charset=utf-8';

  /// Beantwortet eine Anfrage. [remoteAddress] dient nur der Drosselung.
  Future<void> handle(
    HttpRequest request, {
    String? remoteAddress,
  }) async {
    final String path = request.uri.path;
    final String method = request.method;

    // Der Status-Endpunkt ist bewusst ohne Drosselung und ohne Token: Er
    // existiert genau dafür, dass die Statusseite auf GitHub Pages ihn
    // abfragen kann.
    if (path == '/v1/health' && method == 'GET') {
      await _json(request, HttpStatus.ok, <String, dynamic>{
        'status': 'running',
        'version': 1,
      });
      return;
    }

    final String identity = remoteAddress ?? request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final bool writes = method != 'GET' && method != 'HEAD';
    if (!_rateLimiter.allow(identity, writes: writes)) {
      await _error(request, HttpStatus.tooManyRequests, 'tooManyRequests');
      return;
    }

    if (apiToken != null && writes) {
      if (request.headers.value('x-api-token') != apiToken) {
        await _error(request, HttpStatus.unauthorized, 'unauthorized');
        return;
      }
    }

    if (request.contentLength > Limits.maxBodyBytes) {
      await _error(request, HttpStatus.requestEntityTooLarge, 'tooLarge');
      return;
    }

    try {
      final List<String> segments = _segments(path);
      if (segments.isEmpty || segments.first != 'v1') {
        await _error(request, HttpStatus.notFound, 'unknownEndpoint');
        return;
      }
      final List<String> route = segments.sublist(1);
      if (route.isEmpty) {
        await _error(request, HttpStatus.notFound, 'unknownEndpoint');
        return;
      }

      if (route.first == 'chain') {
        await _chain(request, method, route.sublist(1));
      } else if (route.first == 'share') {
        await _share(request, method, route);
      } else if (route.first == 'directory') {
        await _directory(request, method, route.sublist(1));
      } else {
        await _error(request, HttpStatus.notFound, 'unknownEndpoint');
      }
    } on FormatException catch (error) {
      await _error(request, HttpStatus.badRequest, error.message.toString());
    } catch (error) {
      // Der Server darf nicht mit einem Stacktrace antworten – das würde
      // Pfade und Struktur verraten. Der Fehler wird geloggt, die Antwort
      // bleibt generisch.
      stderr.writeln('unhandled error: $error');
      await _error(request, HttpStatus.internalServerError, 'serverError');
    }
  }

  // ------------------------------------------------------------ Sync-Kette

  /// `GET    /v1/chain/{chainId}`                  alle Snapshots der Kette
  /// `PUT    /v1/chain/{chainId}`                  Snapshot dieses Geräts
  /// `GET    /v1/chain/{chainId}/devices`          Geräteliste
  /// `DELETE /v1/chain/{chainId}/devices/{id}`     Gerät verlässt die Kette
  /// `DELETE /v1/chain/{chainId}`                  Kette vollständig löschen
  Future<void> _chain(
    HttpRequest request,
    String method,
    List<String> route,
  ) async {
    if (route.isEmpty) {
      await _error(request, HttpStatus.notFound, 'unknownEndpoint');
      return;
    }
    final String chainId = _identifier(route[0]);

    if (method == 'GET' && route.length == 2 && route[1] == 'devices') {
      final List<Map<String, dynamic>> devices = store
          .chain(chainId)
          .map((Map<String, dynamic> snapshot) => <String, dynamic>{
                'deviceId': snapshot['deviceId'],
                'deviceName': snapshot['deviceName'],
                'updatedAt': snapshot['updatedAt'],
                'includesSettings': snapshot['includesSettings'],
              })
          .toList();
      await _json(request, HttpStatus.ok, <String, dynamic>{
        'chainId': chainId,
        'devices': devices,
      });
      return;
    }

    if (method == 'GET' && route.length == 1) {
      final List<Map<String, dynamic>> snapshots = store.chain(chainId);
      await _json(request, HttpStatus.ok, <String, dynamic>{
        'chainId': chainId,
        'snapshots': snapshots,
        'serverTime': DateTime.now().toUtc().toIso8601String(),
      });
      return;
    }

    if (method == 'PUT' && route.length == 1) {
      final Map<String, dynamic> body = await _readJson(request);
      final Map<String, dynamic>? validated = _validateSnapshot(body);
      if (validated == null) {
        await _error(request, HttpStatus.badRequest, 'invalidSnapshot');
        return;
      }
      if (store.chain(chainId).length >= Limits.maxDevicesPerChain &&
          !store.chain(chainId).any((Map<String, dynamic> s) =>
              s['deviceId'] == validated['deviceId'])) {
        await _error(request, HttpStatus.conflict, 'tooManyDevices');
        return;
      }
      await store.putChainSnapshot(chainId, validated);
      await _json(request, HttpStatus.ok, <String, dynamic>{
        'chainId': chainId,
        'deviceId': validated['deviceId'],
        'storedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return;
    }

    if (method == 'DELETE' && route.length == 3 && route[1] == 'devices') {
      final bool removed =
          await store.deleteChainSnapshot(chainId, _identifier(route[2]));
      await _json(request,
          removed ? HttpStatus.ok : HttpStatus.notFound, <String, dynamic>{
        'removed': removed,
      });
      return;
    }

    if (method == 'DELETE' && route.length == 1) {
      final bool removed = await store.deleteChain(chainId);
      await _json(request,
          removed ? HttpStatus.ok : HttpStatus.notFound, <String, dynamic>{
        'removed': removed,
      });
      return;
    }

    await _error(request, HttpStatus.notFound, 'unknownEndpoint');
  }

  /// Prüft einen eingehenden Snapshot und liefert ihn in bereinigter Form
  /// zurück – oder null, wenn etwas nicht stimmt.
  ///
  /// Der Server übernimmt hier *nur* Struktur: Gerätename, Zeitstempel und die
  ///verschlüsselte* Hülle. Die Hülle wird als Zeichenkette gespeichert, ohne
  /// dass der Server sie öffnet.
  static Map<String, dynamic>? _validateSnapshot(Map<String, dynamic> body) {
    final String deviceId = _identifier(body['deviceId']?.toString() ?? '');
    if (deviceId.isEmpty) return null;
    final Object? envelope = body['envelope'];
    if (envelope is! Map) return null;

    final String deviceName = (body['deviceName']?.toString() ?? '').trim();
    return <String, dynamic>{
      'deviceId': deviceId,
      'deviceName': deviceName.length > Limits.maxDeviceNameLength
          ? deviceName.substring(0, Limits.maxDeviceNameLength)
          : deviceName,
      'updatedAt': _timestamp(body['updatedAt']),
      'includesSettings': body['includesSettings'] == true,
      'envelope': jsonEncode(envelope),
    };
  }

  // ----------------------------------------------------------------- Shares

  /// `GET    /v1/share/{shareId}`     ein Share
  /// `PUT    /v1/share/{shareId}`     anlegen oder aktualisieren
  /// `DELETE /v1/share/{shareId}`     löschen
  Future<void> _share(
    HttpRequest request,
    String method,
    List<String> route,
  ) async {
    if (route.length != 2) {
      await _error(request, HttpStatus.notFound, 'unknownEndpoint');
      return;
    }
    final String shareId = _identifier(route[1]);

    if (method == 'GET') {
      final Map<String, dynamic>? share = store.share(shareId);
      if (share == null) {
        await _error(request, HttpStatus.notFound, 'shareNotFound');
        return;
      }
      await _json(request, HttpStatus.ok, share);
      return;
    }

    if (method == 'PUT') {
      final Map<String, dynamic> body = await _readJson(request);
      final Map<String, dynamic>? share = _validateShare(shareId, body);
      if (share == null) {
        await _error(request, HttpStatus.badRequest, 'invalidShare');
        return;
      }
      if (store.share(shareId) == null) {
        final int owned = _sharesOfUser(
          share['ownerSchoolNumber']?.toString() ?? '',
          share['ownerUsername']?.toString() ?? '',
        );
        if (owned >= Limits.maxSharesPerUser) {
          await _error(request, HttpStatus.conflict, 'tooManyShares');
          return;
        }
      }
      await store.putShare(share);
      await _json(request, HttpStatus.ok, <String, dynamic>{
        'id': shareId,
        'storedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return;
    }

    if (method == 'DELETE') {
      final Map<String, dynamic>? share = store.share(shareId);
      if (share == null) {
        await _error(request, HttpStatus.notFound, 'shareNotFound');
        return;
      }
      await store.deleteShare(shareId);
      await _json(request, HttpStatus.ok, <String, dynamic>{'removed': true});
      return;
    }

    await _error(request, HttpStatus.notFound, 'unknownEndpoint');
  }

  /// Prüft einen eingehenden Share.
  ///
  /// Der Anzeigename wird serverseitig erneut auf anstößige Begriffe geprüft –
  /// die Prüfung der App allein ist nicht vertrauenswürdig, weil die
  /// Schnittstelle auch ohne die App aufrufbar ist.
  static Map<String, dynamic>? _validateShare(
    String shareId,
    Map<String, dynamic> body,
  ) {
    final Map<String, dynamic>? owner = _asMap(body['owner']);
    if (owner == null) return null;

    final String username = (owner['username']?.toString() ?? '').trim();
    final String schoolNumber = (owner['schoolNumber']?.toString() ?? '').trim();
    final String displayName = (owner['displayName']?.toString() ?? '').trim();
    if (username.isEmpty || username.length > Limits.maxUsernameLength) {
      return null;
    }
    if (schoolNumber.isEmpty || schoolNumber.length > 32) return null;
    if (!Moderation.checkDisplayName(displayName).isOk) return null;

    final Object? envelopes = body['envelopes'];
    if (envelopes is! Map || envelopes.isEmpty) return null;
    // Jeder Eintrag muss eine Hülle sein, die der Server nicht zu lesen
    // braucht – er speichert sie als Zeichenkette.
    final Map<String, dynamic> stored = <String, dynamic>{};
    for (final String slot in <String>['byUsername', 'byPassword', 'bySchool']) {
      final Object? envelope = envelopes[slot];
      if (envelope is Map) stored[slot] = jsonEncode(envelope);
    }
    if (stored.isEmpty) return null;

    final String label = (body['label']?.toString() ?? '').trim();
    return <String, dynamic>{
      'id': shareId,
      'owner': <String, dynamic>{
        'username': username,
        'schoolNumber': schoolNumber,
        'displayName': displayName,
      },
      'ownerUsername': username,
      'ownerSchoolNumber': schoolNumber,
      'label': label.length > Limits.maxLabelLength
          ? label.substring(0, Limits.maxLabelLength)
          : label,
      'searchable': body['searchable'] == true,
      'isGlobal': body['isGlobal'] == true,
      'hasPassword': stored.containsKey('byPassword'),
      'unlockableWithSchoolCredentials': stored.containsKey('bySchool'),
      'updatedAt': _timestamp(body['updatedAt']),
      'envelopes': stored,
    };
  }

  /// Wie viele Shares hat diese Person an dieser Schule bereits?
  int _sharesOfUser(String schoolNumber, String username) {
    return store
        .directory(schoolNumber)
        .where((Map<String, dynamic> share) =>
            (share['ownerUsername']?.toString() ?? '') == username)
        .length;
  }

  // -------------------------------------------------------------- Verzeichnis

  /// `GET /v1/directory/{schoolNumber}`
  ///
  /// Liefert die Personen dieser Schulnummer, die mindestens einen Share
  /// ausdrücklich als "suchbar" markiert haben – und die geschützten
  /// Hüllen selbstverständlich nicht.
  Future<void> _directory(
    HttpRequest request,
    String method,
    List<String> route,
  ) async {
    if (method != 'GET' || route.length != 1) {
      await _error(request, HttpStatus.notFound, 'unknownEndpoint');
      return;
    }
    final String schoolNumber = _identifier(route[0]);
    final List<Map<String, dynamic>> shares = store.directory(schoolNumber);

    // Nach Person gruppieren, wie es die Suchliste in der App anzeigt.
    final Map<String, Map<String, dynamic>> people =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> share in shares) {
      final Map<String, dynamic>? owner = _asMap(share['owner']);
      if (owner == null) continue;
      final String username = owner['username']?.toString() ?? '';
      final Map<String, dynamic> person = people.putIfAbsent(
        username,
        () => <String, dynamic>{
          'username': username,
          'displayName': owner['displayName']?.toString() ?? username,
          'shares': <Map<String, dynamic>>[],
        },
      );
      (person['shares'] as List<Map<String, dynamic>>).add(<String, dynamic>{
        'id': share['id'],
        'label': share['label'],
        'isGlobal': share['isGlobal'] == true,
        'hasPassword': share['hasPassword'] == true,
        'updatedAt': share['updatedAt'],
      });
    }

    await _json(request, HttpStatus.ok, <String, dynamic>{
      'schoolNumber': schoolNumber,
      'people': people.values.toList(),
    });
  }

  // ----------------------------------------------------------------- Helfer

  static List<String> _segments(String path) => path
      .split('/')
      .where((String segment) => segment.isNotEmpty)
      .map(Uri.decodeComponent)
      .toList();

  /// Bezeichner dürfen nur aus den Zeichen bestehen, die die App selbst
  /// verwendet (base64url eines SHA-256-Digests). Alles andere wird
  /// abgelehnt, statt in Dateinamen oder Vergleichen weiterzukommen.
  static String _identifier(String raw) {
    final String cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return cleaned.length > 128 ? '' : cleaned;
  }

  static String _timestamp(Object? value) {
    final DateTime parsed = DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    return parsed.toIso8601String();
  }

  static Map<String, dynamic>? _asMap(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  /// Liest und dekodiert den Anfragetext.
  ///
  /// Jeder Fehlerfall endet als [FormatException] mit einem kurzen Code, den
  /// der Client übersetzen kann – die tatsächliche Meldung (`Invalid
  /// Unicode`, `Unexpected character` o.ä.) sagt einem Angreifer mehr über die
  /// Verarbeitung als nötig.
  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final String raw;
    try {
      raw = await utf8.decoder.bind(request).join();
    } on FormatException {
      throw const FormatException('invalidEncoding');
    } on RangeError {
      throw const FormatException('invalidEncoding');
    }
    if (raw.isEmpty) return <String, dynamic>{};

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('invalidJson');
    }
    if (decoded is! Map) throw const FormatException('invalidJson');
    return decoded.cast<String, dynamic>();
  }

  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.parse(jsonContentType)
      // Die Statusseite auf GitHub Pages fragt den Endpunkt aus dem Browser
      // ab – ohne diese Header blockiert der Browser die Anfrage.
      ..headers.set('access-control-allow-origin', '*')
      ..headers.set('cache-control', 'no-store');
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  /// Antwortet mit einem Fehlercode.
  ///
  /// Wichtig: Der Body wird vorher **geleert**. Wird eine Anfrage abgelehnt,
  /// ohne dass ihr Body gelesen wurde, bleiben die Bytes im
  /// Keep-alive-Puffer liegen – die nächste Anfrage auf derselben Verbindung
  /// liest dann Müll und scheitert scheinbar grundlos. Das ist im Betrieb
  /// nicht sichtbar und in Tests verwirrend, deshalb wird hier bewusst
  /// drainiert.
  Future<void> _error(HttpRequest request, int status, String code) async {
    await _drain(request);
    await _json(request, status, <String, dynamic>{'error': code});
  }

  /// Liest einen Body, den niemand mehr braucht, begrenzt auf [Limits].
  ///
  /// Ist der Body größer als die Obergrenze, wird er nicht mehr gelesen und
  /// die Verbindung geschlossen – sonst müsste der Server beliebig große
  /// Datenmengen entsorgen, nur um sie zu verwerfen.
  Future<void> _drain(HttpRequest request) async {
    try {
      int read = 0;
      await for (final List<int> chunk in request) {
        read += chunk.length;
        if (read > Limits.maxBodyBytes) {
          request.response.headers.set('connection', 'close');
          return;
        }
      }
    } catch (_) {
      // Der Client hat den Upload abgebrochen – für die Antwort egal.
    }
  }
}
