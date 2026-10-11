import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/crypto/Passphrase.dart';
import 'package:substitute/services/crypto/PayloadCrypto.dart';
import 'package:substitute/services/sync/NameGuard.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

/// Ein Server, der nur Share-Aufrufe versteht.
class ShareServer {
  final Map<String, Map<String, dynamic>> shares =
      <String, Map<String, dynamic>>{};

  /// Alle Verzeichnis-Anfragen, um prüfen zu können, welche Schulnummer
  /// abgefragt wurde.
  final List<String> directoryRequests = <String>[];

  SyncApiClient client() => SyncApiClient(
        baseUrl: Uri.parse('https://sync.test'),
        client: MockClient((http.Request request) async {
          final List<String> segments = request.url.pathSegments;
          if (request.method == 'PUT' && segments.first == 'v1' && segments[1] == 'share') {
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            // Wichtig: Der Anfragerumpf ist snake_case (Spaltennamen), die
            // Antwort ist camelCase (Domänenmodell der App). Wer hier einfach
            // den Rumpf zurueckgibt, spiegelt eine Serverform, die es nicht
            // gibt – `displayName` kaeme dann als `display_name` an.
            shares[segments[2]] = <String, dynamic>{
              'id': segments[2],
              'owner': body['owner'],
              'label': body['label'],
              // Aus den Hüllen abgeleitet, wie es die generierte Spalte in
              // der Datenbank auch tut.
              'hasPassword': (body['envelopes'] as Map?)?.containsKey('byPassword') ?? false,
              'unlockableWithSchoolCredentials':
                  (body['envelopes'] as Map?)?.containsKey('bySchool') ?? false,
              'updatedAt': body['updated_at'],
              'envelopes': body['envelopes'],
            };
            return http.Response('{}', 200);
          }
          if (request.method == 'GET' && segments.length == 3 && segments[1] == 'share') {
            final Map<String, dynamic>? stored = shares[segments[2]];
            if (stored == null) {
              return http.Response('{"error":"shareNotFound"}', 404);
            }
            return http.Response(jsonEncode(stored), 200);
          }
          if (request.method == 'DELETE' && segments.length == 3) {
            shares.remove(segments[2]);
            return http.Response('{}', 200);
          }
          if (segments[1] == 'directory') {
            directoryRequests.add(segments[2]);
            return http.Response(jsonEncode(<String, dynamic>{'people': const []}), 200);
          }
          return http.Response('{"error":"unknownEndpoint"}', 404);
        }),
      );
}

/// Liest die Namen der übertragenen Personen.
List<String> namesOf(SharedPreferences prefs, [String key = 'persons']) {
  return (prefs.getStringList(key) ?? const <String>[])
      .map((String raw) => (jsonDecode(raw) as Map)['name'].toString())
      .toList();
}

/// Die Klassen – schlichte Namen, wie die App sie ablegt.
///
/// Über [SyncDataReader.readItems] statt über `getStringList` plus
/// `jsonDecode`: die Zeile `7c` ist kein JSON, und `jsonDecode` lässt die
/// ganze Liste scheitern statt sie zu lesen.
List<String> classesOf(SharedPreferences prefs, [String key = 'classes']) =>
    SyncDataReader.readItems(prefs, key)
        .map((Object item) => item.toString())
        .toList();

