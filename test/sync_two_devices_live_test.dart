import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/crypto/Passphrase.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';
import 'package:substitute/services/sync/SyncKeys.dart';

/// Zwei Geräte, ein Server, **echtes** HTTP.
///
/// `sync_engine_test.dart` fährt zwei Geräte mit einem Attrappen-Server.
/// Dieser Test fährt dieselbe Sache gegen die deployed Functions. Der
/// Unterschied ist der ganze Punkt: Ein Fehler in der Übertragung oder in der
/// Function ist mit einem Attrappen-Server prinzipiell unsichtbar – der
/// Attrappe beantwortet alles so, wie man es gerne hätte.
///
/// Zwei Geräte brauchen zwei getrennte Platten. `setMockInitialValues` ist ein
/// globaler Zustand, deshalb wird der Speicher hier als "Platte des gerade
/// aktiven Geräts" benutzt: Vor jedem Gerät wird sie mit dessen Daten
/// beladen, danach wird sie wieder als dessen Platte eingelesen.
void main() {
  final String url = SyncEngine.defaultServerUrl;
  const String passphrase = 'blue sky river seven apple candle';
  const String chainId = 'live-two-devices-probe';

  var reachable = false;
  late SyncApiClient host;
  late SyncApiClient guest;

  setUpAll(() async {
    host = SyncApiClient(baseUrl: Uri.parse(url));
    reachable = await host.isServerRunning();
    if (!reachable) {
      // ignore: avoid_print
      print('  ⚠ $url ist nicht erreichbar – Live-Tests übersprungen.');
      return;
    }
    guest = SyncApiClient(baseUrl: Uri.parse(url));
    await host.deleteChain(chainId);
  });

  tearDownAll(() async {
    if (reachable) await host.deleteChain(chainId);
    host.dispose();
    if (reachable) guest.dispose();
  });

  /// Legt die "Platte" eines Geräts an und gibt die passenden `prefs` zurück.
  ///
  /// Die Speicherform ist hier **absichtlich die aus der App**, nicht die
  /// bequemere: `persons` und `classes` liegen als JSON-Zeichenkette, nur die
  /// Pläne als `StringList`. Ein früherer Fassung dieses Tests legte alles als
  /// Liste ab – und bestand damit genau den Fehler, den die App im echten
  /// Betrieb hatte: Der Leser verwarf die JSON-gespeicherten Bestandteile
  /// kommentarlos, und der Test sah eine Welt, in der das nicht passiert.
  Future<SharedPreferences> diskOf(List<Map<String, dynamic>> persons) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'persons': jsonEncode(persons),
      'offlineVPData': <String>[
        jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Plan von A'}),
      ],
      'classes': jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'c1', 'name': 'Klasse'},
      ]),
    });
    return SharedPreferences.getInstance();
  }

  /// Liest die "Platte" wieder aus – so kommt sie auf das nächste Gerät.
  ///
  /// Über [SyncDataReader.readLines], nicht über `getStringList`: Die Platte
  /// enthält ja gerade Einträge, die als JSON-Zeichenkette gespeichert sind.
  Map<String, Object> plateOf(SharedPreferences prefs) => <String, Object>{
        for (final String key in SyncKeys.dataKeys)
          if (SyncDataReader.readLines(prefs, key).isNotEmpty)
            key: SyncDataReader.readLines(prefs, key),
      };

  /// Legt eine Platte mit beliebigen Werten an.
  Future<SharedPreferences> diskWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(<String, Object>{...values});
    return SharedPreferences.getInstance();
  }

  List<String> namesOn(SharedPreferences prefs, String key) =>
      SyncDataReader.readLines(prefs, SchoolStorage.scopedKey(prefs, key))
          .map((String raw) => (jsonDecode(raw) as Map)['name'].toString())
          .toList();

  SyncState stateFor(String id) => SyncState(
        passphrase: passphrase,
        chainId: chainId,
        deviceId: id,
        deviceName: 'Gerät $id',
        includeSettings: true,
        lastSync: null,
      );

  test('Daten wandern in beide Richtungen', () async {
    if (!reachable) return;

    // --- Gerät A schickt hoch -------------------------------------------
    SharedPreferences prefsA = await diskOf(<Map<String, dynamic>>[
      <String, dynamic>{'id': '1', 'name': 'Nur auf A'},
    ]);
    final SyncOutcome a =
        await SyncEngine(client: host).run(prefsA, stateFor('a'));
    expect(a.succeeded, isTrue, reason: 'A: ${a.error}');
    expect(a.pushed, isTrue, reason: 'A hat nichts hochgeschickt');

    // Steht auf dem Server überhaupt ein Gerät? Sonst ist alles Weitere
    // gegenstandslos.
    final List<SyncDevice> afterA = await host.fetchDevices(chainId);
    expect(afterA.length, 1, reason: 'auf dem Server steht kein Gerät');
    expect(afterA.single.deviceId, 'a');
    expect(afterA.single.deviceName, 'Gerät a');

    final Map<String, Object> plateA = plateOf(prefsA);

    // --- Gerät B zieht ---------------------------------------------------
    SharedPreferences prefsB = await diskOf(<Map<String, dynamic>>[
      <String, dynamic>{'id': '2', 'name': 'Nur auf B'},
    ]);
    final SyncOutcome b =
        await SyncEngine(client: guest).run(prefsB, stateFor('b'));
    expect(b.succeeded, isTrue, reason: 'B: ${b.error}');
    expect(b.pushed, isTrue, reason: 'B hat nicht hochgeschickt');
    expect(b.pulled, 1, reason: 'B hat keine fremde Hülle bekommen');
    expect(b.merged, greaterThan(0), reason: 'B hat nichts von A übernommen');

    // ignore: avoid_print
    print('  B nach dem Lauf: Personen=${namesOn(prefsB, 'persons')} '
        'Pläne=${namesOn(prefsB, 'offlineVPData')}');

    expect(namesOn(prefsB, 'persons'), contains('Nur auf A'),
        reason: 'Die Person von A kam bei B nicht an');
    expect(namesOn(prefsB, 'persons'), contains('Nur auf B'),
        reason: 'Bs eigene Person ist verschwunden');
    expect(namesOn(prefsB, 'offlineVPData'), contains('Plan von A'),
        reason: 'Der Plan von A kam bei B nicht an');

    // --- Zurück auf Gerät A: bekommt A jetzt Bs Daten? -------------------
    SharedPreferences.setMockInitialValues(<String, Object>{
      ...plateA,
      // Der Zustand der Kette gehört ebenfalls zur Platte.
      SyncEngine.stateStorageKey: jsonEncode(stateFor('a').toJson()),
    });
    prefsA = await SharedPreferences.getInstance();

    final SyncOutcome a2 =
        await SyncEngine(client: host).run(prefsA, stateFor('a'));
    expect(a2.succeeded, isTrue, reason: 'A2: ${a2.error}');
    expect(a2.pulled, 1, reason: 'A2 hat Bs Hülle nicht bekommen');
    expect(a2.merged, greaterThan(0), reason: 'A2 hat nichts von B übernommen');

    // ignore: avoid_print
    print('  A nach dem zweiten Lauf: '
        'Personen=${namesOn(prefsA, 'persons')}');

    expect(namesOn(prefsA, 'persons'), contains('Nur auf B'),
        reason: 'Die Person von B kam bei A nicht an');
    expect(namesOn(prefsA, 'persons'), contains('Nur auf A'),
        reason: 'As eigene Person ist verschwunden');
  });

  test('Einstellungen wandern zwischen zwei Geräten', () async {
    if (!reachable) return;
    // Der Punkt, an dem es zuletzt klemmte: Einstellungen wurden gesendet, aber
    // nie angenommen, weil ein einziger Paket-Zeitstempel auf „jetzt" bei jedem
    // Lauf jedes Gerät zum neuesten machte.
    const String passphrase = 'blue sky river seven apple candle';
    final String settingsChain = '$chainId-settings';
    await host.deleteChain(settingsChain);

    SyncState settingsState(String id) => SyncState(
          passphrase: passphrase,
          chainId: settingsChain,
          deviceId: id,
          deviceName: 'Gerät $id',
          includeSettings: true,
          lastSync: null,
        );

    // Gerät B: die Kette einmal aufbauen, damit beide Geräte eine Historie
    // haben. Erst danach zählt eine Änderung als Änderung.
    SharedPreferences prefsB = await diskWith(<String, Object>{
      'hideTeacher': false,
      'languageCode': 'de',
    });
    await SyncEngine(client: guest).run(prefsB, settingsState('b'));

    SharedPreferences prefsA = await diskWith(<String, Object>{
      'hideTeacher': false,
      'languageCode': 'de',
    });
    await SyncEngine(client: host).run(prefsA, settingsState('a'));

    // Jetzt ändert B wirklich etwas – Sprache und Plan-Einstellung.
    await prefsB.setString('languageCode', 'en');
    await prefsB.setBool('hideTeacher', true);
    final SyncOutcome b = await SyncEngine(client: guest)
        .run(prefsB, settingsState('b'));
    expect(b.succeeded, isTrue, reason: 'B: ${b.error}');

    // Und A holt nach.
    final SyncOutcome a = await SyncEngine(client: host)
        .run(prefsA, settingsState('a'));
    expect(a.succeeded, isTrue, reason: 'A: ${a.error}');
    expect(a.pulled, 1, reason: 'B wurde nicht gelesen');

    expect(prefsA.getString('languageCode'), 'en',
        reason: 'die Sprache ist nicht angekommen');
    expect(prefsA.getBool('hideTeacher'), isTrue,
        reason: 'der Schalter ist nicht angekommen');

    await host.deleteChain(settingsChain);
  });

  test('Klassen aus der Auswahl wandern auf das andere Gerät', () async {
    if (!reachable) return;
    // Genau der gemeldete Fall: eine neue Kette starten, auf dem zweiten Gerät
    // beitreten, und die ausgewählten Klassen bleiben lokal.
    //
    // Die Platte wird hier so angelegt, wie es `VPlan.dart` beim Tippen auf
    // „Klasse auswählen" tut – `setStringList(key, ['8a', '8b'])` mit schlichten
    // Namen, ohne JSON. Ein Test mit JSON-Objekten würde eine Welt prüfen, in
    // der die App nicht existiert, und genau daran ist der Fehler entstanden.
    const String classesChain = 'live-classes-probe';
    await host.deleteChain(classesChain);

    SyncState classesState(String id) => SyncState(
          passphrase: passphrase,
          chainId: classesChain,
          deviceId: id,
          deviceName: 'Gerät $id',
          includeSettings: false,
          lastSync: null,
        );

    // Gerät A: zwei Klassen ausgewählt, wie nach dem Tippen in der Auswahl.
    SharedPreferences prefsA = await diskWith(<String, Object>{
      'classes': <String>['8a', '8b'],
    });
    final SyncOutcome a = await SyncEngine(client: host)
        .run(prefsA, classesState('klasse-a'));
    expect(a.succeeded, isTrue, reason: 'A: ${a.error}');
    expect(a.pushed, isTrue);

    // Gerät B tritt bei und hat eine eigene Klasse.
    SharedPreferences prefsB = await diskWith(<String, Object>{
      'classes': <String>['9a'],
    });
    final SyncOutcome b = await SyncEngine(client: guest)
        .run(prefsB, classesState('klasse-b'));
    expect(b.succeeded, isTrue, reason: 'B: ${b.error}');
    expect(b.pulled, 1, reason: 'Gerät A wurde nicht gelesen');

    // ignore: avoid_print
    print('  B sieht: ${prefsB.getStringList('classes')}');

    final List<String> beiB = prefsB.getStringList('classes') ?? const <String>[];
    expect(beiB, containsAll(<String>['8a', '8b']),
        reason: 'die Klassen von A sind nicht angekommen');
    expect(beiB, contains('9a'), reason: 'die eigene Klasse von B ist weg');
    // Und zwar als schlichte Namen – kein `"8a"` mit Anführungszeichen.
    for (final String name in beiB) {
      expect(name, isNot(startsWith('"')), reason: 'als JSON geschrieben: $name');
    }

    // Und zurück zu A.
    final SyncOutcome a2 = await SyncEngine(client: host)
        .run(prefsA, classesState('klasse-a'));
    expect(a2.succeeded, isTrue, reason: 'A2: ${a2.error}');
    expect(prefsA.getStringList('classes'), contains('9a'));

    await host.deleteChain(classesChain);
  });

  test('die Reihenfolge der Klassen wandert mit', () async {
    if (!reachable) return;
    // Der gemeldete Fall: Auf einem Gerät liegen die Klassen in der Reihenfolge
    // `XYZ, ABC`, auf dem anderen angekommen sind sie alphabetisch – also
    // umsortiert. Die Anordnung ist in der App benutzersichtbar.
    const String orderChain = 'live-order-probe';
    await host.deleteChain(orderChain);

    SyncState orderState(String id) => SyncState(
          passphrase: passphrase,
          chainId: orderChain,
          deviceId: id,
          deviceName: 'Gerät $id',
          includeSettings: false,
          lastSync: null,
        );

    SharedPreferences prefsA = await diskWith(<String, Object>{
      'classes': <String>['XYZ', 'ABC'],
    });
    // Einmal syncen, damit beide Geräte eine Historie haben – erst danach gilt
    // eine geänderte Reihenfolge als geändert.
    await SyncEngine(client: host).run(prefsA, orderState('ord-a'));

    SharedPreferences prefsB = await diskWith(<String, Object>{
      'classes': <String>['NUR-B'],
    });
    await SyncEngine(client: guest).run(prefsB, orderState('ord-b'));

    // ignore: avoid_print
    print('  A: ${prefsA.getStringList('classes')}  '
        'B: ${prefsB.getStringList('classes')}');

    final List<String> beiA = prefsA.getStringList('classes') ?? const <String>[];
    final List<String> beiB = prefsB.getStringList('classes') ?? const <String>[];

    expect(beiA.indexOf('XYZ'), lessThan(beiA.indexOf('ABC')),
        reason: 'die eigene Anordnung ist zerschlagen: $beiA');
    expect(beiB.indexOf('XYZ'), lessThan(beiB.indexOf('ABC')),
        reason: 'die Anordnung des anderen Geräts ist nicht angekommen: $beiB');
    expect(beiB, contains('NUR-B'), reason: 'die eigene Klasse ist weg');

    // Und jetzt die entscheidende Probe: B ordnet um – und A folgt.
    await prefsB.setStringList('classes', <String>['NUR-B', 'ABC', 'XYZ']);
    await SyncEngine(client: guest).run(prefsB, orderState('ord-b'));
    await SyncEngine(client: host).run(prefsA, orderState('ord-a'));

    // ignore: avoid_print
    print('  nach dem Umsortieren:  A: ${prefsA.getStringList('classes')}');

    final List<String> danachA = prefsA.getStringList('classes') ?? const <String>[];
    expect(danachA.indexOf('ABC'), lessThan(danachA.indexOf('XYZ')),
        reason: 'die neue Anordnung von B ist nicht angekommen: $danachA');

    await host.deleteChain(orderChain);
  });

  test('nach einem Lauf ist die Kette auf dem Server vollständig',
      () async {
    if (!reachable) return;
    final List<SyncDevice> devices = await host.fetchDevices(chainId);
    expect(devices.map((SyncDevice d) => d.deviceId).toSet(), <String>{'a', 'b'});
  });

  test('die Wortreihenfolge im Sync-Code ist egal', () async {
    if (!reachable) return;
    // Der stille Totalausfall, den niemand sieht: Dieselben zehn Wörter in
    // anderer Reihenfolge ergaben früher eine andere Kette. Beide Geräte
    // meldeten Erfolg, beide zeigten "Letzter Sync", und es kam nichts an –
    // weil jede in einer eigenen, leeren Kette stand.
    const String sorted = 'apple blue candle dog echo mango river seven six sky';
    const String mixed = 'Mango BLUE dog, echo river apple candle sky six seven.';
    expect(Passphrase.normalize(mixed), sorted);
    expect(SyncEngine.chainIdFor(mixed), SyncEngine.chainIdFor(sorted));

    // Und das Ganze einmal über den echten Server: Zwei Geräte, die
    // unterschiedlich getippte Codes eintippen, landen in derselben Kette.
    final String permuted = '$chainId-permuted';
    final String code = 'cat dog bird fish apple mango river seven six sky';
    final String codeShuffled = 'sky six seven river mango apple fish bird dog cat';
    expect(SyncEngine.chainIdFor(code), SyncEngine.chainIdFor(codeShuffled));

    SyncState stateFor2(String id) => SyncState(
          passphrase: code,
          chainId: SyncEngine.chainIdFor(code),
          deviceId: id,
          deviceName: 'Gerät $id',
          includeSettings: true,
          lastSync: null,
        );

    SharedPreferences prefsOne = await diskOf(<Map<String, dynamic>>[
      <String, dynamic>{'id': '1', 'name': 'Nur auf dem ersten'},
    ]);
    await SyncEngine(client: host).run(prefsOne, stateFor2('eins'));

    // Das zweite Gerät tippt die Wörter in umgekehrter Reihenfolge ein.
    SharedPreferences prefsTwo = await diskOf(<Map<String, dynamic>>[
      <String, dynamic>{'id': '2', 'name': 'Nur auf dem zweiten'},
    ]);
    final SyncOutcome second =
        await SyncEngine(client: guest).run(prefsTwo, stateFor2('zwei'));

    expect(second.pulled, 1,
        reason: 'die vertauschte Eingabe hat nicht dieselbe Kette gefunden');
    expect(namesOn(prefsTwo, 'persons'), contains('Nur auf dem ersten'));

    await host.deleteChain(SyncEngine.chainIdFor(code));
  });
}
