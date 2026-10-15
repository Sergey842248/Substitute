/// Der Sync-Eintrag in der Leiste, das Passwort eines Shares und der Name,
/// unter dem ein Share in der Liste einer Person steht.
///
/// Drei Themen, die alle damit zu tun haben, dass **nichts** verloren geht:
///
/// * Wer den Sync-Eintrag ausblendet, schaltet Sync und Teilen ab – ohne dass
///   ein Share gelöscht oder ein Sync aufgelöst würde.
/// * Ein Share-Passwort ist ein **getipptes** Passwort: Ziffern und
///   Sonderzeichen dürfen darin vorkommen, ohne dass sie die Bedeutung verlieren.
/// * Wer einen Share über den Nutzernamen findet, muss dessen **Namen** sehen
///   und nicht viermal das Wort „Share".
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/AppAppearance.dart';
import 'package:substitute/services/crypto/Passphrase.dart';
import 'package:substitute/services/crypto/PayloadCrypto.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';
import 'package:substitute/services/sync/SyncEngine.dart';
import 'package:substitute/services/sync/SyncPayload.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/SyncShareEnabled.dart';

/// Der Inhalt, den eine Kollegin geteilt hat: ihre Klasse und ihre Person.
///
/// Von Hand gebaut statt über [ShareManager.buildPayload], weil die App dann
/// ihren **eigenen** Bestand als Quelle nähme – und der Import dann nichts
/// Neues importierte. Genau darum geht es hier: Es muss etwas **dazukommen**.
class SyncPayloadTestdaten {
  const SyncPayloadTestdaten._();