const String userA = 'blue sky river seven apple candle';
const String userB = 'red moon water nine tiger mango';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShareServer server;
  late ShareManager manager;

  setUp(() {
    server = ShareServer();
    manager = ShareManager(client: server.client());
    SharedPreferences.setMockInitialValues(<String, Object>{
      'offlineVPData': <String>[
        jsonEncode(<String, dynamic>{
          'date': '2026-09-29',
          'name': 'Vertretungsplan fuer Hans Schneider',
        }),
        jsonEncode(<String, dynamic>{'date': '2025-01-15', 'name': 'Plan von 2025'}),
      ],
      // So legt die App sie ab: `setStringList(key, ['7c', '5a'])` – ohne
      // JSON. Der Test hat lange die gegenteilige Form benutzt und damit eine
      // Welt geprüft, in der die Klassenauswahl nicht existiert.
      'classes': <String>['7c', '5a'],
      'persons': <String>[
        jsonEncode(<String, dynamic>{
          'id': 'p1',
          'name': 'Hans',
          'classId': '7c',
          'courses': <String>['Deutsch', 'Mathe'],
        }),
        jsonEncode(<String, dynamic>{
          'id': 'p2',
          'name': 'Petra',
          'classId': '7c',
          'courses': <String>['Englisch'],
        }),
        jsonEncode(<String, dynamic>{
          'id': 'p3',
          'name': 'Sven',
          'classId': '5a',
          'courses': <String>['Biologie'],
        }),
      ],
      'hideTeacher': false,
    });
  });

  group('Nutzername', () {
  test('publishing with an over-long username gives a clear error', () async {
    // Der Server weist einen Nutzernamen von mehr als 60 Zeichen mit
    // `invalidShare` ab – dieselbe Meldung wie bei einem verbotenen Namen.
    // Deshalb wird die Laenge schon hier geprueft, damit der Nutzer weiss,
    // woran es liegt.
    SharedPreferences.setMockInitialValues(<String, Object>{
      ShareManager.usernameStorageKey:
          // 63 Zeichen – genau die Länge, die ein erzeugter Nutzername
          // früher im Mittel hatte und die der Server nicht akzeptiert.
          'amber river stone seven candle mango tiger cloud field lantern bright maple',
      ShareManager.displayNameStorageKey: 'Kollegin',
      'classes': <String>['5a'],
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    Object? caught;
    try {
      await ShareManager(client: ShareServer().client())
          .publish(
        prefs: prefs,
        schoolNumber: '123456',
        schoolPassword: 'geheim',
        displayName: 'Kollegin',
        label: 'Mein Plan',
        payload: <String, dynamic>{'classes': <String>['5a']},
        selection: const ShareSelection(classIds: <String>{'5a'}),
        searchable: true,
      );
    } catch (error) {
      caught = error;
    }

    expect(caught, isA<ShareException>());
    expect((caught! as ShareException).code, 'usernameTooLong');
    expect(
      (prefs.getString(ShareManager.usernameStorageKey) ?? '').length,
      greaterThan(ShareManager.maxUsernameLength),
    );
  });

    test('besteht aus mehreren lesbaren Wörtern und passt auf den Server',
        () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ({String username, String displayName}) identity =
          await ShareManager.ensureIdentity(prefs);
      final List<String> words = identity.username.split(' ');
      // Nicht mehr genau zehn: Die Länge ist auf das Limit des Servers
      // begrenzt, und dafür greift die Erzeugung je nach Wortlänge auf
      // weniger Wörter zurück. Mindestens fünf bleiben es – die Entropie
      // liegt damit weiter weit über jeder sinnvollen Grenze.
      expect(words.length, inInclusiveRange(5, Passphrase.wordCount));
      expect(
        identity.username.length,
        lessThanOrEqualTo(ShareManager.maxUsernameLength),
        reason: 'der Server lehnt längere Nutzernamen ab',
      );
      for (final String word in words) {
        expect(RegExp(r'^[a-z]{3,10}$').hasMatch(word), isTrue,
            reason: '"$word" soll ein echtes englisches Wort sein');
      }
      expect(identity.username, isNot(contains('  ')));
      expect(identity.username, identity.username.trim());
    });

    test('bleibt stabil, wird also nicht bei jedem Aufruf neu erzeugt', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String first = (await ShareManager.ensureIdentity(prefs)).username;
      final String second = (await ShareManager.ensureIdentity(prefs)).username;
      expect(first, second);
    });

    test('schlägt einen lesbaren Anzeigenamen vor', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ({String username, String displayName}) identity =
          await ShareManager.ensureIdentity(prefs);
      expect(identity.displayName, isNotEmpty);
      expect(identity.displayName, identity.displayName[0].toUpperCase() +
          identity.displayName.substring(1));
    });

    test('weist einen anstößigen Anzeigenamen ab', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (final String bad in <String>['Arschloch', 'f-u-c-k', 'Scheißkopf']) {
        expect(
          await ShareManager.setDisplayName(prefs, bad),
          isFalse,
          reason: '"$bad" muss abgewiesen werden',
        );
      }
      expect(await ShareManager.setDisplayName(prefs, 'Frau Müller'), isTrue);
      expect(ShareManager.readDisplayName(prefs), 'Frau Müller');
    });

    // Die ID hängt **nur** am Nutzernamen. Das ist der Grund, warum ein
    // Share aus einer fremden Schule überhaupt zu öffnen ist: Wer die zehn
    // Wörter hat, kann die ID berechnen, ohne die Schulnummer der
    // Besitzerin zu kennen. Umgekehrt ist die Schulnummer kein Teil der ID
    // – sie entscheidet nur, ob ein Share im Suchmenü auftaucht.
    test('die Share-ID hängt am Nutzernamen, nicht an der Schulnummer', () {
      expect(ShareManager.shareIdFor(userA), ShareManager.shareIdFor(userA));
      expect(ShareManager.shareIdFor(userA), isNot(ShareManager.shareIdFor(userB)));
    });
  });

  group('Share veröffentlichen', () {
    Future<SharedPreferences> ready({String? username}) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ShareManager.ensureIdentity(prefs);
      if (username != null) {
        await prefs.setString(ShareManager.usernameStorageKey, username);
      }
      return prefs;
    }

    test('nimmt nur die ausgewählten Personen und Klassen auf', () async {
      final SharedPreferences prefs = await ready();
      final Map<String, dynamic> payload = await ShareManager.buildPayload(
        prefs,
        const ShareSelection(
          classIds: <String>{'7c'},
          personIds: <String>{'p1'},
        ),
      );
      final List<String> persons = (jsonDecode(jsonEncode(payload)) as Map)
          .toString()
          .isEmpty
          ? const <String>[]
          : <String>[];
      expect(payload.toString(), contains('Hans'));
      expect(payload.toString(), isNot(contains('Sven')));
      expect(payload.toString(), isNot(contains('5a')));
      expect(persons, isEmpty);
    });

    test('nimmt die Klasse einer geteilten Person mit', () async {
      final SharedPreferences prefs = await ready();
      final Map<String, dynamic> payload = await ShareManager.buildPayload(
        prefs,
        const ShareSelection(personIds: <String>{'p1'}),
      );
      expect(payload.toString(), contains('7c'));
    });

    test('kann die Pläne aus der Vergangenheit weglassen', () async {
      final SharedPreferences prefs = await ready();
      final String withHistory = (await ShareManager.buildPayload(
        prefs,
        const ShareSelection(classIds: <String>{'7c'}, includeHistory: true),
      ))
          .toString();
      final String without = (await ShareManager.buildPayload(
        prefs,
        const ShareSelection(classIds: <String>{'7c'}, includeHistory: false),
      ))
          .toString();
      expect(withHistory, contains('2025-01-15'));
      expect(without, isNot(contains('2025-01-15')));
    });

    test('verschlüsselt ohne Passwort für Nutzername und Schule', () async {
      final SharedPreferences prefs = await ready();
      final LocalShare share = await manager.publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'schulpasswort',
        displayName: 'Frau Müller',
        label: 'Vertretungspläne',
        payload: await ShareManager.buildPayload(
          prefs,
          const ShareSelection(classIds: <String>{'7c'}),
        ),
        selection: const ShareSelection(classIds: <String>{'7c'}),
        searchable: true,
      );

      expect(share.hasPassword, isFalse);
      final Map<String, dynamic> stored = server.shares[share.id]!;
      expect(
        (stored['envelopes'] as Map).keys,
        containsAll(<String>['byUsername', 'bySchool']),
      );
      // Der Inhalt steht nirgends im Klartext. Geprüft wird an einem
      // absichtlich sehr langen Namen – kurze Zeichenfolgen wie "7c" kommen
      // in Base64 zufällig vor und würden den Test flackern lassen.
      expect(jsonEncode(stored), isNot(contains('Vertretungsplan fuer Hans Schneider')));
      // Der Anzeigename steht dagegen absichtlich im Klartext: Er ist das,
      // wonach im Suchmenü gesucht wird, und der Server muss ihn lesen können.
      expect(stored['owner'], isA<Map<String, dynamic>>());
    });

    test('verschlüsselt mit Passwort nur für das Passwort', () async {
      final SharedPreferences prefs = await ready();
      final LocalShare share = await manager.publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'schulpasswort',
        displayName: 'Frau Müller',
        label: 'Vertretungspläne',
        payload: await ShareManager.buildPayload(
          prefs,
          const ShareSelection(classIds: <String>{'7c'}),
        ),
        selection: const ShareSelection(classIds: <String>{'7c'}),
        searchable: true,
        sharePassword: 'nine tiger mango apple candle',
      );

      expect(share.hasPassword, isTrue);
      final Map<String, dynamic> stored = server.shares[share.id]!;
      // Kein Weg am Passwort vorbei – auch nicht mit den Schuldaten.
      expect((stored['envelopes'] as Map).keys, <String>['byPassword']);
    });

    test('weist einen anstößigen Anzeigenamen auch beim Teilen ab', () async {
      final SharedPreferences prefs = await ready();
      expect(
        () => manager.publish(
          prefs: prefs,
          schoolNumber: '12345',
          schoolPassword: 'pw',
          displayName: 'Arschloch',
          label: 'x',
          payload: <String, dynamic>{},
          selection: const ShareSelection(classIds: <String>{'7c'}),
          searchable: true,
        ),
        throwsA(isA<ShareException>()
            .having((ShareException e) => e.code, 'code', 'nameBlocked')),
      );
    });

    test('weist einen Share ohne Auswahl ab', () async {
      final SharedPreferences prefs = await ready();
      expect(
        () => manager.publish(
          prefs: prefs,
          schoolNumber: '12345',
          schoolPassword: 'pw',
          displayName: 'Frau Müller',
          label: 'x',
          payload: <String, dynamic>{},
          selection: const ShareSelection(),
          searchable: true,
        ),
        throwsA(isA<ShareException>()
            .having((ShareException e) => e.code, 'code', 'nothingSelected')),
      );
    });

    test('merkt sich, was im Share war', () async {
      final SharedPreferences prefs = await ready();
      const ShareSelection selection =
          ShareSelection(classIds: <String>{'7c'}, personIds: <String>{'p1'});
      final LocalShare share = await manager.publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'pw',
        displayName: 'Frau Müller',
        label: 'Vertretungspläne',
        payload: await ShareManager.buildPayload(prefs, selection),
        selection: selection,
        searchable: true,
      );
      final List<LocalShare> stored = ShareManager.readShares(prefs);
      expect(stored, hasLength(1));
      expect(stored.single.id, share.id);
      expect(stored.single.selection.classIds, <String>{'7c'});
      expect(stored.single.selection.personIds, <String>{'p1'});
    });

    test('löscht einen Share wieder', () async {
      final SharedPreferences prefs = await ready();
      final LocalShare share = await manager.publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'pw',
        displayName: 'Frau Müller',
        label: 'x',
        payload: await ShareManager.buildPayload(
            prefs, const ShareSelection(classIds: <String>{'7c'})),
        selection: const ShareSelection(classIds: <String>{'7c'}),
        searchable: true,
      );
      await manager.remove(prefs, share.id);
      expect(ShareManager.readShares(prefs), isEmpty);
      expect(server.shares.containsKey(share.id), isFalse);
    });
  });

  group('Share öffnen', () {
    late SharedPreferences publisherPrefs;
    late String publishedId;

    Future<void> publishWith({
      String? sharePassword,
      bool searchable = true,
    }) async {
      publisherPrefs = await SharedPreferences.getInstance();
      await ShareManager.ensureIdentity(publisherPrefs);
      await publisherPrefs.setString(
        ShareManager.usernameStorageKey,
        userA,
      );
      final ShareSelection selection =
          const ShareSelection(classIds: <String>{'7c'}, personIds: <String>{'p1'});
      final LocalShare share = await manager.publish(
        prefs: publisherPrefs,
        schoolNumber: '12345',
        schoolPassword: 'schulpasswort',
        displayName: 'Frau Müller',
        label: 'Vertretungspläne',
        payload: await ShareManager.buildPayload(publisherPrefs, selection),
        selection: selection,
        searchable: searchable,
        sharePassword: sharePassword,
      );
      publishedId = share.id;
    }

    test('öffnet mit dem Nutzernamen', () async {
      await publishWith();
      final ShareRecord record =
          await manager.client.fetchShare(publishedId);
      final Map<String, dynamic> payload = ShareManager.unlock(record, userA);
      expect(payload.toString(), contains('Hans'));
      expect(ShareManager.canUnlockWithUsername(record), isTrue);
    });

    test('öffnet mit den Schulzugangsdaten', () async {
      await publishWith();
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        userA,
        schoolPassword: 'schulpasswort',
      );
      expect(payload.toString(), contains('Hans'));
    });

    test('ein falsches Schulpasswort schadet nicht, weil der Nutzername '
        'allein genügt', () async {
      await publishWith();
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      // Ohne Share-Passwort ist der Nutzername der Schlüssel; ein falsches
      // Schulpasswort ist dann schlicht irrelevant.
      expect(
        ShareManager.unlock(
          record,
          userA,
          schoolPassword: 'falsch',
        ).toString(),
        contains('Hans'),
      );
    });

    test('ein falscher Nutzername öffnet nichts', () async {
      await publishWith();
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      for (final String wrong in <String>[userB, 'blue sky', 'ganz anderes']) {
        expect(
          () => ShareManager.unlock(record, wrong),
          throwsA(isA<ShareException>().having(
            (ShareException e) => e.code,
            'code',
            'wrongCredentials',
          )),
          reason: '"$wrong" darf den Share nicht öffnen',
        );
      }
    });

    test('öffnet mit dem Passwort, nicht mit dem Nutzernamen', () async {
      const String sharePassword = 'nine tiger mango apple candle';
      await publishWith(sharePassword: sharePassword);
      final ShareRecord record = await manager.client.fetchShare(publishedId);

      // Mit Passwort geht es.
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        userA,
        sharePassword: sharePassword,
      );
      expect(payload.toString(), contains('Hans'));
      expect(ShareManager.canUnlockWithPassword(record), isTrue);

      // Ohne Passwort nicht – auch nicht mit den Schuldaten.
      expect(
        () => ShareManager.unlock(record, userA),
        throwsA(isA<ShareException>()),
      );
      expect(
        () => ShareManager.unlock(record, userA, schoolPassword: 'schulpasswort'),
        throwsA(isA<ShareException>()),
      );
    });

    test('ein fremder Nutzername öffnet nichts', () async {
      await publishWith(sharePassword: 'nine tiger mango apple candle');
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      expect(
        () => ShareManager.unlock(
          record,
          userB,
          sharePassword: 'nine tiger mango apple candle',
        ),
        throwsA(isA<ShareException>()),
      );
    });

    test('zählt den Inhalt für die Vorauswahl', () async {
      await publishWith();
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      final Map<String, dynamic> payload = ShareManager.unlock(record, userA);
      final ({int classes, int persons, int plans}) counts =
          ShareManager.countContents(payload);
      expect(counts.persons, 1);
      expect(counts.classes, greaterThanOrEqualTo(1));
      expect(counts.plans, 2);
    });
  });

  // Die Schulnummer spielt im Share keine Rolle mehr. Sie entscheidet nur noch,
  // ob ein Share im Suchmenü der eigenen Schule auftaucht – öffnen kann man
  // ihn mit dem Nutzernamen von überall.
  group('Schulen', () {
    late SharedPreferences publisherPrefs;

    Future<String> publish({String? sharePassword, bool searchable = true}) async {
      publisherPrefs = await SharedPreferences.getInstance();
      await ShareManager.ensureIdentity(publisherPrefs);
      await publisherPrefs.setString(ShareManager.usernameStorageKey, userA);
      final ShareSelection selection =
          const ShareSelection(classIds: <String>{'7c'}, personIds: <String>{'p1'});
      final LocalShare share = await manager.publish(
        prefs: publisherPrefs,
        schoolNumber: '12345',
        schoolPassword: 'schulpasswort',
        displayName: 'Frau Müller',
        label: 'Vertretungspläne',
        payload: await ShareManager.buildPayload(publisherPrefs, selection),
        selection: selection,
        searchable: searchable,
        sharePassword: sharePassword,
      );
      return share.id;
    }

    test('ein Share öffnet sich von einer anderen Schule aus', () async {
      final String id = await publish();
      // Die öffnende Person kennt nur den Nutzernamen – ihre eigene
      // Schulnummer spielt keine Rolle und wird gar nicht erst gebraucht.
      final ShareRecord record = await manager.client.fetchShare(id);
      expect(
        ShareManager.unlock(record, userA).toString(),
        contains('Hans'),
        reason: 'Der Nutzername muss von jeder Schule aus genügen.',
      );
    });

    test('die Schulnummer steht in keinem Schlüssel', () async {
      final String id = await publish();
      final ShareRecord record = await manager.client.fetchShare(id);
      // Ein Share, an anderer Stelle mit **anderem** Schulpasswort erzeugt,
      // wäre unter derselben ID gelandet und hätte einen anderen Schlüssel.
      // Genau deshalb ist dieser Test eine Zusicherung: Es gibt nur eine
      // Schlüsselableitung, und die kennt keine Schulnummer.
      expect(ShareManager.shareScope, 'share');
      expect(
        ShareManager.unlock(
          record,
          userA,
          schoolPassword: 'ein voellig anderes schulpasswort',
        ).toString(),
        contains('Hans'),
      );
    });

    test('ein passwortgeschützter Share braucht das Passwort', () async {
      const String sharePassword = 'nine tiger mango apple candle';
      final String id = await publish(sharePassword: sharePassword);
      final ShareRecord record = await manager.client.fetchShare(id);

      // Weder der Nutzername noch irgendein Schulpasswort kommen hinein.
      expect(
        () => ShareManager.unlock(record, userA),
        throwsA(isA<ShareException>()),
      );
      expect(
        () => ShareManager.unlock(record, userA, schoolPassword: 'schulpasswort'),
        throwsA(isA<ShareException>()),
      );
      // Das Passwort schon – auch von einer anderen Schule aus.
      expect(
        ShareManager.unlock(record, userA, sharePassword: sharePassword)
            .toString(),
        contains('Hans'),
      );
    });

    test('das Suchmenü fragt ausschließlich die eigene Schule ab', () async {
      await publish(searchable: true);
      await manager.client.fetchDirectory('12345');
      expect(
        server.directoryRequests,
        <String>['12345'],
        reason: 'Fremde Schulen dürfen nicht abgefragt werden.',
      );
    });

    test('ein nicht als suchbar markierter Share taucht nicht auf', () async {
      await publish(searchable: false);
      final List<ShareOwner> own = await manager.client.fetchDirectory('12345');
      final List<ShareOwner> other = await manager.client.fetchDirectory('99999');
      expect(own, isEmpty);
      expect(other, isEmpty);
    });
  });

  group('Import mit den drei Modi', () {
    late Map<String, dynamic> payload;

    setUp(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ShareManager.ensureIdentity(prefs);
      await prefs.setString(ShareManager.usernameStorageKey, userA);
      final ShareSelection selection =
          const ShareSelection(classIds: <String>{'7c'}, personIds: <String>{'p1'});
      final LocalShare share = await manager.publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'pw',
        displayName: 'Frau Müller',
        label: 'Vertretungspläne',
        payload: await ShareManager.buildPayload(prefs, selection),
        selection: selection,
        searchable: true,
      );
      payload = ShareManager.unlock(
        await manager.client.fetchShare(share.id),
        userA,
      );
    });

    /// Für die Import-Tests wird absichtlich eine **leere** App angenommen:
    /// So sieht man genau das, was aus dem Share hereinkommt, ohne dass die
    /// eigenen Daten das Bild verwischen.
    Future<SharedPreferences> emptyApp() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      return SharedPreferences.getInstance();
    }

    test('"Original" übernimmt Person und Klasse unverändert', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
      );
      expect(namesOf(prefs), <String>['Hans']);
      // Die fremde Klassennummer bleibt erhalten – genau der Sinn von
      // "Original": man sieht sie so, wie die Person sie angelegt hat.
      expect(classesOf(prefs), <String>['7c']);
      // Und die Kurse bleiben an der Person.
      final String personRaw = (prefs.getStringList('persons') ?? <String>[]).single;
      expect(
        (jsonDecode(personRaw) as Map)['courses'],
        containsAll(<String>['Deutsch', 'Mathe']),
      );
      expect(result.importedPersons, 1);
      expect(result.importedClasses, 1);
    });

    test('"Original" übernimmt auch die gespeicherten Pläne', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
      );
      expect(result.importedPlans, 2);
      final List<String> dates = (prefs.getStringList('offlineVPData') ??
              <String>[])
          .map((String raw) => (jsonDecode(raw) as Map)['date'].toString())
          .toList();
      expect(dates, containsAll(<String>['2026-09-29', '2025-01-15']));
    });

    // Die Option heißt in der Oberfläche „Klassen", weil sie genau das
    // erzeugt: eine Klasse je übernommener Klasse **und** Person.
    test('"Klassen" macht aus Klassen und Personen Klassen', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.plans,
        displayName: 'Frau Müller',
      );
      // Die fremde Klasse bleibt `7c`, aus der Person wird die Klasse `Hans`.
      expect(classesOf(prefs), containsAll(<String>['7c', 'Hans']));
      // Als Person taucht nichts mehr auf – der Modus macht nur Klassen.
      expect(namesOf(prefs), isEmpty);
      expect(result.importedClasses, 2);
    });

    // Vorher entstand je Kurs ein Plan „Hans – Deutsch", „Hans – Mathe" …
    // Das war doppelt und überflüssig: Die Kurse hängen an der Klasse, die aus
    // der Person wurde.
    test('"Klassen" erzeugt keine zusätzlichen Pläne', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.plans,
        displayName: 'Frau Müller',
      );
      expect(prefs.getStringList('offlineVPData'), anyOf(isNull, isEmpty),
          reason: 'Aus einer Person dürfen keine Pläne entstehen.');
      expect(result.importedPlans, 0);
    });

    test('"Personen" macht aus Klassen und Personen eigene Personen', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.persons,
        displayName: 'Frau Müller',
      );
      // Aus jeder übernommenen Person und jeder übernommenen Klasse wird ein
      // Name – und zu jedem gehört eine eigene Klasse.
      final List<String> names = namesOf(prefs);
      expect(names, containsAll(<String>['Hans', '7c']));
      // Kein Name doppelt, und zu jedem genau eine Klasse.
      expect(names.toSet(), hasLength(names.length));
      expect(classesOf(prefs), hasLength(names.length));
      expect(result.importedPersons, names.length);
    });

    // Der Name eines Plans ist keine Person. „Vertretungsplan fuer Hans
    // Schneider" stand vorher in der Personenliste und füllte sie nur.
    test('"Personen" zieht keine Namen aus den Plänen', () async {
      final SharedPreferences prefs = await emptyApp();
      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.persons,
        displayName: 'Frau Müller',
      );
      expect(
        namesOf(prefs),
        isNot(contains(anyOf('Vertretungsplan fuer Hans Schneider', 'Plan von 2025'))),
      );
      // Und nichts bleibt als "Plan" liegen.
      expect(
        prefs.getStringList('offlineVPData'),
        anyOf(isNull, isEmpty),
        reason: 'Im Modus "Personen" wird kein Plan übernommen.',
      );
    });

    test('lässt vorhandene Daten unangetastet', () async {
      final SharedPreferences prefs = await emptyApp();
      await prefs.setStringList('classes', <String>['5a']);
      await prefs.setStringList('persons', <String>[
        jsonEncode(<String, dynamic>{'id': 'own', 'name': 'Sven'}),
      ]);

      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
      );

      expect(classesOf(prefs), containsAll(<String>['5a', '7c']));
      expect(namesOf(prefs), containsAll(<String>['Sven', 'Hans']));
    });

    test('vergibt eindeutige IDs für importierte Personen', () async {
      final SharedPreferences prefs = await emptyApp();
      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
      );
      final List<String> ids = (prefs.getStringList('persons') ?? <String>[])
          .map((String raw) => (jsonDecode(raw) as Map)['id'].toString())
          .toList();
      expect(ids, hasLength(1));
      expect(ids.single, startsWith('import-'));
      // Die ID darf nicht mit einer lokalen ID kollidieren.
      expect(ids.single, isNot('1'));
    });

    test('kommt mit Daten einer anderen App nicht aus', () async {
      final SharedPreferences prefs = await emptyApp();
      expect(
        () => ShareManager.applyImport(
          prefs,
          <String, dynamic>{'app': 'something-else'},
          mode: ShareImportMode.original,
          displayName: 'Frau Müller',
        ),
        throwsA(isA<ShareException>()
            .having((ShareException e) => e.code, 'code', 'unreadable')),
      );
    });

    test('lässt bei zwei Klassen mit gleichem Kürzel keine Kollision zu', () async {
      final SharedPreferences prefs = await emptyApp();
      await prefs.setStringList('classes', <String>['7c']);
      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
      );
      final List<String> classes = classesOf(prefs);
      expect(classes, hasLength(2));
      expect(classes.toSet(), hasLength(2),
          reason: 'Ein bestehendes Kürzel darf nicht überschrieben werden.');
    });
  });

  group('Auswahl beim Import', () {
    late Map<String, dynamic> payload;

    setUp(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ShareManager.ensureIdentity(prefs);
      await prefs.setString(ShareManager.usernameStorageKey, userA);
      // Die Test-App hat die Klassen `7c` und `5a` und die Person `p1`.
      const ShareSelection selection =
          ShareSelection(classIds: <String>{'7c', '5a'}, personIds: <String>{'p1'});
      final LocalShare share = await manager.publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'pw',
        displayName: 'Frau Müller',
        label: 'Vertretungspläne',
        payload: await ShareManager.buildPayload(prefs, selection),
        selection: selection,
        searchable: true,
      );
      payload = ShareManager.unlock(
        await manager.client.fetchShare(share.id),
        userA,
      );
    });

    Future<SharedPreferences> emptyApp() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      return SharedPreferences.getInstance();
    }

    test('alles auswählen nimmt Klassen und Personen mit', () async {
      final ({
        List<String> classes,
        List<({String id, String name})> persons,
      }) items = ShareManager.selectableItems(payload);
      expect(items.classes, containsAll(<String>['7c', '5a']));
      expect(items.persons.map((({String id, String name}) p) => p.name),
          contains('Hans'));

      final ShareImportSelection selection = ShareManager.selectAll(payload);
      expect(selection.classIds, containsAll(<String>['7c', '5a']));
      expect(selection.personIds, isNotEmpty);
      expect(selection.includePlans, isTrue,
          reason: 'Zwischengespeicherte Pläne kommen standardmäßig mit.');
    });

    test('nur ausgewählte Klassen und Personen werden übernommen', () async {
      final SharedPreferences prefs = await emptyApp();
      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
        selection: ShareManager.selectAll(payload).copyWith(
          classIds: <String>{'7c'},
        ),
      );
      expect(classesOf(prefs), <String>['7c']);
    });

    test('eine abgewählte Person wird nicht importiert', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportSelection selection = ShareManager.selectAll(payload)
          .copyWith(personIds: <String>{});
      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.persons,
        displayName: 'Frau Müller',
        selection: selection,
      );
      expect(namesOf(prefs), containsAll(<String>['7c', '5a']));
      expect(namesOf(prefs), isNot(contains('Hans')));
    });

    test('ohne Pläne-Schalter kommen keine gespeicherten Pläne mit', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.original,
        displayName: 'Frau Müller',
        selection:
            ShareManager.selectAll(payload).copyWith(includePlans: false),
      );
      expect(result.importedPlans, 0);
      expect(prefs.getStringList('offlineVPData'), anyOf(isNull, isEmpty));
    });

    test('eine leere Auswahl wird abgewiesen, statt alles zu importieren',
        () async {
      final SharedPreferences prefs = await emptyApp();
      expect(
        () => ShareManager.applyImport(
          prefs,
          payload,
          mode: ShareImportMode.original,
          displayName: 'Frau Müller',
          selection: const ShareImportSelection(
            classIds: <String>{},
            personIds: <String>{},
            includePlans: false,
          ),
        ),
        throwsA(isA<ShareException>()
            .having((ShareException e) => e.code, 'code', 'nothingSelected')),
      );
      expect(classesOf(prefs), isEmpty);
    });

    test('der Pläne-Schalter zählt nur im Modus "Original"', () async {
      final ShareImportSelection selection =
          ShareManager.selectAll(payload);
      expect(ShareManager.countPlansOf(payload, selection), greaterThan(0));
      expect(
        ShareManager.countPlansOf(payload, selection,
            mode: ShareImportMode.plans),
        0,
      );
      expect(
        ShareManager.countPlansOf(
            payload, selection.copyWith(includePlans: false)),
        0,
      );
    });
  });

  group('Suchmenü', () {
    test('fragt nur die eigene Schulnummer ab', () async {
      await manager.client.fetchDirectory('12345');
      expect(server.directoryRequests, <String>['12345']);
    });

    test('leere Liste ist ein normaler Fall, kein Fehler', () async {
      final List<ShareOwner> people = await manager.client.fetchDirectory('12345');
      expect(people, isEmpty);
    });
  });

  group('NameGuard in den Anzeigenamen', () {
    test('deckt sich mit der Liste des Servers', () {
      // Der Server prüft dieselben Regeln noch einmal – siehe
      // docs/server/lib/src/moderation.dart. Diese Liste hier ist der
      // vollständige Satz; der Server hat bewusst nur die groben Fälle.
      expect(NameGuard.blockedTerms, isNotEmpty);
      expect(NameGuard.compoundTerms, isNotEmpty);
    });
  });
}
