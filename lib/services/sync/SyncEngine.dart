import 'dart:async';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ConfigBackup.dart';
import '../crypto/Hashing.dart';
import '../crypto/PayloadCrypto.dart';
import '../crypto/Passphrase.dart';
import '../SchoolStorage.dart';
import 'SyncApiClient.dart';
import 'SyncCredentials.dart';
import 'SyncKeys.dart';
import 'SyncMerge.dart';
import 'SyncPayload.dart';

/// Der lokale Zustand der Sync-Kette, in der dieses Gerät gerade ist.
///
/// Bewusst in `SharedPreferences` statt im Arbeitsspeicher: Nach einem Neustart
/// muss die Kette weiterlaufen, ohne dass der Nutzer sie neu einrichten muss.
class SyncState {
  const SyncState({
    required this.passphrase,
    required this.chainId,
    required this.deviceId,
    required this.deviceName,
    required this.includeSettings,
    required this.lastSync,
    this.lastPushError,
  });

  /// Die zehn Wörter, die die Kette definieren. Wer sie kennt, darf
  /// beitreten; ohne sie kommt niemand hinein.
  final String passphrase;

  /// Die Kette beim Server – aus [passphrase] abgeleitet, damit man sie nicht
  /// separat speichern muss.
  final String chainId;

  /// Eigene Gerätekennung, damit das Gerät seinen eigenen Snapshot
  /// wiedererkennt.
  final String deviceId;

  /// Anzeigename in der Geräteliste.
  final String deviceName;

  /// Ob die Einstellungen Teil der Kette sind.
  final bool includeSettings;

  /// Wann zuletzt erfolgreich synchronisiert wurde.
  final DateTime? lastSync;

  /// Die letzte Fehlermeldung, falls ein Push scheiterte.
  final String? lastPushError;

  bool get isActive => passphrase.isNotEmpty && chainId.isNotEmpty;

  SyncState copyWith({
    String? passphrase,
    String? chainId,
    String? deviceId,
    String? deviceName,
    bool? includeSettings,
    DateTime? lastSync,
    String? lastPushError,
    bool clearError = false,
  }) =>
      SyncState(
        passphrase: passphrase ?? this.passphrase,
        chainId: chainId ?? this.chainId,
        deviceId: deviceId ?? this.deviceId,
        deviceName: deviceName ?? this.deviceName,
        includeSettings: includeSettings ?? this.includeSettings,
        lastSync: lastSync ?? this.lastSync,
        lastPushError: clearError ? null : (lastPushError ?? this.lastPushError),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'passphrase': passphrase,
        'chainId': chainId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'includeSettings': includeSettings,
        'lastSync': lastSync?.toUtc().toIso8601String(),
        'lastPushError': lastPushError,
      };

  static SyncState fromJson(Map<String, dynamic> json) => SyncState(
        passphrase: json['passphrase']?.toString() ?? '',
        chainId: json['chainId']?.toString() ?? '',
        deviceId: json['deviceId']?.toString() ?? '',
        deviceName: json['deviceName']?.toString() ?? '',
        includeSettings: json['includeSettings'] == true,
        lastSync: DateTime.tryParse(json['lastSync']?.toString() ?? ''),
        lastPushError: json['lastPushError']?.toString(),
      );
}

/// Was ein Sync bewirkt hat – für die Anzeige nach dem Lauf.
class SyncOutcome {
  const SyncOutcome({
    required this.pulled,
    required this.pushed,
    required this.merged,
    required this.devices,
    required this.finishedAt,
    this.error,
  });

  /// Anzahl der Geräte, von denen Daten geholt wurden.
  final int pulled;

  /// true, wenn die eigenen Daten zum Server geschickt wurden.
  final bool pushed;

  /// Anzahl der übernommenen Änderungen.
  final int merged;

  /// Die Geräte, die nach dem Lauf in der Kette waren.
  final List<SyncDevice> devices;

  final DateTime finishedAt;

  /// null bei Erfolg, sonst der Fehlercode.
  final String? error;

  bool get succeeded => error == null;

  bool get hasChanges => merged > 0;
}

