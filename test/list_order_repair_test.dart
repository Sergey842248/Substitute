import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/ClassNames.dart';
import 'package:substitute/services/ListOrderRepair.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/StorageStartupRepair.dart';

/// Nach dem Update müssen **bestehende** Listen mit sortiert werden.
///
/// Die Sortierung greift beim Anlegen und Entfernen einer Klasse – aber sie
/// erreicht die Listen nicht, die **vorher** geschrieben wurden. Sie stammen
/// aus einer Zeit, in der die Reihenfolge der Eingabe folgte: Wer `11` vor
/// `06.2` angelegt hatte, hatte danach `11, 06.2`, und daran ändert das Sortieren
/// beim Anlegen nichts mehr. Ohne einen Durchgang beim Start bliebe es so, bis
/// jemand zufällig eine Klasse hinzufügt – oder für immer, wenn niemand das tut.
///
/// Der Durchgang ist an keine Bedingung geknüpft: Er prüft vor dem Schreiben und
/// tut bei bereits richtigen Listen nichts. Damit heilt er sich selbst, statt
/// nach einem Update nur einmal zu laufen.
void main() {
  group('Bereits vorhandene Klassen', () {
    test('werden beim Start sortiert', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['11', '06.2', '8a', '10', '07.1'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(prefs.getStringList('classes'),
          <String>['11', '06.2', '8a', '10', '07.1'],
          reason: 'Ausgangslage: so hat die App es bisher gespeichert');

      final int repariert = await ListOrderRepair.repairAll(prefs);

      expect(repariert, greaterThan(0), reason: 'es wurde nichts gemacht');
      expect(prefs.getStringList('classes'),
          <String>['06.2', '07.1', '8a', '10', '11']);
    });

    test('und zwar so, wie Menschen lesen', () async {
      // Genau die Verwechslung, die der Auftrag nennt: `06.2` vor `11`, und
      // `8a` vor `10`.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['10', '11', '06.2', '8a', '9z', '07.1'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ListOrderRepair.repairAll(prefs);
      expect(prefs.getStringList('classes'),
          ClassNames.sortiert(<String>['10', '11', '06.2', '8a', '9z', '07.1']));
      expect(prefs.getStringList('classes'),
          <String>['06.2', '07.1', '8a', '9z', '10', '11']);
    });

    test('bereits sortierte Listen bleiben unangetastet', () async {
      // Ohne diese Prüfung schriebe der Durchgang bei jedem Start dieselbe
      // Liste neu – das wäre Verschleiß ohne Nutzen, und auf der SD-Karte
      // spürbar.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['06.2', '8a', '10', '11'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(await ListOrderRepair.repairAll(prefs), 0);
      expect(prefs.getStringList('classes'), <String>['06.2', '8a', '10', '11']);
    });

    test('eine leere Liste ist kein Fall', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(await ListOrderRepair.repairAll(prefs), 0);
    });

    test('und die Form bleibt die der App – eine StringList', () async {
      // Würde der Durchgang als JSON-Zeichenkette schreiben, stünde `classes`
      // danach als String da, und `VPlanAPI.getClasses` – das einen
      // `getStringList` darauf macht – würde beim Start einen TypeError werfen.
      // Genau daran ist die App einmal unstartbar geworden.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['11', '06.2'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ListOrderRepair.repairAll(prefs);

      expect(() => prefs.getStringList('classes'), returnsNormally);
      expect(() => prefs.getString('classes'), throwsA(isA<TypeError>()),
          reason: 'als JSON geschrieben – die App startet damit nicht mehr');
    });
  });

  group('Alle Schulen, nicht nur die aktive', () {
    test('jede bekannte Schule wird repariert', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'schoolProfiles': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'default', 'name': 'Meine Schule'},
          <String, dynamic>{'id': 'gym', 'name': 'Gymnasium Nord'},
        ]),
        'activeSchoolId': 'gym',
        // Die aktive Schule, unsortiert …
        'schools.gym.classes': <String>['11', '06.2'],
        // … und eine andere, die man sonst leicht übersieht.
        'schools.real.classes': <String>['10', '06.2'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Das Profil „real" steht nicht in der Profilliste, die Daten sind aber
      // da – etwa weil das Profil gelöscht wurde. Aus der Profilliste allein
      // würde diese Schule nicht gefunden, und ihre Klassen tauchten beim
      // Umschalten wieder unsortiert auf.
      final int repariert = await ListOrderRepair.repairAll(prefs);

      expect(repariert, greaterThan(0));
      expect(prefs.getStringList('schools.gym.classes'), <String>['06.2', '11']);
      expect(prefs.getStringList('schools.real.classes'), <String>['06.2', '10'],
          reason: 'die andere Schule wurde nicht repariert');
    });

    test('eine kaputte Profilliste ist kein Grund abzubrechen', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'schoolProfiles': 'kein json {{{',
        'classes': <String>['11', '06.2'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Es bleibt bei der aktiven Schule – besser so, als Profile zu erfinden.
      expect(await ListOrderRepair.repairAll(prefs), greaterThan(0));
      expect(prefs.getStringList('classes'), <String>['06.2', '11']);
    });
  });

  group('Pläne', () {
    test('der Cache wird nach Datum geordnet', () async {
      // Der Plancache ist über das Datum geschlüsselt, und die App sucht darin
      // nach Datum. Die Reihenfolge darin ist nie von einem Menschen
      // zusammengestellt worden – sie folgt der Reihenfolge, in der die Tage
      // kamen – also gehört sie von Anfang an sortiert.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-03', 'name': 'C'}),
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'A'}),
          jsonEncode(<String, dynamic>{'date': '2026-10-02', 'name': 'B'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(await ListOrderRepair.repairAll(prefs), greaterThan(0));
      final List<String> daten = (prefs.getStringList('offlineVPData')!)
          .map((String raw) => (jsonDecode(raw) as Map)['date'].toString())
          .toList();
      expect(daten, <String>['2026-10-01', '2026-10-02', '2026-10-03']);
    });

    test('dabei gehen keine Pläne verloren', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-03', 'name': 'C'}),
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'A'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ListOrderRepair.repairAll(prefs);

      final List<String> namen = (prefs.getStringList('offlineVPData')!)
          .map((String raw) => (jsonDecode(raw) as Map)['name'].toString())
          .toList();
      expect(namen, <String>['A', 'C'],
          reason: 'ein Plan ist verschwunden oder verändert worden');
    });

    test('ein einzelner Plan wird nicht angefasst', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'A'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(await ListOrderRepair.repairAll(prefs), 0);
    });
  });

  group('Der Start der App', () {
    test('bringt eine bestehende Klassenliste in Ordnung', () async {
      // Geprüft wird `StorageStartupRepair.run` – also genau das, was `main()`
      // aufruft. `main()` selbst lässt sich in einem Test nicht ausführen, es
      // macht `runApp`; deshalb steht der Ablauf in dieser Funktion.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['11', '06.2', '8a', '10', '07.1'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final StartupRepairReport bericht =
          await StorageStartupRepair.run(prefs);

      expect(prefs.getStringList('classes'),
          <String>['06.2', '07.1', '8a', '10', '11'],
          reason: 'die bestehende Liste ist nicht sortiert worden');
      expect(bericht.listsReordered, greaterThan(0));
      expect(bericht.isEmpty, isFalse);
    });

    test('und ebenso die Pläne einer bestehenden App', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-03', 'name': 'C'}),
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'A'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await StorageStartupRepair.run(prefs);

      final List<String> daten = (prefs.getStringList('offlineVPData')!)
          .map((String raw) => (jsonDecode(raw) as Map)['date'].toString())
          .toList();
      expect(daten, <String>['2026-10-01', '2026-10-03']);
    });

    test('eine bereits in Ordnung gebrachte App meldet „nichts"', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['06.2', '8a', '10'],
        'offlineVPData': <String>[
          jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'A'}),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect((await StorageStartupRepair.run(prefs)).isEmpty, isTrue);
    });

    test('die Form wird dabei mit in Ordnung gebracht', () async {
      // Beide Durchgänge gehören zusammen: Der eine ist aus einem Absturz
      // entstanden, der andere aus der neuen Sortierregel. Steht nur einer in
      // `main()`, bliebe der andere liegen.
      SharedPreferences.setMockInitialValues(<String, Object>{
        // `persons` als Liste, obwohl die App einen String erwartet – damit
        // war die App nicht startbar.
        'persons': <String>[jsonEncode(<String, dynamic>{'id': '1', 'name': 'H'})],
        'classes': <String>['11', '06.2'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final StartupRepairReport bericht =
          await StorageStartupRepair.run(prefs);

      expect(bericht.formsFixed, greaterThan(0), reason: 'die Form blieb falsch');
      expect(bericht.listsReordered, greaterThan(0), reason: 'die Ordnung blieb');
      expect(() => prefs.getString('persons'), returnsNormally,
          reason: 'ohne das startet die App nicht mehr');
      expect(prefs.getStringList('classes'), <String>['06.2', '11']);
    });
  });

  group('Der Schulwechsel', () {
    test('die Liste einer anderen Schule ist danach in Ordnung', () async {
      // Der Punkt, an dem es auffällt: Wer auf eine andere Schule umschaltet,
      // darf keine unsortierte Liste vorfinden.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'schoolProfiles': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'a', 'name': 'Schule A'},
          <String, dynamic>{'id': 'b', 'name': 'Schule B'},
        ]),
        'activeSchoolId': 'a',
        'schools.a.classes': <String>['11', '06.2'],
        'schools.b.classes': <String>['10', '06.2'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ListOrderRepair.repairAll(prefs);

      for (final String id in <String>['a', 'b']) {
        await SchoolStorage.setActiveSchool(id);
        final List<String>? klasse = prefs.getStringList(
          SchoolStorage.scopedKey(prefs, 'classes'),
        );
        expect(klasse, ClassNames.sortiert(klasse!),
            reason: 'Schule $id ist nicht sortiert: $klasse');
      }
    });
  });
}
