import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'SyncCredentials.dart';

/// Fehler des Sync-Servers, als verständlicher Code.
///
/// Die Oberfläche übersetzt [SyncException.code] in eine Meldung; die
/// englischen Texte sind nur der Fallback für Tests und Logs.
class SyncException implements Exception {
  const SyncException(this.code, {this.status});

  /// Der Fehlercode, z.B. `network`, `notFound`, `wrongPassphrase`.
  final String code;

  /// Der HTTP-Status, falls die Anfrage den Server erreicht hat.
  final int? status;

  /// true, wenn ein erneuter Versuch sinnvoll ist.
  bool get isTransient =>
      code == 'network' || code == 'timeout' || code == 'tooManyRequests';

  /// Die Meldung, die ohne Übersetzungsschlüssel angezeigt werden kann.
  String get message => defaultMessages[code] ?? 'The sync server reported an error ($code).';

  static const Map<String, String> defaultMessages = <String, String>{
    'network': 'The sync server could not be reached.',
    'timeout': 'The sync server took too long to answer.',
    'notFound': 'This sync code or share does not exist (any more).',
    'wrongPassphrase': 'Wrong code – or the data was changed on the way.',
    'forbidden': 'The server rejected this request.',
    'tooManyRequests': 'Too many requests. Please try again in a minute.',
    'conflict': 'This sync chain is full, or too many shares exist.',
    'serverError': 'The sync server has a problem.',
    'tooLarge': 'The data is too large for the server.',
    'invalidShare': 'This share is not allowed.',
    'serverUnreachable': 'The sync server is not configured or not running.',
  };

  @override
  String toString() => 'SyncException($code, status: $status)';
}

/// Ein Gerät in einer Sync-Kette, wie der Server es meldet.
class SyncDevice {
  const SyncDevice({
    required this.deviceId,
    required this.deviceName,
    required this.updatedAt,
    required this.includesSettings,
  });

  final String deviceId;
  final String deviceName;
  final DateTime updatedAt;
  final bool includesSettings;

  /// Der Name, den man in der Geräteliste anzeigt.
  String get displayName =>
      deviceName.trim().isEmpty ? 'Unknown device' : deviceName.trim();

  static SyncDevice fromJson(Map<String, dynamic> json) => SyncDevice(
        deviceId: json['deviceId']?.toString() ?? '',
        deviceName: json['deviceName']?.toString() ?? '',
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        includesSettings: json['includesSettings'] == true,
      );
}