/// Treibt die Sync-Kette: Daten lesen, verschlüsseln, hochladen, holen,
/// entschlüsseln, zusammenführen, zurückschreiben.
///
/// Der Ablauf eines Laufs ist immer derselbe:
///
/// 1. **Sammeln** – die ausgewählten Bestandteile aus `SharedPreferences`
///    lesen und zu einem [SyncPayload] machen.
/// 2. **Verschlüsseln** – mit einem aus der Passphrase abgeleiteten Schlüssel.
/// 3. **Hochladen** – der eigene Snapshot geht zum Server.
/// 4. **Holen** – die Snapshots der anderen Geräte.
/// 5. **Zusammenführen** – alle Geräte in beliebiger Reihenfolge; das Ergebnis
///    ist damit unabhängig davon, welches Gerät zuerst synchronisiert.
/// 6. **Zurückschreiben** – das Ergebnis lokal speichern, damit die App die
///    neuen Daten sieht.
///
/// Schritt 5 ist der Grund, warum ein Sync in beide Richtungen funktioniert:
/// Es gibt keinen "Master", jedes Gerät trägt bei, und die Zusammenführung
/// entscheidet pro Eintrag, wer gewinnt.
class SyncEngine {
  SyncEngine({required this.client});

  final SyncApiClient client;

  /// Domänen-Trennung für die Kettenkennung. Verschiedene Domänen dürfen
  /// niemals dieselbe Kennung ergeben, sonst würde ein Share als Sync-Kette
  /// erkannt (oder umgekehrt).
  static const String chainDomain = 'substitute/sync-chain/v1';

  /// Domänen-Trennung für die Ableitung des Verschlüsselungsschlüssels.
  static const String keyDomain = 'substitute/sync/v1';

  static const String stateStorageKey = 'sync.state';
  static const String serverUrlKey = 'sync.serverUrl';

  // ------------------------------------------------------------- Lokaler Zustand

