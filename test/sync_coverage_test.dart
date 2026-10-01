import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Was kommt zwischen zwei Geräten tatsächlich an?
///
/// Kein Attrappen-Server: Der Test merkt sich nur, was **hinausgeht** und was
/// **hereinkommt**, und prüft dann, ob die Zusammenführung das Richtige damit
/// macht. Damit lässt sich jeder Bestandteil einzeln nachfragen, ohne dass man
/// raten muss.
///
/// Die Platten werden in der Form angelegt, in der die App sie anlegt – sonst
/// prüft der Test eine Welt, in der die App nicht existiert.
void main() {
  /// Der letzte Push je Gerät – so, wie der Server ihn ablegt.
  final Map<String, Map<String, dynamic>> pushes =
      <String, Map<String, dynamic>>{};
  late List<Map<String, dynamic>> served;
  late SyncApiClient client;

  setUp(() {
    pushes.clear();
    served = <Map<String, dynamic>>[];

    client = SyncApiClient(
      baseUrl: Uri.parse('https://messgerät.test'),
      client: _RecordingClient((Map<String, dynamic> body) {
        pushes[body['device_id'] as String] = body;
      }, () => served),
    );
  });

  SyncState stateOf([String deviceId = 'geraet-a']) => SyncState(
        passphrase: 'blue sky river seven apple candle',
        chainId: 'kette',
        deviceId: deviceId,
        deviceName: 'Pixel',
        includeSettings: true,
        lastSync: null,
      );

  /// Legt die Platte eines Geräts an.
  Future<SharedPreferences> diskWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      // Zu Schul-Daten zusammengefasst, wie es die App tut: `hideTeacher`
      // ist boolesch, `lessontimes` eine JSON-Zeichenkette.
      ...values,
    });
    return SharedPreferences.getInstance();
  }

  /// Holt die Hülle zurück, die [deviceId] zuletzt hochgeschoben hat.
  ///
  /// Hier wird nicht wirklich verschlüsselt – es geht um die *Form* der
  /// übertragenen Teile, nicht um Krypto (die hat eigene Tests). Der Rückweg
  /// nimmt die Hülle unverändert wieder, genau wie der Server sie lagert.
  void servePushOf(String deviceId) {
    final Map<String, dynamic>? last = pushes[deviceId];
    if (last == null) {
      served = <Map<String, dynamic>>[];
      return;
    }
    served = <Map<String, dynamic>>[
      <String, dynamic>{
        'deviceId': deviceId,
        'deviceName': 'Gerät $deviceId',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'includesSettings': true,
        'envelope': last['envelope'],
      },
    ];
  }

  group('Daten', () {
    test('Klassen kommen von Gerät B auf Gerät A an', () async {
      final SharedPreferences prefsB = await diskWith(<String, Object>{
        'classes': <String>[
          jsonEncode(<String, dynamic>{'id': 'c2', 'name': '9c'}),
          jsonEncode(<String, dynamic>{'id': 'c3', 'name': '10d'}),
        ],
      });
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      servePushOf('geraet-b');

      final SharedPreferences prefsA = await diskWith(<String, Object>{
        'classes': <String>[jsonEncode(<String, dynamic>{'id': 'c1', 'name': '8a'})],
      });
      final SyncOutcome outcome =
          await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      expect(outcome.succeeded, isTrue, reason: '${outcome.error}');
      expect(outcome.pulled, 1, reason: 'B wurde gar nicht gelesen');
      expect(outcome.merged, greaterThan(0), reason: 'nichts übernommen');

      final List<String> names = SyncDataReader.readLines(prefsA, 'classes')
          .map((String l) => (jsonDecode(l) as Map)['name'].toString())
          .toList();
      expect(names, contains('9c'), reason: 'die Klassen von B kamen nicht an');
      expect(names, contains('10d'));
      expect(names, contains('8a'), reason: 'As eigene Klasse ist weg');
      expect(names, hasLength(3), reason: 'es wird nicht zusammengeführt');
    });

    test('Pläne kommen an, auch die aus der Vergangenheit', () async {
      final SharedPreferences prefsB = await diskWith(<String, Object>{
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-09-01', 'name': 'Alt'}),
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Heute'}),
        ],
      });
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      servePushOf('geraet-b');

      final SharedPreferences prefsA = await diskWith(<String, Object>{
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Heute A'}),
        ],
      });
      await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      final List<String> dates = SyncDataReader.readLines(prefsA, 'offlineVPData')
          .map((String l) => (jsonDecode(l) as Map)['date'].toString())
          .toList();
      expect(dates, contains('2026-09-01'),
          reason: 'der Plan aus der Vergangenheit kam nicht an');
    });
  });

  group('Einstellungen', () {
    test('eine einfache Einstellung wird übernommen', () async {
      final SharedPreferences prefsB = await diskWith(<String, Object>{
        'hideTeacher': true,
      });
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      servePushOf('geraet-b');

      final SharedPreferences prefsA = await diskWith(<String, Object>{
        'hideTeacher': false,
      });
      final SyncOutcome outcome =
          await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      // ignore: avoid_print
      print('merged=${outcome.merged} error=${outcome.error} pulled=${outcome.pulled} hideTeacher=${prefsA.getBool('hideTeacher')}');
      expect(prefsA.getBool('hideTeacher'), isTrue, reason: 'Einstellung nicht übernommen');
      expect(outcome.merged, greaterThan(0), reason: 'übernommen, aber nicht gemeldet');
    });

    test('die Sprache wird übernommen', () async {
      // Bewusst ausgeschlossen: `isDeviceLocalKey` nennt `languageCode`
      // geräteübergreifend. Das ist eine **Produktentscheidung**, und die
      // überzeugt nicht – Sprache ist eine Vorliebe der Person, nicht des
      // Geräts. Dieser Test hält die neue Absicht fest.
      final SharedPreferences prefsB = await diskWith(<String, Object>{
        'languageCode': 'en',
      });
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      servePushOf('geraet-b');

      final SharedPreferences prefsA = await diskWith(<String, Object>{
        'languageCode': 'de',
      });
      await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      expect(prefsA.getString('languageCode'), 'en',
          reason: 'die Sprache des anderen Geräts kam nicht an');
    });

    test('eine Plan-Einstellung wird übernommen', () async {
      final SharedPreferences prefsB = await diskWith(<String, Object>{
        'defaultPlanModeClass': 'table',
      });
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      servePushOf('geraet-b');

      final SharedPreferences prefsA = await diskWith(<String, Object>{
        'defaultPlanModeClass': 'list',
      });
      await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      expect(prefsA.getString('defaultPlanModeClass'), 'table');
    });

    test('eine neue Einstellung wandert ohne Codeänderung mit', () async {
      // Der eigentliche Punkt: Eine Liste von Schlüsseln kann nicht
      // gleichzeitig vollständig und aktuell sein. Jede neue Einstellung, die
      // jemand hinzufügt, wäre in einer Liste stillschweigend nicht
      // synchronisiert – bis jemand sie nachträglich einträgt.
      const String unbekannt = 'planAnsichtBrennermodus';

      // Ablauf wie in der Wirklichkeit: Erst kommt die Kette zustande, dann
      // wird etwas geändert. Wichtig dabei ist, den Wert **im Speicher** zu
      // ändern und nicht die Platte neu anzulegen – eine neue Platte würde auch
      // den Schatten des zuletzt Gesendeten löschen, und genau der ist das,
      // woran der Sync eine echte Änderung erkennt.
      SharedPreferences prefsB =
          await diskWith(<String, Object>{unbekannt: 'aus'});
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      served = <Map<String, dynamic>>[];

      SharedPreferences prefsA =
          await diskWith(<String, Object>{unbekannt: 'aus'});
      await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      // Jetzt die Änderung auf B, und B meldet noch einmal – erst dadurch hat
      // der Wert überhaupt eine Zeit, die aussagekräftig ist.
      await prefsB.setString(unbekannt, 'an');
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      servePushOf('geraet-b');

      final SyncOutcome outcome =
          await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      expect(outcome.succeeded, isTrue, reason: '${outcome.error}');
      expect(prefsA.getString(unbekannt), 'an',
          reason: 'eine neue Einstellung muss ohne Codeänderung mitwandern');
      expect(outcome.merged, greaterThan(0),
          reason: 'übernommen, aber nicht gemeldet');
    });

    test('bei gleichem Stand kommen beide Geräte zum selben Ergebnis',
        () async {
      // Zwei Geräte, die denselben Stand haben, dürfen nicht verschiedene
      // Ergebnisse behalten – sonst schieben sie ihn endlos hin und her und
      // die Kette kommt nie zur Ruhe.
      //
      // Beide starten ohne Historie, ihre Zeit ist also der Anfang der
      // Zeitachse: ein echter Gleichstand, nicht nur ein gleich schneller Lauf.
      SharedPreferences prefsB =
          await diskWith(<String, Object>{'hideTeacher': true});
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));

      SharedPreferences prefsA =
          await diskWith(<String, Object>{'hideTeacher': false});
      servePushOf('geraet-b');
      final SyncOutcome aufA =
          await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));
      expect(aufA.pulled, 1, reason: 'B wurde nicht gelesen');

      final bool onA = prefsA.getBool('hideTeacher')!;

      // Und nun B mit A als Quelle. Weicht das Ergebnis ab, tauschen die
      // beiden Geräte den Wert bei jedem Lauf.
      servePushOf('geraet-a');
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      expect(prefsB.getBool('hideTeacher'), onA,
          reason: 'die Geräte sind sich uneinig – sie würden endlos tauschen');
    });

    test('Zugangsdaten wandern nie mit', () async {
      final SharedPreferences prefsB = await diskWith(<String, Object>{
        'vplanPassword': 'geheim',
        'vplanUsername': 'mueller',
        'vplanSchoolnumber': '12345',
      });
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      final String alles = jsonEncode(pushes);
      expect(alles, isNot(contains('geheim')));
      expect(alles, isNot(contains('mueller')));
    });
  });

  group('Karten', () {
    test('eine als Map gespeicherte Angabe kommt an', () async {
      // `initializedClasses` und `hiddenSubjectsByClass` sind Maps, keine
      // Listen. Sie standen in `dataKeys`, wurden aber nie übertragen – und
      // wären bei einem Versuch als Liste zur falschen Form geworden.
      final SharedPreferences prefsB = await diskWith(<String, Object>{
        'initializedClasses': jsonEncode(<String, dynamic>{'c1': true}),
        'hiddenSubjectsByClass':
            jsonEncode(<String, dynamic>{'c1': <String>['Deutsch']}),
      });
      await SyncEngine(client: client).run(prefsB, stateOf('geraet-b'));
      servePushOf('geraet-b');

      final SharedPreferences prefsA = await diskWith(<String, Object>{
        'initializedClasses': jsonEncode(<String, dynamic>{'c2': true}),
        'hiddenSubjectsByClass': jsonEncode(<String, dynamic>{}),
      });
      await SyncEngine(client: client).run(prefsA, stateOf('geraet-a'));

      final Map<String, dynamic> init =
          jsonDecode(prefsA.getString('initializedClasses')!) as Map<String, dynamic>;
      expect(init.keys, containsAll(<String>['c1', 'c2']));

      final Map<String, dynamic> hidden =
          jsonDecode(prefsA.getString('hiddenSubjectsByClass')!) as Map<String, dynamic>;
      expect(hidden['c1'], <String>['Deutsch']);
    });
  });
}

/// Ein Client, der mitzählt, was hinausgeht, und eine fertige Antwort
/// zurückgibt. Es wird **nicht** verschlüsselt – die Hülle wird unverändert
/// durchgereicht, genau wie auf dem Server.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.onPut, this.answer);

  final void Function(Map<String, dynamic>) onPut;
  final List<Map<String, dynamic>> Function() answer;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String body = '';
    if (request is http.Request) body = request.body;

    if (request.method == 'PUT' && body.isNotEmpty) {
      onPut(jsonDecode(body) as Map<String, dynamic>);
    }

    final Map<String, dynamic> payload = request.method == 'PUT'
        ? <String, dynamic>{}
        : <String, dynamic>{
            'chainId': 'kette',
            'snapshots': answer(),
            'serverTime': DateTime.now().toUtc().toIso8601String(),
          };

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(payload))),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}