  static Map<String, dynamic> fremderShare() => SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', <Object>['9z']),
          SyncPayload.describePart('persons', <Object>[
            <String, dynamic>{
              'id': 'p9',
              'name': 'Petra',
              'classId': '9z',
              'courses': <String>['Mathe'],
            },
          ]),
          SyncPayload.describePart('offlineVPData', <Object>[
            <String, dynamic>{
              'date': '2026-09-29',
              'name': 'Plan der Kollegin'
            },
          ]),
        ],
        tombstones: const <SyncTombstone>[],
        settings: <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 9, 29),
        deviceName: 'Diensthandy',
      ).toJson();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Die Shares des Attrappen-Servers, genau wie er sie ausgibt.
  ///
  /// Die Hülle wird unverändert weitergegeben – nur so lässt sich prüfen, dass
  /// ein **älterer** Share mit seiner Wortphrase weiterhin zu öffnen ist.
  final Map<String, Map<String, dynamic>> anteile =
      <String, Map<String, dynamic>>{};

  late SharedPreferences prefs;
  late ShareManager manager;

  /// Ein Server, der nur Share-Aufrufe versteht.
  SyncApiClient server() => SyncApiClient(
        baseUrl: Uri.parse('https://sync.test'),
        client: MockClient((http.Request request) async {
          final List<String> segmente = request.url.pathSegments;
          if (request.method == 'PUT' && segmente[1] == 'share') {
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            anteile[segmente[2]] = <String, dynamic>{
              'id': segmente[2],
              'owner': body['owner'],
              'label': body['label'],
              'searchable': body['searchable'] == true,
              'hasPassword':
                  (body['envelopes'] as Map?)?.containsKey('byPassword') ??
                      false,
              'updatedAt': body['updated_at'],
              'envelopes': body['envelopes'],
            };
            return http.Response('{}', 200);
          }
          if (request.method == 'GET' && segmente.length == 3) {
            final Map<String, dynamic>? gespeichert = anteile[segmente[2]];
            if (gespeichert == null) {
              return http.Response('{"error":"shareNotFound"}', 404);
            }
            return http.Response(jsonEncode(gespeichert), 200);
          }
          if (request.method == 'DELETE') {
            anteile.remove(segmente[2]);
            return http.Response('{}', 200);
          }
          return http.Response('{"error":"unknown"}', 404);
        }),
      );

  const String nutzername = 'blue sky river seven apple candle';

  ShareSelection auswahl() =>
      const ShareSelection(classIds: <String>{'7c'}, personIds: <String>{'p1'});

  /// Meldet an, legt eine Klasse und eine Person an und blendet den
  /// Sync-Eintrag wahlweise aus.
  Future<void> vorbereiten({bool syncSichtbar = true}) async {
    anteile.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    manager = ShareManager(client: server());
    prefs = await SharedPreferences.getInstance();
    await ShareManager.ensureIdentity(prefs);
    await prefs.setString(ShareManager.usernameStorageKey, nutzername);
    await prefs.setString('vplanSchoolnumber', '12345');
    await prefs.setString('vplanPassword', 'schulpasswort');
    await prefs.setStringList('classes', <String>['7c']);
    await prefs.setStringList('persons', <String>[
      jsonEncode(<String, dynamic>{
        'id': 'p1',
        'name': 'Hans',
        'classId': '7c',
        'courses': <String>['Deutsch'],
      }),
    ]);
    await AppAppearance.setShowSyncShareTab(prefs, syncSichtbar);
  }

  /// Der Inhalt, der in den Share wandert.
  Future<Map<String, dynamic>> inhalt() =>
      ShareManager.buildPayload(prefs, auswahl());

  Future<LocalShare> veroeffentlichen({String? passwort}) async =>
      manager.publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'schulpasswort',
        displayName: 'Frau Müller',
        label: 'Meine Pläne',
        payload: await inhalt(),
        selection: auswahl(),
        searchable: true,
        sharePassword: passwort,
      );

  group('Der Sync-Eintrag in der Leiste', () {
    test('entscheidet, ob Sync und Teilen laufen', () async {
      await vorbereiten();
      expect(SyncShareEnabled.isEnabled(prefs), isTrue);
      expect(SyncShareEnabled.isDisabled(prefs), isFalse);

      // Derselbe Wert, an dem auch die Leiste hängt: Zwei Schalter für eine
      // Frage hießen am Ende, dass einer von beiden vergessen wird – und dann
      // läuft etwas weiter, das niemand mehr sehen kann.
      expect(SyncShareEnabled.isEnabled(prefs),
          AppAppearance.showSyncShareTab(prefs));

      await AppAppearance.setShowSyncShareTab(prefs, false);
      expect(SyncShareEnabled.isEnabled(prefs), isFalse);
      await AppAppearance.setShowSyncShareTab(prefs, true);
      expect(SyncShareEnabled.isEnabled(prefs), isTrue);
    });

    test('ausgeblendet lässt sich nichts teilen', () async {
      await vorbereiten(syncSichtbar: false);
      expect(
        () => veroeffentlichen(),
        throwsA(
          isA<ShareException>().having(
            (ShareException e) => e.code,
            'code',
            'syncShareDisabled',
          ),
        ),
        reason: 'Ausgeblendet heißt: es wird nichts veröffentlicht.',
      );
    });

    test('und wieder eingeblendet läuft alles wie vorher', () async {
      // Zuerst einen Share anlegen, solange es noch geht.
      await vorbereiten();
      final LocalShare vorher =
          await veroeffentlichen(passwort: r'aB3$xYz!9kLm');

      // Aus- und wieder einschalten.
      await AppAppearance.setShowSyncShareTab(prefs, false);
      await AppAppearance.setShowSyncShareTab(prefs, true);

      // Der Share steht noch in der Liste …
      expect(
        ShareManager.readShares(prefs).map((LocalShare s) => s.id),
        <String>[vorher.id],
        reason: 'Ausblenden darf keinen Share löschen.',
      );
      // … lässt sich wieder bearbeiten …
      final LocalShare nachher = await manager.update(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'schulpasswort',
        share: vorher,
        label: 'Meine Pläne, neu',
      );
      expect(nachher.label, 'Meine Pläne, neu');
      expect(nachher.id, vorher.id);
      // … und lässt sich mit demselben Passwort öffnen, mit dem er angelegt
      // wurde.
      final ShareRecord record = await manager.client.fetchShare(vorher.id);
      expect(
        ShareManager.unlock(record, nutzername, sharePassword: r'aB3$xYz!9kLm')
            .toString(),
        contains('7c'),
      );
    });

    test('die eigenen Shares verschwinden aus dem Suchverzeichnis', () async {
      await vorbereiten();
      final LocalShare share = await veroeffentlichen();
      expect(anteile[share.id]!['searchable'], isTrue);

      // Ausgeblendet: Der Share darf nicht mehr in der Liste der Kolleginnen
      // stehen – sonst wäre die Funktion nicht abgeschaltet, sondern nur ihre
      // Tür zugemauert.
      await AppAppearance.setShowSyncShareTab(prefs, false);
      await ShareManager.gleicheSuchverzeichnis(
          client: manager.client, prefs: prefs);
      expect(anteile[share.id]!['searchable'], isFalse);
      // Er ist aber **nicht** gelöscht: Er steht noch auf dem Server, und er
      // ist über den Nutzernamen weiterhin zu öffnen.
      expect(
        ShareManager.unlock(
          await manager.client.fetchShare(share.id),
          nutzername,
        ).toString(),
        contains('7c'),
      );

      // Und wieder eingeblendet kommt er so zurück, wie er war.
      await AppAppearance.setShowSyncShareTab(prefs, true);
      await ShareManager.gleicheSuchverzeichnis(
          client: manager.client, prefs: prefs);
      expect(anteile[share.id]!['searchable'], isTrue);
      expect(ShareManager.readShares(prefs).single.id, share.id);
    });

    test('importierte Personen stehen in der Form, die die App liest',
        () async {
      await vorbereiten();
      // Der Inhalt eines fremden Shares: eine fremde Klasse mit einer Person.
      final Map<String, dynamic> payload = SyncPayloadTestdaten.fremderShare();
      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
      );

      // **Das** ist der gemeldete Fehler: Der Import legte `persons` als Liste
      // ab, `VPlanAPI.getPersons` liest mit `getString` – und scheiterte daran
      // still. Es erschien keine einzige der importierten Personen, und die App
      // musste neu gestartet werden, damit `StorageHealer` den Eintrag
      // nebenbei in die richtige Form schrieb.
      final List<Map<String, dynamic>> personen = await VPlanAPI().getPersons();
      expect(
        personen.map((Map<String, dynamic> p) => p['name']),
        containsAll(<String>['Hans', 'Petra']),
        reason: 'die importierten Personen sind für die App unsichtbar',
      );
      // Auch die Klasse steht da – und zwar als Liste, so wie `classes` es ist.
      expect(prefs.getStringList('classes'), contains('9z'));
    });

    test('ausgeblendet wird auch nichts importiert', () async {
      await vorbereiten(syncSichtbar: false);
      // Ein fremder Share, so wie ihn der Server zurückgibt.
      final Map<String, dynamic> payload = SyncPayloadTestdaten.fremderShare();
      expect(
        () => ShareManager.applyImport(
          prefs,
          payload,
          mode: ShareImportMode.original,
          displayName: 'Frau Müller',
        ),
        throwsA(isA<ShareException>()),
        reason: 'Sonst hinge das Suchmenü offen, während die anderen zu sind.',
      );
      expect(
        SyncDataReader.readLines(prefs, 'classes'),
        <String>['7c'],
        reason: 'Der eigene Bestand bleibt unangetastet.',
      );
    });
  });

  group('Das Passwort eines Shares', () {
    test('ist zwölf Zeichen lang und enthält alle vier Zeichenarten', () async {
      await vorbereiten();
      for (int i = 0; i < 20; i++) {
        final String pw = ShareManager.generateSharePassword();
        expect(pw.length, ShareManager.sharePasswordLength, reason: pw);
        expect(RegExp(r'[a-z]').hasMatch(pw), isTrue, reason: pw);
        expect(RegExp(r'[A-Z]').hasMatch(pw), isTrue, reason: pw);
        expect(RegExp(r'[0-9]').hasMatch(pw), isTrue, reason: pw);
        expect(RegExp(r'[^A-Za-z0-9]').hasMatch(pw), isTrue, reason: pw);
        // Zusammenhängend: kein Leerzeichen, kein Trennzeichen dazwischen.
        expect(pw.contains(' '), isFalse, reason: pw);
      }
    });

    test('ist nicht zwanzigmal dasselbe', () async {
      await vorbereiten();
      final Set<String> gesehen = <String>{
        for (int i = 0; i < 20; i++) ShareManager.generateSharePassword(),
      };
      expect(gesehen.length, greaterThan(19));
    });

    test('behält Ziffern und Sonderzeichen', () async {
      await vorbereiten();
      const String pw = r'aB3$xYz!9kLm';
      final LocalShare share = await veroeffentlichen(passwort: pw);
      final ShareRecord record = await manager.client.fetchShare(share.id);
      // Vorher lief das Passwort durch `Passphrase.normalize`: Das machte
      // klein, sortierte die Wörter und **warf Ziffern und Sonderzeichen weg** –
      // `aB3$xYz!9kLm` wurde zu `ab xyz klm`, und jedes Passwort mit Ziffern
      // hätte denselben Schlüssel gehabt.
      expect(
        ShareManager.unlock(record, nutzername, sharePassword: pw).toString(),
        contains('7c'),
      );
      expect(
        () => ShareManager.unlock(record, nutzername, sharePassword: 'falsch'),
        throwsA(isA<ShareException>()),
      );
    });

    test('öffnet einen älteren Share mit seiner Wortphrase weiterhin',
        () async {
      await vorbereiten();
      final String id = ShareManager.shareIdFor(nutzername);
      const String phrase = 'nine tiger mango apple candle';

      // Die Hülle **wie früher**: Das Passwort lief durch `Passphrase.normalize`
      // (klein, sortiert, nur Buchstaben).
      final String altesGeheimnis = Passphrase.normalize(phrase);
      anteile[id] = <String, dynamic>{
        'id': id,
        'owner': <String, dynamic>{
          'username': nutzername,
          'displayName': 'Frau Müller',
        },
        'label': 'Meine Pläne',
        'hasPassword': true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'envelopes': <String, dynamic>{
          'byPassword': PayloadCrypto.encryptJson(
            PayloadCrypto.deriveKey(
              '${Passphrase.normalize(nutzername)}'
              '|${ShareManager.shareScope}|$altesGeheimnis',
              salt: ShareManager.keyDomain,
            ),
            await inhalt(),
            salt: ShareManager.keyDomain,
          ),
        },
      };

      // Wer die Wörter kennt, kommt weiter hinein – auch in anderer
      // Reihenfolge, wie es früher möglich war.
      final ShareRecord record = await manager.client.fetchShare(id);
      expect(
        ShareManager.unlock(record, nutzername, sharePassword: phrase)
            .toString(),
        contains('7c'),
      );
      expect(
        ShareManager.unlock(
          record,
          nutzername,
          sharePassword: phrase.split(' ').reversed.join(' '),
        ).toString(),
        contains('7c'),
      );
    });

    test('und der Server nennt Name und Beschriftung des Shares', () async {
      await vorbereiten();
      final LocalShare share = await veroeffentlichen();
      final ShareRecord record = await manager.client.fetchShare(share.id);
      // Ohne diese beiden Felder stand in der Liste der Person überall nur das
      // Wort „Share" – bei zwei Shares nicht zu unterscheiden.
      expect(record.label, 'Meine Pläne');
      expect(record.displayName, 'Frau Müller');
      expect(record.username, nutzername);
    });
  });

  group('Der Sync selbst', () {
    test('läuft nicht, solange der Eintrag ausgeblendet ist', () async {
      await vorbereiten(syncSichtbar: false);

      // Der Server, den der Koordinator benutzt – er darf gar nicht gefragt
      // werden.
      final List<http.Request> fragen = <http.Request>[];
      SyncCoordinator.clientFactory = (Uri baseUrl) => SyncApiClient(
            baseUrl: baseUrl,
            client: MockClient((http.Request request) async {
              fragen.add(request);
              return http.Response('{}', 200);
            }),
          );
      addTearDown(() => SyncCoordinator.clientFactory = null);

      // Ein eingerichteter Sync – er darf nur nicht laufen.
      await SyncEngine.saveState(
        prefs,
        SyncState(
          passphrase: nutzername,
          chainId: SyncEngine.chainIdFor(nutzername),
          deviceId: 'geraet-1',
          deviceName: 'Testgeraet',
          includeSettings: true,
          lastSync: null,
        ),
      );
      expect(await SyncEngine.loadState(prefs), isNotNull);

      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      expect(
        await coordinator.syncNow(reason: 'test', force: true),
        isNull,
        reason: 'Ein ausgeblendeter Sync darf keinen Lauf anfangen.',
      );
      coordinator.detach();
      expect(fragen, isEmpty, reason: 'Es darf nicht einmal gefragt werden.');

      // Und der Zustand ist nach wie vor da: Es wurde nichts gelöscht.
      expect(await SyncEngine.loadState(prefs), isNotNull);
    });
  });
}