  /// Liest den gespeicherten Zustand.
  static Future<SyncState?> loadState(SharedPreferences prefs) async {
    final String? raw = prefs.getString(stateStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final SyncState state = SyncState.fromJson(decoded.cast<String, dynamic>());
      return state.isActive ? state : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveState(SharedPreferences prefs, SyncState state) =>
      prefs.setString(stateStorageKey, jsonEncode(state.toJson()));

  /// Die Adresse des Sync-Servers.
  ///
  /// Voreingestellt ist das Supabase-Projekt; ohne Server läuft
  /// die App wie bisher, nur eben ohne Sync.
  static Uri serverUrl(SharedPreferences prefs) {
    final String? custom = prefs.getString(serverUrlKey);
    if (custom != null && custom.trim().isNotEmpty) {
      return Uri.parse(custom.trim());
    }
    return Uri.parse(defaultServerUrl);
  }

  /// Die Adresse des Sync-Servers. Siehe [SyncCredentials.defaultServerUrl].
  static const String defaultServerUrl = SyncCredentials.defaultServerUrl;

  /// Erzeugt eine neue Passphrase: zehn echte englische Wörter.
  ///
  /// Die Wörter sind aus [Passphrase.wordList] gewählt und deshalb lesbar
  /// und vorlesbar – ein UUID wäre weder abtippsicher noch merkbar.
  static String generatePassphrase() => Passphrase.generate();

  /// Die Kette, die zu einer Passphrase gehört.
  ///
  /// Wer die Passphrase hat, kann die Kennung selbst berechnen und muss sie
  /// nicht nachschlagen: Der Server kennt nur die Kennung, nicht die
  /// Passphrase.
  static String chainIdFor(String passphrase) =>
      PayloadCrypto.publicId(Passphrase.normalize(passphrase), chainDomain);

  /// Der Schlüssel der Kette.
  static DerivedKey keyFor(String passphrase) => PayloadCrypto.deriveKey(
        Passphrase.normalize(passphrase),
        salt: keyDomain,
      );

  /// Prüft, ob eine eingegebene Passphrase benutzt werden kann.
  ///
  /// Falsch geschriebene Wörter führen zu einem Klartext-Hinweis statt zu
  /// einem kryptografisch leeren Fehler – sonst wüsste der Nutzer nicht, ob
  /// die Kette falsch ist oder der Code falsch abgetippt wurde.
  static PassphraseCheck checkPassphrase(String input) =>
      PassphraseInput.check(input);

  // --------------------------------------------------------------------- Lauf

  /// Holt die Geräte der Kette, ohne Daten zu übertragen.
  Future<List<SyncDevice>> fetchDevices(SyncState state) =>
      client.fetchDevices(state.chainId);

  /// Führt einen vollständigen Sync-Lauf durch.
  ///
  /// [prefs] sind die `SharedPreferences` der **aktiven** Schule; die
  /// Sammlung läuft über [SchoolStorage.scopedKey], damit mehrere Schulen
  /// getrennt bleiben.
  Future<SyncOutcome> run(
    SharedPreferences prefs,
    SyncState state, {
    String? deviceName,
    bool push = true,
  }) async {
    final DateTime startedAt = DateTime.now().toUtc();
    final DerivedKey key = keyFor(state.passphrase);

    // 1. Lokalen Stand sammeln.
    final SyncPayload local = await collect(prefs, state, deviceName: deviceName);

    // 2. + 3. Verschlüsseln und hochladen.
    bool pushed = false;
    String? error;
    if (push) {
      try {
        await client.pushSnapshot(
          state.chainId,
          deviceId: state.deviceId,
          deviceName: state.deviceName,
          envelope: PayloadCrypto.encryptJson(
            key,
            local.toJson(),
            salt: keyDomain,
          ),
          includesSettings: state.includeSettings,
          updatedAt: local.updatedAt,
        );
        pushed = true;
      } on SyncException catch (failure) {
        error = failure.code;
      }
    }

    // 4. Die anderen Geräte holen. Auch wenn der Push scheiterte – es kann
    //    sein, dass nur die Schreibrichtung blockiert ist.
    final List<SyncPayload> remotes = <SyncPayload>[];
    List<SyncDevice> devices = <SyncDevice>[];
    try {
      final SyncChainSnapshot snapshot =
          await client.fetchChain(state.chainId, deviceId: state.deviceId);
      devices = snapshot.devices;
      for (final ChainSnapshot entry in snapshot.snapshots) {
        remotes.add(decrypt(key, entry.envelope));
      }
    } on SyncException catch (failure) {
      error ??= failure.code;
    } on PayloadCryptoException {
      // Ein Gerät mit einer anderen Krypto-Version – nicht die ganze Kette
      // deswegen verwerfen.
      error ??= 'futureSchema';
    }

    // 5. Zusammenführen. Die Reihenfolge ist bewusst beliebig: der Merge
    //    selbst ist symmetrisch.
    SyncPayload merged = local;
    int changed = 0;
    for (final SyncPayload remote in remotes) {
      final SyncMergeResult result = SyncMerge.merge(merged, remote);
      changed += result.totalChanges;
      merged = SyncPayload(
        parts: result.parts,
        tombstones: result.tombstones,
        // Stehen die Einstellungen nicht in dieser Kette, werden sie auch von
        // anderen Geräten **nicht** übernommen – sonst würde ein Gerät, das
        // sie abgeschaltet hat, trotzdem fremde Einstellungen bekommen.
        settings: state.includeSettings
            ? (result.settings ?? merged.settings)
            : merged.settings,
        // Die Zeit je Wert muss mitwandern, sonst weiß der nächste Merge
        // nicht, wann ein Wert zuletzt geändert wurde, und alle Werte schienen
        // gleich alt – mit derselben Folge wie vorher.
        settingsAt: state.includeSettings
            ? _mergeStamps(merged.settingsAt, result.settingsAt ?? const <String, DateTime>{})
            : merged.settingsAt,
        updatedAt: startedAt,
        deviceName: state.deviceName,
      );
    }

    // 6. Zurückschreiben. Auch dann, wenn sich nur Einstellungen geändert
    //    haben und kein einziger Eintrag – sonst kämen reine
    //    Einstellungsänderungen eines anderen Geräts nie an.
    if (changed > 0 || _settingsDiffer(local.settings, merged.settings)) {
      await SyncMerge.applyToPreferences(prefs, merged);
      changed += _countSettingChanges(local.settings, merged.settings);
    }

    return SyncOutcome(
      pulled: remotes.length,
      pushed: pushed,
      merged: changed,
      devices: devices,
      finishedAt: DateTime.now().toUtc(),
      error: error,
    );
  }

  /// Liest die zu synchronisierenden Daten der aktiven Schule.
  Future<SyncPayload> collect(
    SharedPreferences prefs,
    SyncState state, {
    String? deviceName,
  }) async {
    final String Function(String) scope = (String key) =>
        SchoolStorage.scopedKey(prefs, key);
    // Daten und Einstellungen werden getrennt gelesen: Einstellungen sind
    // einfache Werte, keine Listen – und `SharedPreferences` wirft einen
    // Typfehler, wenn man einen Schalter als Liste abfragt.
    final Map<String, List<Object>> parts =
        await SyncDataReader.readParts(prefs, SyncKeys.dataKeysOf(scope));

    // **Alle** übertragbaren Werte, nicht eine handgepflegte Liste. Siehe
    // [SyncDataReader.readValues] – eine Positivliste kann nicht vollständig
    // sein, und jede neue Einstellung bliebe sonst auf diesem Gerät.
    final Map<String, dynamic> values = state.includeSettings
        ? <String, dynamic>{
            ...SyncDataReader.readValues(prefs),
            // Die Karten dekodiert, damit sie einzeln zusammenführbar sind.
            ...SyncDataReader.readMaps(prefs),
          }
        : <String, dynamic>{};
    final Map<String, DateTime> stamps = state.includeSettings
        ? _stampsFor(prefs, values)
        : <String, DateTime>{};

    return SyncPayload(
      parts: [
        for (final MapEntry<String, List<Object>> entry in parts.entries)
          SyncPayload.describePart(entry.key, entry.value),
      ],
      tombstones: SyncMerge.readTombstones(prefs),
      settings: values,
      settingsAt: stamps,
      updatedAt: DateTime.now().toUtc(),
      deviceName: deviceName ?? state.deviceName,
    );
  }

  /// Nimmt die Zeitangaben beider Seiten für die Werte zusammen, die es jetzt
  /// gibt.
  ///
  /// Für jeden Wert zählt die **neuere** Zeit – so trägt der fremde Wert seine
  /// eigene Änderungszeit mit, statt sie bei „jetzt" zu verlieren. Das ist der
  /// Punkt, an dem die Kette sonst in einen Stillstand liefe: Ein Wert würde
  /// einmal übernommen und danach bei jedem Lauf als alt behandelt.
  static Map<String, DateTime> _mergeStamps(
    Map<String, DateTime> local,
    Map<String, DateTime> remote,
  ) {
    final Map<String, DateTime> merged = <String, DateTime>{...local};
    for (final MapEntry<String, DateTime> entry in remote.entries) {
      final DateTime? mine = local[entry.key];
      if (mine == null || entry.value.isAfter(mine)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  /// Die Änderungszeit **je Wert**, und das Merken des neuen Stands.
  ///
  /// Neu ist die Zeit nur dort, wo sich der Wert gegenüber dem zuletzt
  /// gesendeten tatsächlich geändert hat. Alles andere behält seine
  /// bisherige – sonst sähe bei jedem Lauf alles frisch aus, und die
  /// Einstellungen hätten wieder denselben Fehler.
  ///
  /// Der Schatten des gesendeten Stands liegt in
  /// [SyncEngine.timestampsStorageKey]. Der Sync muss dafür **keine einzige**
  /// Schreibstelle der App anfassen – wichtig, weil es in `VPlanAPI`,
  /// `Plan` und den Einstellungsseiten Dutzende davon gibt.
  Map<String, DateTime> _stampsFor(
    SharedPreferences prefs,
    Map<String, dynamic> values,
  ) {
    final DateTime now = DateTime.now().toUtc();
    final Map<String, dynamic> shadow = _readShadow(prefs);
    final Map<String, DateTime> previousStamps = _readStamps(prefs);
    final Map<String, DateTime> stamps = <String, DateTime>{};

    for (final MapEntry<String, dynamic> entry in values.entries) {
      final String encoded = jsonEncode(entry.value);
      final Object? known = shadow[entry.key];
      if (known == null) {
        // Erstmals gesehen: Wann dieser Wert gesetzt wurde, weiß dieses Gerät
        // nicht – die App merkt es sich nirgends. Es behauptet deshalb
        // **nicht**, der neueste zu sein, sondern bekommt den Anfang der
        // Zeitachse.
        //
        // Mit „jetzt" stattdessen behauptete jedes Gerät beim ersten Lauf, der
        // Neueste zu sein – auch eines, das den Wert nie angefasst hat. Damit
        // hätte das Gerät mit der echten Änderung immer gegen ein Gerät
        // verloren, das nur zufällig später dran war, und keine Einstellung
        // wäre je angekommen.
        stamps[entry.key] = SyncPayload.epoch;
      } else if (known.toString() != encoded) {
        // Gegen den gesendeten Stand verglichen: hier wurde wirklich
        // umgestellt, und genau dann ist „jetzt" berechtigt.
        stamps[entry.key] = now;
      } else {
        stamps[entry.key] = previousStamps[entry.key] ?? SyncPayload.epoch;
      }
      shadow[entry.key] = encoded;
    }

    // Ein Wert, der lokal verschwunden ist, wird auch aus dem Schatten
    // entfernt – sonst gälte er beim Zurückkommen als unverändert.
    shadow.removeWhere((String key, dynamic _) => !values.containsKey(key));

    _writeShadow(prefs, shadow, stamps);
    return stamps;
  }

  /// Der zuletzt gesendete Werte- und Zeitstand.
  static const String timestampsStorageKey = 'sync.settingsTimestamps';

  Map<String, dynamic> _readShadow(SharedPreferences prefs) {
    try {
      final String? raw = prefs.getString(timestampsStorageKey);
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, dynamic>{};
      final Object? values = decoded['values'];
      if (values is! Map) return <String, dynamic>{};
      return values.cast<String, dynamic>();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, DateTime> _readStamps(SharedPreferences prefs) {
    try {
      final String? raw = prefs.getString(timestampsStorageKey);
      if (raw == null || raw.isEmpty) return <String, DateTime>{};
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, DateTime>{};
      final Object? stamps = decoded['stamps'];
      if (stamps is! Map) return <String, DateTime>{};
      return stamps.map((dynamic key, dynamic value) => MapEntry<String, DateTime>(
            key.toString(),
            DateTime.tryParse(value.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ));
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  void _writeShadow(
    SharedPreferences prefs,
    Map<String, dynamic> shadow,
    Map<String, DateTime> stamps,
  ) {
    // Ein Fehler hier darf den Sync nicht abbrechen. Die Folge wäre nur, dass
    // beim nächsten Lauf alles als frisch gilt – das ist ein ungenauer
    // Zeitstempel, kein Datenverlust.
    unawaited(prefs.setString(
      timestampsStorageKey,
      jsonEncode(<String, dynamic>{
        'values': shadow,
        'stamps': stamps.map((String k, DateTime v) =>
            MapEntry<String, String>(k, v.toUtc().toIso8601String())),
      }),
    ));
  }

  /// Entschlüsselt eine Hülle zu einem [SyncPayload].
  static SyncPayload decrypt(DerivedKey key, Map<String, dynamic> envelope) =>
      SyncPayload.fromJson(PayloadCrypto.decryptJson(key, envelope));

  /// true, wenn sich mindestens eine Einstellung unterscheidet.
  static bool _settingsDiffer(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) =>
      _countSettingChanges(a, b) > 0;

  /// Wie viele Einstellungen sich unterscheiden.
  static int _countSettingChanges(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    int changes = 0;
    for (final MapEntry<String, dynamic> entry in b.entries) {
      if (!a.containsKey(entry.key)) {
        changes++;
        continue;
      }
      if (jsonEncode(a[entry.key]) != jsonEncode(entry.value)) changes++;
    }
    // Ein Schlüssel, den es lokal gab und remote nicht mehr, zählt auch als
    // Änderung – sonst würde er dauerhaft erhalten bleiben.
    for (final String key in a.keys) {
      if (!b.containsKey(key)) changes++;
    }
    return changes;
  }

  // ---------------------------------------------------------------- Geräte

  /// Erzeugt die Kennung dieses Geräts und einen schönen Anzeigenamen.
  ///
  /// Die Kennung ist zufällig und dauerhaft: Sie wird einmal erzeugt und
  /// gespeichert, sonst würde die App bei jedem Start als neues Gerät
  /// erscheinen und die Kette mit toten Einträgen aufüllen.
  static ({String deviceId, String deviceName}) createDevice(
    SharedPreferences prefs,
  ) {
    final String? existing = prefs.getString('sync.deviceId');
    if (existing != null && existing.isNotEmpty) {
      return (
        deviceId: existing,
        deviceName: prefs.getString('sync.deviceName') ?? '',
      );
    }
    final String deviceId = Hashing.toHex(Hashing.randomBytes(16));
    // Der Anzeigename wird erst nach dem ersten Lauf gesetzt – dort kennt
    // die App auch den echten Gerätenamen.
    return (deviceId: deviceId, deviceName: '');
  }

  /// Ermittelt einen lesbaren Namen für dieses Gerät.
  ///
  /// Fällt bewusst auf das Modell zurück, wenn die Plattform keinen
  /// Gerätenamen liefert: "Tablet" in der Geräteliste ist ehrlicher als
  /// "Unknown device".
  static Future<String> describeDevice() async {
    try {
      final DeviceInfoPlugin info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidDeviceInfo android = await info.androidInfo;
        return [android.manufacturer, android.model]
            .where((String part) => part.trim().isNotEmpty)
            .join(' ')
            .trim();
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final IosDeviceInfo ios = await info.iosInfo;
        return ios.model;
      }
    } catch (_) {
      // Plattform-API nicht verfügbar – der Name ist nur Kosmetik.
    }
    return '';
  }

  /// Verlässt die Kette, **ohne** die lokalen Daten anzufassen.
  ///
  /// Das ist der entscheidende Punkt der Anforderung: Wer die Kette einmal
  /// synchronisiert hat, behält seine Pläne, Personen und Einstellungen –
  /// sie werden nur nicht mehr mit den anderen Geräten abgeglichen.
  static Future<void> leaveChain(
    SharedPreferences prefs,
    SyncState state,
    SyncApiClient client,
  ) async {
    try {
      await client.leaveChain(state.chainId, state.deviceId);
    } on SyncException {
      // Auch wenn der Server nicht erreichbar ist, wird der lokale Zustand
      // gelöscht: Sonst würde die App in einen Zustand geraten, in dem sie
      // eine Kette erwartet, die es nicht mehr gibt.
    }
    await prefs.remove(stateStorageKey);
  }
}

/// Eingabeprüfung für Passphrasen.
class PassphraseInput {
  const PassphraseInput._();

  /// Der Fehlercode – oder null, wenn die Eingabe brauchbar ist.
  static PassphraseCheck check(String input) {
    final String normalized = Passphrase.normalize(input);
    if (normalized.isEmpty) {
      return const PassphraseCheck._(null, null, isEmpty: true);
    }
    if (Passphrase.split(input).length < Passphrase.minimumWords) {
      return const PassphraseCheck._('tooFewWords', null, isEmpty: true);
    }
    final List<String> unknown = Passphrase.unknownWords(input);
    if (unknown.isNotEmpty) {
      return PassphraseCheck._('unknownWords', unknown.join(', '), isEmpty: true);
    }
    return const PassphraseCheck._(null, null);
  }
}

/// Das Ergebnis einer Passphrasen-Prüfung.
///
/// Eigener Typ statt `NameVerdict` aus `NameGuard`: Dort sind die Codes für
/// Anzeigenamen hinterlegt, hier für Wortfolgen.
class PassphraseCheck {
  const PassphraseCheck._(this.errorCode, this.detail, {this.isEmpty = false});

  /// null, wenn die Eingabe gültig ist.
  final String? errorCode;

  /// Zusatzinformation, z.B. die unbekannten Wörter.
  final String? detail;

  /// true, wenn die Eingabe gar keine brauchbare Wortfolge ergab.
  final bool isEmpty;

  bool get isValid => errorCode == null;
}

/// Hilfsfunktion, damit die App nicht die ganze `ConfigBackup`-Logik für
/// einen einzelnen Schlüssel braucht.
bool isCredentialKey(String key) => ConfigBackup.credentialKeys.any(key.contains);