/// Ein Share, wie der Server ihn beschreibt – **ohne** den Inhalt.
class ShareSummary {
  const ShareSummary({
    required this.id,
    required this.username,
    required this.displayName,
    required this.label,
    required this.isGlobal,
    required this.hasPassword,
    required this.updatedAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String label;
  final bool isGlobal;
  final bool hasPassword;
  final DateTime updatedAt;

  /// Wie der Share in der Liste beschriftet wird.
  String get displayLabel => label.trim().isEmpty ? 'Share' : label.trim();

  static ShareSummary fromJson(Map<String, dynamic> json) => ShareSummary(
        id: json['id']?.toString() ?? json['shareId']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        isGlobal: json['isGlobal'] == true,
        hasPassword: json['hasPassword'] == true,
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Eine Person mit allen ihren Shares – eine Zeile der Suchliste.
class ShareOwner {
  const ShareOwner({
    required this.username,
    required this.displayName,
    required this.shares,
  });

  final String username;
  final String displayName;
  final List<ShareSummary> shares;

  static ShareOwner fromJson(Map<String, dynamic> json) => ShareOwner(
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        shares: (json['shares'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ShareSummary.fromJson)
            .toList(),
      );
}

/// Der vollständige Share-Eintrag inklusive der verschlüsselten Hüllen.
class ShareRecord {
  const ShareRecord({
    required this.id,
    required this.envelopes,
    required this.hasPassword,
    required this.isGlobal,
    required this.updatedAt,
  });

  final String id;

  /// Die verschlüsselten Hüllen, nach Entsperrmethode benannt:
  /// `byUsername`, `byPassword`, `bySchool`.
  final Map<String, dynamic> envelopes;

  final bool hasPassword;
  final bool isGlobal;
  final DateTime updatedAt;

  /// Die Hülle, die mit [derivedKey] verschlüsselt wurde – oder null, wenn
  /// [derivedKey] zu keiner Hülle passt. Genau das ist der Test: Passt der
  /// abgeleitete Schlüssel zu keiner Hülle, ist die Entsperrmethode falsch.
  Map<String, dynamic>? envelopeFor(String derivedKeyId) =>
      envelopes[derivedKeyId];
}

/// Sprechername für die Entsperrmethode, die eine Hülle benutzt.
class ShareSlot {
  const ShareSlot._(this.id, this.label);

  /// Der Nutzername allein.
  static const ShareSlot byUsername = ShareSlot._('byUsername', 'byUsername');

  /// Der Nutzername zusammen mit dem gewählten Share-Passwort.
  static const ShareSlot byPassword = ShareSlot._('byPassword', 'byPassword');

  /// Die Schulzugangsdaten.
  static const ShareSlot bySchool = ShareSlot._('bySchool', 'bySchool');

  final String id;
  final String label;
}

/// Das Ergebnis eines erfolgreichen Pulls: die Kette plus die Geräte.
/// Die verschlüsselte Hülle eines einzelnen Geräts in einer Kette.
class ChainSnapshot {
  const ChainSnapshot({required this.deviceId, required this.envelope});

  final String deviceId;

  /// Die noch verschlüsselte Hülle – entschlüsselt wird sie in `SyncEngine`.
  final Map<String, dynamic> envelope;
}

/// Der vollständige Stand einer Kette nach einem Pull.
class SyncChainSnapshot {
  const SyncChainSnapshot({required this.devices, required this.snapshots});

  /// Die Geräte dieser Kette, wie der Server sie kennt.
  final List<SyncDevice> devices;

  /// Die Hüllen aller Geräte außer dem eigenen.
  final List<ChainSnapshot> snapshots;
}

/// Spricht mit dem Sync-Server.
///
/// Erwartet wird ausschließlich `application/json`; die eigentliche
/// Verschlüsselung passiert vorher in der App (End-to-End). Dieser Client
/// ist also ein Transportweg, kein Zugriffskanal.
class SyncApiClient {
  SyncApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        // Supabase verteilt die Functions unter /functions/v1/<name> und
        // erwartet den Bezeichner als Query-Parameter. Der eigene Server
        // nimmt ihn in den Pfad. Beides zu unterstuetzen kostet eine
        // Verzweigung und haelt den Betrieb ohne Zusatzkonfiguration offen.
        _isSupabase = SyncCredentials.isSupabase(baseUrl);

  /// Die Adresse des Servers.
  final Uri baseUrl;

  final http.Client _client;
  final bool _ownsClient;

  /// true, wenn die Edge Functions von Supabase angesprochen werden.
  final bool _isSupabase;

  /// true, wenn dieses Geraet den Publishable Key mitschicken muss.
  ///
  /// Supabase laesst keinen Aufruf ohne `apikey` durch das Gateway – auch
  /// dann nicht, wenn die Function selbst kein JWT prueft. Der eigene Server
  /// braucht keinen.
  bool get sendsApiKey => _isSupabase;

  static const Duration _timeout = Duration(seconds: 20);

  Uri _uri(String path) {
    final String base = baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  /// Wo ein eigener Snapshot hingesendet wird.
  ///
  /// Bei Supabase gibt es keine Kette im Pfad – sie steckt im Rumpf, und die
  /// Function heißt `chain-snapshots`. Der eigene Server will beides im Pfad
  /// haben (`/v1/chain/{id}`), sonst findet er die Kette nicht. Deshalb je
  /// einen Helfer pro Fall und keine gemeinsame Namensabbildung: ein
  /// generisches `/v1/<function-name>` hat beim eigenen Server den
  /// Ketten-Namen im falschen Format.
  String _chainWritePath(String chainId) =>
      _isSupabase ? '/functions/v1/chain-snapshots' : '/v1/chain/$chainId';

  /// Wo ein Share hingesendet wird. Aus demselben Grund wie oben.
  String _shareWritePath(String shareId) =>
      _isSupabase ? '/functions/v1/shares' : '/v1/share/$shareId';

  /// Der Pfad zu einer Sync-Kette.
  ///
  /// Der eigene Server nimmt die ID in den Pfad
  /// (`/v1/chain/abc`), Supabase als Query-Parameter (`?chain_id=abc`).
  ///
  /// Der Wert bekommt bewusst kein `eq.`-Präfix: Das ist PostgREST-Syntax und
  /// gehört in die Function, die den Wert zerlegt. Wer es hier setzt,
  /// bekommt `eq.abc` als Ketten-ID zurueck – und damit eine leere Kette ohne
  /// Fehlermeldung.
  Uri _chainPath(String chainId, {Map<String, String> query = const {}}) {
    if (_isSupabase) {
      return _uri('/functions/v1/chain-snapshots').replace(
        queryParameters: <String, String>{'chain_id': chainId, ...query},
      );
    }
    final String? device = query['device_id'];
    final String suffix = query['devices'] == '1'
        ? '/devices'
        : (device == null ? '' : '/devices/$device');
    return _uri('/v1/chain/$chainId$suffix');
  }

  /// Der Pfad zu einem Share. Gleiche Trennung wie bei der Kette.
  Uri _sharePath(String shareId) {
    if (_isSupabase) {
      return _uri('/functions/v1/shares').replace(
        queryParameters: <String, String>{'id': shareId},
      );
    }
    return _uri('/v1/share/$shareId');
  }

  /// Der Pfad zum Suchverzeichnis.
  Uri _directoryPath(String schoolNumber) {
    if (_isSupabase) {
      return _uri('/functions/v1/directory').replace(
        queryParameters: <String, String>{'school_number': schoolNumber},
      );
    }
    return _uri('/v1/directory/$schoolNumber');
  }

  /// Die Adresse des Status-Endpunkts.
  Uri _healthUri() =>
      _isSupabase ? _uri('/functions/v1/health') : _uri('/v1/health');

  void dispose() {
    if (_ownsClient) _client.close();
  }

  /// Prüft, ob der Server erreichbar ist und antwortet.
  ///
  /// Genau diese Abfrage macht auch die Statusseite auf GitHub Pages; deshalb
  /// antwortet der Server hier mit einem schlichten `status`-Feld.
  Future<bool> isServerRunning() async {
    try {
      final http.Response response = await _client
          .get(_healthUri(), headers: <String, String>{
            if (sendsApiKey) 'apikey': SyncCredentials.publishableKey,
          })
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final Object? decoded = jsonDecode(response.body);
      return decoded is Map && decoded['status'] == 'running';
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ Sync-Kette

  /// Lädt alle Snapshots einer Kette.
  Future<SyncChainSnapshot> fetchChain(
    String chainId, {
    String? deviceId,
  }) async {
    final Map<String, dynamic> body =
        await _send('GET', _chainPath(chainId));
    final List<dynamic> raw = body['snapshots'] as List<dynamic>? ?? <dynamic>[];
    final List<SyncDevice> devices = <SyncDevice>[];
    final List<ChainSnapshot> snapshots = <ChainSnapshot>[];

    for (final Object? entry in raw) {
      if (entry is! Map) continue;
      final Map<String, dynamic> snapshot = entry.cast<String, dynamic>();
      final SyncDevice device = SyncDevice.fromJson(snapshot);
      devices.add(device);
      // Der eigene Snapshot wird nicht gebraucht: Die App hat ihn lokal
      // bereits. Das spart Entschlüsselungszeit und vermeidet, dass das
      // eigene Gerät seine eigenen Daten "übernimmt".
      if (deviceId != null && device.deviceId == deviceId) continue;
      final Object? envelope = snapshot['envelope'];
      if (envelope is! Map) continue;
      snapshots.add(ChainSnapshot(
        deviceId: device.deviceId,
        envelope: envelope.cast<String, dynamic>(),
      ));
    }

    return SyncChainSnapshot(devices: devices, snapshots: snapshots);
  }

  /// Listet die Geräte einer Kette (ohne die Daten).
  Future<List<SyncDevice>> fetchDevices(String chainId) async {
    final Map<String, dynamic> body =
        await _send('GET', _chainPath(chainId, query: <String, String>{'devices': '1'}));
    return (body['devices'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SyncDevice.fromJson)
        .toList();
  }

  /// Sendet den eigenen Snapshot hoch.
  Future<void> pushSnapshot(
    String chainId, {
    required String deviceId,
    required String deviceName,
    required Map<String, dynamic> envelope,
    required bool includesSettings,
    required DateTime updatedAt,
  }) async {
    // Die Rumpf-Felder heissen snake_case, weil sie 1:1 in die Spalten der
    // Datenbank gehen. Der Dart-Code ist camelCase, der Datenbank-Code
    // snake_case, und an dieser Stelle gewinnt der Datenbank-Code: die
    // Function liest genau diese Namen.
    await _send('PUT', _chainWritePath(chainId), body: <String, dynamic>{
      'chain_id': chainId,
      'device_id': deviceId,
      'device_name': deviceName,
      'envelope': envelope,
      'includes_settings': includesSettings,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Nimmt ein Gerät aus der Kette. Die Daten auf dem Gerät bleiben erhalten –
  /// der Server löscht nur den Snapshot.
  Future<void> leaveChain(String chainId, String deviceId) =>
      _send('DELETE', _chainPath(chainId, query: <String, String>{
        'device_id': deviceId,
      }));

  /// Löscht die ganze Kette auf dem Server (alle Geräte).
  ///
  /// Eine Kette, die es nicht gibt, ist dabei **kein Fehler**: „Löschen" ist
  /// das gewünschte Ergebnis, und der Server hat nichts zu melden. Sonst
  /// scheitert der Knopf genau dann, wenn er am wenigsten schadet – bei einer
  /// frischen Installation, deren Ketten-ID noch niemandem bekannt ist.
  Future<void> deleteChain(String chainId) async {
    try {
      await _send('DELETE', _chainPath(chainId));
    } on SyncException catch (failure) {
      // 404 = es gab nichts zu löschen. 410 sagen die Edge Functions, wenn
      // eine Kette leer ist. Beides ist hier der gewünschte Endzustand.
      if (failure.status == 404 || failure.status == 410) return;
      rethrow;
    }
  }

  // ------------------------------------------------------------------ Shares

  /// Holt das Suchverzeichnis einer Schulnummer.
  ///
  /// Der Server liefert nur Personen derselben Schulnummer, und von diesen nur
  /// diejenigen, die ihre Shares ausdrücklich als *suchbar* markiert haben.
  Future<List<ShareOwner>> fetchDirectory(String schoolNumber) async {
    final Map<String, dynamic> body =
        await _send('GET', _directoryPath(schoolNumber));
    return (body['people'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ShareOwner.fromJson)
        .toList();
  }

  /// Holt einen Share samt seiner verschlüsselten Hüllen.
  Future<ShareRecord> fetchShare(String shareId) async {
    final Map<String, dynamic> body = await _send('GET', _sharePath(shareId));
    return ShareRecord(
      id: body['id']?.toString() ?? shareId,
      envelopes: (body['envelopes'] as Map<String, dynamic>? ??
          <String, dynamic>{}),
      hasPassword: body['hasPassword'] == true,
      isGlobal: body['isGlobal'] == true,
      updatedAt:
          DateTime.tryParse(body['updatedAt']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Legt einen Share an oder aktualisiert ihn.
  Future<void> publishShare({
    required String shareId,
    required String username,
    required String schoolNumber,
    required String displayName,
    required String label,
    required Map<String, dynamic> envelopes,
    required bool searchable,
    required bool isGlobal,
    required DateTime updatedAt,
  }) =>
      _send('PUT', _shareWritePath(shareId), body: <String, dynamic>{
        'id': shareId,
        'owner': <String, dynamic>{
          'username': username,
          'school_number': schoolNumber,
          'display_name': displayName,
        },
        'label': label,
        'envelopes': envelopes,
        'searchable': searchable,
        'is_global': isGlobal,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      });

  /// Löscht einen Share.
  Future<void> deleteShare(String shareId) =>
      _send('DELETE', _sharePath(shareId));

  // ----------------------------------------------------------------- Internes

  /// Schickt eine Anfrage. [target] ist ein Pfad oder eine fertige Adresse.
  Future<Map<String, dynamic>> _send(
    String method,
    Object target, {
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = target is Uri ? target : _uri(target as String);
    late final http.Response response;
    try {
      final Map<String, String> headers = <String, String>{
        'accept': 'application/json',
        if (body != null) 'content-type': 'application/json; charset=utf-8',
        // Supabases Gateway laesst keinen Aufruf ohne diesen Kopf durch. Der
        // Key ist oeffentlich und gibt allein nichts frei – die Rechte stehen
        // in der Datenbank.
        if (sendsApiKey) 'apikey': SyncCredentials.publishableKey,
      };
      final String? payload =
          body == null ? null : jsonEncode(_sanitize(body));
      response = await switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.put(uri, headers: headers, body: payload),
      }
          .timeout(_timeout);
    } on TimeoutException {
      throw const SyncException('timeout');
    } catch (_) {
      throw const SyncException('network');
    }

    Map<String, dynamic> decoded = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final Object? parsed = jsonDecode(response.body);
        if (parsed is Map) decoded = parsed.cast<String, dynamic>();
      } catch (_) {
        // Keine JSON-Antwort – dann bleibt `decoded` leer und der Status
        // entscheidet.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final String code = decoded['error']?.toString() ?? _codeForStatus(response.statusCode);
    throw SyncException(code, status: response.statusCode);
  }

  static String _codeForStatus(int status) {
    switch (status) {
      case 401:
      case 403:
        return 'forbidden';
      case 404:
        return 'notFound';
      case 409:
        return 'conflict';
      case 413:
        return 'tooLarge';
      case 429:
        return 'tooManyRequests';
      default:
        return status >= 500 ? 'serverError' : 'serverError';
    }
  }

  /// `jsonEncode` scheitert an `NaN` und `Infinity`; die kommen in den Daten
  /// nicht vor, aber ein kaputter Plan könnte sie enthalten. Statt die
  /// Übertragung abzubrechen, wird ein Sonderwert eingesetzt – der Inhalt ist
  /// verschlüsselt und für niemanden außer dem Besitzer lesbar.
  static Object? _sanitize(Object? value) {
    if (value is double) {
      if (value.isNaN || value.isInfinite) return 0;
      return value;
    }
    if (value is List) return value.map(_sanitize).toList();
    if (value is Map) {
      return value.map<String, Object?>(
        (Object? key, Object? v) => MapEntry<String, Object?>(
          key.toString(),
          _sanitize(v),
        ),
      );
    }
    return value;
  }
}
