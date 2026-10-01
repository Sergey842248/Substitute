import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/ClassNames.dart';
import 'package:substitute/services/sync/SyncKeys.dart';
import 'package:substitute/services/sync/SyncMerge.dart';
import 'package:substitute/services/sync/SyncPayload.dart';

/// Klassen sind **immer** sortiert – und zwar so, wie Menschen lesen:
/// `06.2` vor `11`.
///
/// Das ist eine bewusste Umkehr der Anordnung, die vorher mitgewandert ist.
/// Eine übernommene Reihenfolge klingt plausibel, hat hier aber zwei Mängel:
///
/// * Zwei Geräte müssen sich auf eine Reihenfolge einigen, die niemand
///   verlangt hat. Jede neue Klasse, die nur auf einem Gerät existiert,
///   müsste irgendwo einsortiert werden – und die Frage „wo?" hätte keine
///   Antwort.
/// * Sie bliebe erhalten, auch wenn jemand eine Klasse anlegt, die nicht
///   passt. Die Liste enthielte dann `11, 06.2, 8a`, und das ist der Zustand,
///   den man nicht haben will.
///
/// Eine berechnete Ordnung hat keinen dieser beiden Mängel: Sie ist auf jedem
/// Gerät gleich, und sie stimmt nach jedem Anlegen und Entfernen von selbst.
void main() {
  SyncPayload mit(List<String> namen, {DateTime? orderAt}) => SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', namen.cast<Object>(),
              orderAt: orderAt),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );

  List<String> ergebnisVon(SyncMergeResult r) => <String>[
        for (final Object item in r.parts.single.items) item as String,
      ];

  group('Der Merge sortiert die Klassen', () {
    test('06.2 steht vor 11', () {
      final SyncMergeResult r = SyncMerge.merge(
        mit(<String>['11', '06.2', '8a', '10']),
        mit(<String>['11', '06.2', '8a', '10']),
      );
      expect(ergebnisVon(r), <String>['06.2', '8a', '10', '11']);
    });

    test('auch dann, wenn die Geräte unterschiedlich angelegt wurden', () {
      // A hat [XYZ, ABC] angelegt, B [ABC, XYZ]. Die Ordnung ist berechnet,
      // also spielt es keine Rolle, in welcher Reihenfolge jemand getippt hat.
      final SyncMergeResult r = SyncMerge.merge(
        mit(<String>['XYZ', 'ABC']),
        mit(<String>['ABC', 'XYZ']),
      );
      expect(ergebnisVon(r), <String>['ABC', 'XYZ']);
    });

    test('eine neu hinzugekommene Klasse landet an ihrer Stelle', () {
      final SyncMergeResult r = SyncMerge.merge(
        mit(<String>['06.2', '11']),
        mit(<String>['06.2', '11', '07.1']),
      );
      expect(ergebnisVon(r), <String>['06.2', '07.1', '11'],
          reason: 'die neue Klasse steht nicht am Ende');
    });

    test('das Ergebnis ist unabhängig von der Richtung', () {
      final SyncPayload a = mit(<String>['11', '06.2', '8a']);
      final SyncPayload b = mit(<String>['9z', '10b']);
      expect(ergebnisVon(SyncMerge.merge(a, b)),
          ergebnisVon(SyncMerge.merge(b, a)));
    });

    test('und es hängt auch nicht davon ab, wer die Reihenfolge zuletzt änderte', () {
      // Zwei Geräte, deren `orderAt` weit auseinanderliegt: Die berechnete
      // Ordnung muss trotzdem dieselbe sein, sonst hätten die Geräte
      // unterschiedliche Listen.
      final SyncPayload frueh = mit(<String>['11', '06.2'],
          orderAt: DateTime.utc(2026, 10, 1, 10));
      final SyncPayload spaet = mit(<String>['06.2', '11'],
          orderAt: DateTime.utc(2026, 10, 1, 11));
      expect(ergebnisVon(SyncMerge.merge(frueh, spaet)),
          ergebnisVon(SyncMerge.merge(spaet, frueh)));
    });
  });

  group('Die App und der Sync benutzen dieselbe Ordnung', () {
    test('was der Sync schreibt, ist genau das, was ClassNames liefert', () async {
      // Sonst hätte das Gerät, das zuletzt geschrieben hat, eine andere
      // Reihenfolge als das andere – und die Liste wechselte bei jedem Sync.
      const List<String> unsortiert = <String>['11', '06.2', '8a', '10', '07.1'];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': unsortiert,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SyncPayload eigen = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', <Object>['11', '06.2']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final SyncPayload fremd = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('classes', <Object>['8a', '10', '07.1']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );

      final SyncMergeResult r = SyncMerge.merge(eigen, fremd);
      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: r.parts,
          tombstones: r.tombstones,
          settings: r.settings ?? const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      );

      expect(prefs.getStringList('classes'),
          ClassNames.sortiert(<String>['11', '06.2', '8a', '10', '07.1']));
    });

    test('eine alte, unsortierte Liste wird beim Lesen sortiert', () {
      // Der Bestand auf einem Gerät, das schon länger installiert ist. Beim
      // Lesen zu sortieren richtet das, ohne dass jemand eine Klasse anlegen
      // oder entfernen muss.
      expect(
        ClassNames.sortiert(<String>['11', '06.2', '8a']),
        <String>['06.2', '8a', '11'],
      );
    });
  });

  group('Andere Bestandteile bleiben unberührt', () {
    test('Pläne werden nach Datum geordnet', () {
      // Der Vertretungsplan-Cache ist über das Datum geschlüsselt; die App
      // sucht darin nach Datum. Eine übernommene Reihenfolge wäre hier sinnlos.
      final SyncPayload a = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('offlineVPData', <Object>[
            <String, dynamic>{'date': '2026-10-03', 'name': 'C'},
            <String, dynamic>{'date': '2026-10-01', 'name': 'A'},
          ]),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final SyncPayload b = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('offlineVPData', <Object>[
            <String, dynamic>{'date': '2026-10-02', 'name': 'B'},
          ]),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final List<String> daten = (SyncMerge.merge(a, b).parts.single.items)
          .map((Object i) => (i as Map)['date'].toString())
          .toList();
      expect(daten, <String>['2026-10-01', '2026-10-02', '2026-10-03']);
    });

    test('andere schulbezogene Klassenlisten werden ebenso behandelt', () {
      final SyncPayload fremd = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('schools.abc.classes', <Object>['11', '06.2']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final SyncPayload eigen = SyncPayload(
        parts: <SyncPart>[
          SyncPayload.describePart('schools.abc.classes', <Object>['8a']),
        ],
        tombstones: const <SyncTombstone>[],
        settings: const <String, dynamic>{},
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final List<String> namen = ergebnisVon(SyncMerge.merge(eigen, fremd));
      expect(namen, <String>['06.2', '8a', '11']);
    });
  });

  group('Die Form bleibt, wie sie ist', () {
    test('und es sind nach wie vor schlichte Namen', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncMergeResult r = SyncMerge.merge(
        mit(<String>['11', '06.2']),
        mit(<String>['8a']),
      );
      await SyncMerge.applyToPreferences(
        prefs,
        SyncPayload(
          parts: r.parts,
          tombstones: r.tombstones,
          settings: r.settings ?? const <String, dynamic>{},
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      );
      final List<String> geschrieben = prefs.getStringList('classes')!;
      expect(geschrieben, <String>['06.2', '8a', '11']);
      for (final String name in geschrieben) {
        expect(name, isNot(startsWith('"')), reason: 'als JSON geschrieben: $name');
      }
      expect(SyncKeys.itemKeys, contains('classes'));
    });
  });
}
