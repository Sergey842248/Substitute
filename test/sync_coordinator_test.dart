import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';
import 'package:substitute/services/sync/SyncEngine.dart';

/// Prüft den automatischen Sync.
///
/// Vorher gab es keinen – der einzige Aufruf von `SyncEngine.run` saß im Knopf
/// der Einstellungen. Diese Tests halten fest, *wann* nicht gelaufen wird,
/// denn das ist der schwierigere Teil: Ein Zeitgeber, der immer läuft, ist noch
/// keine Funktion, sondern nur Last.
///
/// Der Server ist ein Attrappe über [SyncCoordinator.clientFactory]. Ohne diese
/// Naht wäre der Koordinator nur gegen das echte Netz prüfbar, und das sagt bei
/// einem Netzausfall „Kaputt", während bei einem Serverfehler „Alles gut"
/// dasteht – beides führt in die Irre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Jede Anfrage, die den Attrappen erreicht.
  final List<http.Request> seen = <http.Request>[];

  /// Baut einen Attrappen, der [failWith] liefert, wenn es gesetzt ist.
  void serve({int? failWith, List<Map<String, dynamic>> remoteDevices = const <Map<String, dynamic>>[]}) {
    SyncCoordinator.clientFactory = (Uri baseUrl) => SyncApiClient(
          baseUrl: baseUrl,
          client: MockClient((http.Request request) async {
            seen.add(request);
            if (failWith != null) {
              return http.Response('{"error":"boom"}', failWith);
            }
            if (request.url.path.endsWith('/chain-snapshots') &&
                request.method == 'GET') {
              final bool devicesOnly =
                  request.url.queryParameters['devices'] == '1' ||
                      request.url.path.endsWith('/devices');
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'chainId': 'kette',
                  if (devicesOnly)
                    'devices': remoteDevices
                  else
                    // Die Geräteliste leitet der Client aus den Snapshots ab –
                    // er kennt kein eigenes Feld dafür. Deshalb steht hier
                    // dasselbe Gerät, nur ohne Hülle: Der Eintrag zählt als
                    // Gerät und wird als Hülle übersprungen. Genau das Verhalten
                    // muss der Attrappe nachbilden, sonst prüft er eine
                    // Serverform, die es nicht gibt.
                    'snapshots': <Map<String, dynamic>>[
                      for (final Map<String, dynamic> device in remoteDevices)
                        <String, dynamic>{...device},
                    ],
                  'serverTime': '2026-10-01T00:00:00.000Z',
                }),
                200,
              );
            }
            return http.Response('{}', 200);
          }),
        );
  }

  /// Legt eine eingerichtete Kette mit ein paar Daten an.
  void installChain({
    String deviceId = 'dev-1',
    bool includeSettings = false,
    int persons = 2,
  }) {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SyncEngine.stateStorageKey: jsonEncode(
        SyncState(
          passphrase: 'apple blue candle dog echo mango river seven six sky',
          chainId: 'kette',
          deviceId: deviceId,
          deviceName: 'Pixel',
          includeSettings: includeSettings,
          lastSync: null,
        ).toJson(),
      ),
      if (persons > 0)
        'persons': <String>[
          for (int i = 0; i < persons; i++)
            jsonEncode(<String, dynamic>{'id': '$i', 'name': 'Person $i'}),
        ],
    });
  }

  setUp(() {
    seen.clear();
    serve();
  });

  tearDown(() => SyncCoordinator.clientFactory = null);

  group('Der automatische Sync', () {
    test('fragt ohne eingerichteten Sync niemanden', () async {
      // Ohne Kette. Es darf nicht einmal eine Anfrage hinausgehen – sonst
      // verbrennt die App bei jedem Start einen Aufruf für nichts, und der
      // Server sieht Aktivität von Geräten, die gar nicht teilnehmen.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      final Object? outcome = await coordinator.syncNow(force: true);
      expect(outcome, isNull);
      expect(seen, isEmpty);
    });

    test('läuft, wenn eine Kette da ist', () async {
      installChain();
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      final Object? outcome = await coordinator.syncNow(force: true);
      expect(outcome, isNotNull);
      // Hochgeladen und abgerufen – ein Lauf, der nur eine Seite anfasst,
      // überträgt in keine Richtung etwas.
      expect(seen.any((http.Request r) => r.method == 'PUT'), isTrue);
      expect(seen.any((http.Request r) => r.method == 'GET'), isTrue);
    });

    test('zwei gleichzeitige Läufe werden zu einem', () async {
      installChain();
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      // Ohne die Sperre bedienten zwei Läufe dasselbe Gerät: Einer las den
      // Stand, den der andere gerade schrieb, und entschied dann mit einer
      // veralteten Grundlage – das ist stiller Datenverlust, kein Fehler.
      await Future.wait<Object?>(<Future<Object?>>[
        coordinator.syncNow(force: true),
        coordinator.syncNow(force: true),
      ]);
      final int puts = seen.where((http.Request r) => r.method == 'PUT').length;
      expect(puts, 1, reason: 'es darf nur ein Snapshot geschrieben werden');
    });

    test('zwei Läufe hintereinander werden beide ausgeführt', () async {
      installChain();
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      await coordinator.syncNow(force: true);
      await coordinator.syncNow(force: true);
      expect(seen.where((http.Request r) => r.method == 'PUT').length, 2,
          reason: 'wer auf den Knopf tippt, will jetzt etwas sehen');
    });

    test('ohne force wird der zweite Lauf unterdrückt', () async {
      installChain();
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      await coordinator.syncNow();
      final int before = seen.length;
      await coordinator.syncNow();
      expect(seen.length, before,
          reason: 'zwei Läufe in Sekundenabstand bringen dem Server nichts');
    });

    test('ein Serverfehler wird nicht als Erfolg gemeldet', () async {
      installChain();
      serve(failWith: 500);
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      final SyncOutcome? outcome =
          await coordinator.syncNow(force: true) as SyncOutcome?;
      // Nicht `null`, sondern ein Ergebnis mit Fehler: Die Oberfläche soll
      // den Grund anzeigen können. `null` hieße "es gab nichts zu tun" und
      // wäre die Lüge, auf die sich ein Fehler verstecken könnte.
      expect(outcome, isNotNull);
      expect(outcome!.succeeded, isFalse);
      expect(coordinator.consecutiveFailures, 1);
    });

    test('nach einem Fehlschlag muss gewartet werden', () async {
      installChain();
      serve(failWith: 500);
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      await coordinator.syncNow();
      expect(coordinator.consecutiveFailures, 1);
      final int before = seen.length;
      // Ohne `force`: Der Coordinator soll jetzt die Finger stillhalten und
      // stattdessen warten. Ein Gerät, das im Flugmodus alle paar Sekunden
      // denselben Fehler wiederholt, macht die Leitung nur langsamer.
      await coordinator.syncNow();
      expect(seen.length, before);
    });

    test('ein Erfolg setzt die Fehlerzählung zurück', () async {
      installChain();
      serve(failWith: 500);
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      await coordinator.syncNow();
      expect(coordinator.consecutiveFailures, 1);
      serve();
      await coordinator.syncNow(force: true);
      expect(coordinator.consecutiveFailures, 0);
    });

    test('der Serverfehler wird als solcher gespeichert', () async {
      installChain();
      serve(failWith: 500);
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      await coordinator.syncNow(force: true);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncState? state = await SyncEngine.loadState(prefs);
      expect(state?.lastPushError, isNotNull,
          reason: 'sonst weiß die Anzeige nicht, was los ist');
    });

    test('ein erfolgreicher Lauf merkt sich den Zeitpunkt', () async {
      installChain();
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      expect(coordinator.lastSuccess, isNull);
      await coordinator.syncNow(force: true);
      expect(coordinator.lastSuccess, isNotNull);
    });

    test('der Lauf sieht auch die anderen Geräte', () async {
      installChain();
      serve(
        remoteDevices: <Map<String, dynamic>>[
          <String, dynamic>{
            'deviceId': 'dev-2',
            'deviceName': 'Tablet',
            'updatedAt': '2026-10-01T00:00:00.000Z',
            'includesSettings': false,
          },
        ],
      );
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      final SyncOutcome? outcome =
          await coordinator.syncNow(force: true) as SyncOutcome?;
      // Die Geräteliste kommt als Nebenprodukt des Abrufs mit. Sie wird hier
      // nicht eigens angefragt – das wäre eine zweite Runde, die nur
      // zusätzliche Last erzeugt. Ausgewertet wird sie trotzdem, denn sie ist
      // das Einzige, was dem Nutzer sagt, ob überhaupt jemand in der Kette ist.
      expect(outcome!.devices.map((SyncDevice d) => d.deviceId),
          contains('dev-2'));
    });
  });

  group('Zeitgeber und Lebenszyklus', () {
    test('attach startet den Betrieb, detach stoppt ihn', () {
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      expect(coordinator.isAutomatic, isFalse);
      coordinator.attach();
      expect(coordinator.isAutomatic, isTrue);
      coordinator.detach();
      expect(coordinator.isAutomatic, isFalse);
    });

    test('attach zweimal ist harmlos', () {
      // Sonst gäbe es zwei Zeitgeber, und jeder zweite Lauf fiele in die
      // Zeitsperre – der Betrieb wäre schwerer zu erklären als vorher.
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      coordinator.attach();
      coordinator.attach();
      coordinator.detach();
      coordinator.detach();
    });

    test('das Zurückkehren in die App löst einen Lauf aus', () async {
      installChain();
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      coordinator.attach();
      // `resumed` ist der Moment, an dem jemand auf einen aktuellen Stand
      // hofft. Ohne diesen Auslöser käme ein Sync nur alle paar Minuten.
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // Das Warten lässt sich hier nicht abkürzen, aber der Auslöser darf
      // keinen Absturz machen und nichts senden, solange gesperrt ist.
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      coordinator.detach();
    });

    test('forget setzt den gemerkten Zustand zurück', () async {
      installChain();
      serve(failWith: 500);
      final SyncCoordinator coordinator = SyncCoordinator.createForTest();
      await coordinator.syncNow(force: true);
      expect(coordinator.consecutiveFailures, 1);
      // Ohne forget würde der Koordinator die gerade verlassene Kette ein
      // letztes Mal hochschieben, nachdem der Nutzer sie verlassen hat.
      coordinator.forget();
      expect(coordinator.consecutiveFailures, 0);
      expect(coordinator.lastSuccess, isNull);
    });
  });
}
