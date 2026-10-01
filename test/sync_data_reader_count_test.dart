import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/SyncKeys.dart';

/// Zählt die Einträge, die ein Sync übertragen würde.
///
/// Der Anlass ist ein Absturz: Beim Öffnen des Sync-Menüs kam
/// `type 'String' is not a subtype of type 'List<dynamic>?' in type cast`.
/// Ursache war ein `prefs.getStringList` über `SyncKeys.dataKeys` – aber die
/// App speichert die Hälfte dieser Schlüssel als **JSON-Zeichenkette**, nicht
/// als Liste. `getStringList` wirft daraufhin einen TypeError statt `null` zu
/// liefern, und die Seite stirbt an einer Zahl, die nur eine Anzeige tragen
/// sollte.
///
/// Dieser Test geht deshalb über *jeden* Schlüssel aus [SyncKeys.dataKeys]
/// und legt jeden in genau der Form an, in der die App ihn wirklich schreibt.
void main() {
  /// Legt alle Daten-Schlüssel so an, wie es `VPlanAPI` und
  /// `DeveloperOptions` tun: die einen als String-Liste, die anderen als
  /// JSON-Zeichenkette. Die Liste hier ist aus dem Quelltext abgelesen und
  /// nicht geraten – sie hat sich als genau richtig erwiesen, sonst gäbe es
  /// diesen Test nicht.
  Future<SharedPreferences> withAllDataKeys() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      // Als Liste gespeichert.
      'classes': <String>[jsonEncode(<String, dynamic>{'id': 'c1', 'name': '8a'})],
      'offlineVPData': <String>[
        jsonEncode(<String, dynamic>{'date': '2026-10-01', 'name': 'Plan'}),
      ],
      'cachedRooms': <String>[jsonEncode(<String, dynamic>{'id': 'r1'})],
      'previewHiddenClasses': <String>[jsonEncode(<String, dynamic>{'id': 'c1'})],
      'previewHiddenPersons': <String>[jsonEncode(<String, dynamic>{'id': 'p1'})],
      'initializedClasses': <String>[jsonEncode(<String, dynamic>{'id': 'c1'})],

      // Als JSON-Zeichenkette gespeichert. Genau hier steckt der Absturz.
      'persons': jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'Hans'},
        <String, dynamic>{'id': '2', 'name': 'Petra'},
      ]),
      'classNames': jsonEncode(<String>['8a', '8b']),
      'sickTrack': jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'name': 'Krank'},
      ]),
      'lessontimes': '[]',
      'teacherShorts': '',
      'hiddenSubjectsByClass': jsonEncode(<String, dynamic>{'c1': <String>['Deutsch']}),
    });
    return SharedPreferences.getInstance();
  }

  group('Zählen der übertragbaren Einträge', () {
    test('übersteht einen Schlüssel, der kein String-Listen-Typ ist',
        () async {
      final SharedPreferences prefs = await withAllDataKeys();
      // Das ist der eigentliche Test: Ein Aufruf hier hat das Menü abstürzen
      // lassen. Er muss einfach durchlaufen.
      expect(
        () => SyncDataReader.countItemsOf(
          prefs,
          SyncKeys.dataKeys.map((String k) => SchoolStorage.scopedKey(prefs, k)).toList(),
        ),
        returnsNormally,
      );
    });

    test('zählt die Personen, die als JSON-Zeichenkette liegen', () async {
      final SharedPreferences prefs = await withAllDataKeys();
      expect(SyncDataReader.countItems(prefs, 'persons'), 2);
    });

    test('liest die Personen wirklich – der Pfad, den der Sync nimmt',
        () async {
      // Das ist der Test, der den Ausfallverlust festhält. `countItems` ist
      // nur eine Anzeige; `readParts` ist der Weg, über den ein Sync
      // tatsächlich Daten überträgt. Vorher lieferte dieser Aufruf für
      // `persons` eine leere Liste – kein Fehler, kein Logeintrag, einfach
      // nichts. Der Sync meldete Erfolg und übertrug nur noch die Pläne.
      final SharedPreferences prefs = await withAllDataKeys();
      final Map<String, List<Map<String, dynamic>>> parts =
          await SyncDataReader.readParts(prefs, SyncKeys.dataKeys);
      expect(parts.keys, contains('persons'));
      expect(
        parts['persons']!.map((Map<String, dynamic> p) => p['name']).toList(),
        <String>['Hans', 'Petra'],
      );
      expect(parts.keys, contains('classes'));
      expect(parts.keys, contains('sickTrack'));
      // Und die Pläne, die als Liste liegen, kommen weiterhin mit.
      expect(parts.keys, contains('offlineVPData'));
    });

    test('die geteilten Personen-Listen überleben den JSON-Typ', () async {
      // Dieselbe Ursache, anderer Ort: Der Share-Pfad liest `persons`, das als
      // JSON-Zeichenkette vorliegt. Ein `getStringList` dort wirft einen
      // TypeError und reißt die Seite mit – beim Öffnen des Sync-Menüs genauso
      // wie beim Teilen von Personen. Beide Stellen lesen jetzt über denselben
      // Leser, und dieser Test hält fest, dass er die Form liefert, die beide
      // erwarten.
      final SharedPreferences prefs = await withAllDataKeys();
      final List<String> lines =
          SyncDataReader.readLines(prefs, 'persons');
      expect(lines.length, 2);
      for (final String line in lines) {
        expect(() => jsonDecode(line), returnsNormally,
            reason: 'jede Zeile muss JSON sein, sonst fällt sie später weg');
      }
      expect(
        lines
            .map((String l) => (jsonDecode(l) as Map)['name'].toString())
            .toList(),
        <String>['Hans', 'Petra'],
      );
    });

    test('ein Schalter unter einem Daten-Schlüssel wirft nicht', () async {
      // Der alte Code hat im `catch` `return const []` gemacht und damit jede
      // andere Speicherform ungeprüft gelassen. Jetzt wird weitergearbeitet und
      // der zweite Weg versucht – ein Boolean ergibt dort nichts.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'sickTrack': true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(SyncDataReader.countItems(prefs, 'sickTrack'), 0);
    });

    test('zählt die Pläne, die als Liste liegen', () async {
      final SharedPreferences prefs = await withAllDataKeys();
      expect(SyncDataReader.countItems(prefs, 'offlineVPData'), 1);
    });

    test('eine leere Zeichenkette zählt null', () async {
      // `teacherShorts` wird von den Entwicklereinstellungen mit `''`
      // initialisiert. Das ist kein Fehler, nur nichts da.
      final SharedPreferences prefs = await withAllDataKeys();
      expect(SyncDataReader.countItems(prefs, 'teacherShorts'), 0);
    });

    test('eine leere Liste zählt null', () async {
      final SharedPreferences prefs = await withAllDataKeys();
      expect(SyncDataReader.countItems(prefs, 'lessontimes'), 0);
    });

    test('ein unbekannter Schlüssel zählt null und wirft nicht', () async {
      final SharedPreferences prefs = await withAllDataKeys();
      expect(SyncDataReader.countItems(prefs, 'gibt-es-nicht'), 0);
    });

    test('die Summe ist die, die der Sync wirklich schickt', () async {
      // Die entscheidende Zusicherung: Die Anzeige darf nicht eine Zahl
      // nennen, die der Sync nicht liefert. Also derselbe Schlüssel, dieselbe
      // Dekodierregel.
      final SharedPreferences prefs = await withAllDataKeys();
      final List<String> keys = <String>[
        for (final String key in SyncKeys.dataKeys)
          SchoolStorage.scopedKey(prefs, key),
      ];
      final int counted = SyncDataReader.countItemsOf(prefs, keys);
      final Map<String, List<Map<String, dynamic>>> read =
          await SyncDataReader.readParts(prefs, keys);
      final int actuallySent =
          read.values.fold(0, (int sum, List<Map<String, dynamic>> l) => sum + l.length);
      expect(counted, actuallySent,
          reason: 'die Anzeige zählt $counted, der Sync schickt $actuallySent');
      expect(counted, greaterThan(0));
    });

    test('die Reihenfolge ist unerheblich', () async {
      final SharedPreferences prefs = await withAllDataKeys();
      final int a = SyncDataReader.countItemsOf(prefs, SyncKeys.dataKeys);
      final int b = SyncDataReader.countItemsOf(prefs, SyncKeys.dataKeys.reversed.toList());
      expect(a, b);
    });
  });

  group('getStringList wäre hier gescheitert', () {
    test('der direkte Aufruf wirft – deshalb der Umweg', () async {
      final SharedPreferences prefs = await withAllDataKeys();
      // Diese Zusicherung hält fest, warum der Umweg überhaupt nötig ist.
      // Fiele sie irgendwann weg, könnte man meinen, `countItems` sei
      // übertrieben – und es wäre nur noch Gewohnheit.
      expect(() => prefs.getStringList('persons'), throwsA(isA<TypeError>()));
    });
  });
}
