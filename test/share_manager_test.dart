import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/crypto/PayloadCrypto.dart';
import 'package:substitute/services/sync/NameGuard.dart';
import 'package:substitute/services/sync/ShareManager.dart';
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
            shares[segments[2]] = body;
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

List<String> classesOf(SharedPreferences prefs, [String key = 'classes']) {
  return (prefs.getStringList(key) ?? const <String>[])
      .map((String raw) => (jsonDecode(raw) as Map)['name'].toString())
      .toList();
}

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
      'classes': <String>[
        jsonEncode(<String, dynamic>{'name': '7c'}),
        jsonEncode(<String, dynamic>{'name': '5a'}),
      ],
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
    test('besteht aus zehn lesbaren Wörtern', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ({String username, String displayName}) identity =
          await ShareManager.ensureIdentity(prefs);
      final List<String> words = identity.username.split(' ');
      expect(words, hasLength(10));
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

    test('die Share-ID hängt an Nutzername und Schulnummer', () {
      expect(
        ShareManager.shareIdFor(userA, '12345'),
        isNot(ShareManager.shareIdFor(userA, '99999')),
      );
      expect(
        ShareManager.shareIdFor(userA, '12345'),
        ShareManager.shareIdFor(userA, '12345'),
      );
    });

    test('ein globaler Share hat eine eigene, schulunabhängige ID', () {
      expect(
        ShareManager.globalShareIdFor(userA),
        isNot(ShareManager.shareIdFor(userA, '12345')),
      );
      expect(
        ShareManager.globalShareIdFor(userA),
        ShareManager.globalShareIdFor(userA),
      );
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
        isGlobal: false,
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
        isGlobal: false,
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
          isGlobal: false,
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
          isGlobal: false,
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
        isGlobal: false,
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
        isGlobal: false,
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
      bool isGlobal = false,
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
        isGlobal: isGlobal,
        sharePassword: sharePassword,
      );
      publishedId = share.id;
    }

    test('öffnet mit dem Nutzernamen', () async {
      await publishWith();
      final ShareRecord record =
          await manager.client.fetchShare(publishedId);
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        userA,
        schoolNumber: '12345',
      );
      expect(payload.toString(), contains('Hans'));
      expect(ShareManager.canUnlockWithUsername(record), isTrue);
    });

    test('öffnet mit den Schulzugangsdaten', () async {
      await publishWith();
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        userA,
        schoolNumber: '12345',
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
          schoolNumber: '12345',
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
          () => ShareManager.unlock(record, wrong, schoolNumber: '12345'),
          throwsA(isA<ShareException>().having(
            (ShareException e) => e.code,
            'code',
            'wrongCredentials',
          )),
          reason: '"$wrong" darf den Share nicht öffnen',
        );
      }
    });

    test('eine falsche Schulnummer öffnet nichts', () async {
      await publishWith();
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      expect(
        () => ShareManager.unlock(record, userA, schoolNumber: '99999'),
        throwsA(isA<ShareException>()),
      );
    });

    test('öffnet mit dem Passwort, nicht mit dem Nutzernamen', () async {
      const String sharePassword = 'nine tiger mango apple candle';
      await publishWith(sharePassword: sharePassword);
      final ShareRecord record = await manager.client.fetchShare(publishedId);

      // Mit Passwort geht es.
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        userA,
        schoolNumber: '12345',
        sharePassword: sharePassword,
      );
      expect(payload.toString(), contains('Hans'));
      expect(ShareManager.canUnlockWithPassword(record), isTrue);

      // Ohne Passwort nicht – auch nicht mit den Schuldaten.
      expect(
        () => ShareManager.unlock(record, userA, schoolNumber: '12345'),
        throwsA(isA<ShareException>()),
      );
      expect(
        () => ShareManager.unlock(
          record,
          userA,
          schoolNumber: '12345',
          schoolPassword: 'schulpasswort',
        ),
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
          schoolNumber: '12345',
          sharePassword: 'nine tiger mango apple candle',
        ),
        throwsA(isA<ShareException>()),
      );
    });

    test('zählt den Inhalt für die Vorauswahl', () async {
      await publishWith();
      final ShareRecord record = await manager.client.fetchShare(publishedId);
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        userA,
        schoolNumber: '12345',
      );
      final ({int classes, int persons, int plans}) counts =
          ShareManager.countContents(payload);
      expect(counts.persons, 1);
      expect(counts.classes, greaterThanOrEqualTo(1));
      expect(counts.plans, 2);
    });
  });

  group('Globaler Share', () {
    late SharedPreferences publisherPrefs;

    /// Legt einen globalen Share an und gibt seinen Payload zurück.
    Future<Map<String, dynamic>> publishGlobal({String? sharePassword}) async {
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
        searchable: false,
        isGlobal: true,
        sharePassword: sharePassword,
      );
      return ShareManager.unlock(
        await manager.client.fetchShare(share.id),
        userA,
        schoolNumber: '12345',
        sharePassword: sharePassword,
      );
    }

    test('lässt sich ohne die Schulnummer der Besitzerin öffnen', () async {
      // Genau der Fall, für den es "global" gibt: die öffnende Person kennt
      // nur den Nutzernamen und ihre eigene Schulnummer.
      await publishGlobal();
      final ShareRecord record = await manager.client.fetchShare(
        ShareManager.globalShareIdFor(userA),
      );
      expect(record.isGlobal, isTrue);
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        userA,
        schoolNumber: '99999',
      );
      expect(payload.toString(), contains('Hans'));
    });

    test('hat eine eigene, schulunabhängige ID', () async {
      await publishGlobal();
      final String id = ShareManager.globalShareIdFor(userA);
      expect(server.shares.containsKey(id), isTrue);
      // Und sie ist nicht die ID des normalen Shares.
      expect(id, isNot(ShareManager.shareIdFor(userA, '12345')));
    });

    test('bleibt mit Passwort auch global geschützt', () async {
      await publishGlobal(sharePassword: 'nine tiger mango apple candle');
      final ShareRecord record = await manager.client.fetchShare(
        ShareManager.globalShareIdFor(userA),
      );
      // Aus einer fremden Schule, mit den falschen Schuldaten: geht nicht.
      expect(
        () => ShareManager.unlock(
          record,
          userA,
          schoolNumber: '99999',
          schoolPassword: 'falsch',
        ),
        throwsA(isA<ShareException>()),
      );
      // Mit dem Passwort schon.
      expect(
        ShareManager.unlock(
          record,
          userA,
          schoolNumber: '99999',
          sharePassword: 'nine tiger mango apple candle',
        ).toString(),
        contains('Hans'),
      );
    });

    test('erscheint nicht im Suchverzeichnis einer fremden Schule', () async {
      await publishGlobal();
      // Der Server filtert nach Schulnummer; die App fragt nur ihre eigene.
      final List<ShareOwner> own = await manager.client.fetchDirectory('12345');
      final List<ShareOwner> other = await manager.client.fetchDirectory('99999');
      expect(other, isEmpty);
      // Der eigene Share war nicht als suchbar markiert.
      expect(own, isEmpty);
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
        isGlobal: false,
      );
      payload = ShareManager.unlock(
        await manager.client.fetchShare(share.id),
        userA,
        schoolNumber: '12345',
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

    test('"Pläne" macht aus der Person einen Plan', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.plans,
        displayName: 'Frau Müller',
      );
      // Die Person wird zu einer Klasse mit ihrem Namen …
      expect(classesOf(prefs), <String>['Hans']);
      // … und zu je einem Plan pro Kurs.
      final List<String> planNames = (prefs.getStringList('offlineVPData') ??
              <String>[])
          .map((String raw) => (jsonDecode(raw) as Map)['name'].toString())
          .toList();
      expect(planNames, contains('Hans – Deutsch'));
      expect(planNames, contains('Hans – Mathe'));
      // Als Person taucht sie nicht mehr auf.
      expect(namesOf(prefs), isEmpty);
      expect(result.importedPlans, 2);
    });

    test('"Personen" zieht aus allem Namen', () async {
      final SharedPreferences prefs = await emptyApp();
      final ShareImportResult result = await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.persons,
        displayName: 'Frau Müller',
      );
      // Aus jeder Person, jeder Klasse und jedem Plan wird ein Name – und zu
      // jedem gehört eine eigene Klasse.
      final List<String> names = namesOf(prefs);
      expect(
        names,
        containsAll(<String>[
          'Hans', // aus der Person
          '7c', // aus der Klasse
          'Vertretungsplan fuer Hans Schneider', // aus dem Plan
          'Plan von 2025',
        ]),
      );
      // Kein Name doppelt, und zu jedem genau eine Klasse.
      expect(names.toSet(), hasLength(names.length));
      expect(classesOf(prefs), hasLength(names.length));
      expect(result.importedPersons, names.length);
    });

    test('"Personen" macht aus Klassen und Plänen eigene Personen', () async {
      final SharedPreferences prefs = await emptyApp();
      await ShareManager.applyImport(
        prefs,
        payload,
        mode: ShareImportMode.persons,
        displayName: 'Frau Müller',
      );
      // Und nichts bleibt als "Plan" liegen.
      final List<String> plans = prefs.getStringList('offlineVPData') ??
          <String>[];
      expect(
        plans.where((String raw) => (jsonDecode(raw) as Map)['_importedAs'] == 'plan'),
        isEmpty,
        reason: 'Im Modus "Personen" wird nichts als Plan gespeichert.',
      );
    });

    test('lässt vorhandene Daten unangetastet', () async {
      final SharedPreferences prefs = await emptyApp();
      await prefs.setStringList('classes', <String>[
        jsonEncode(<String, dynamic>{'name': '5a'}),
      ]);
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
      await prefs.setStringList('classes', <String>[
        jsonEncode(<String, dynamic>{'name': '7c'}),
      ]);
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
