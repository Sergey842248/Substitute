import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/ClassNames.dart';

/// Die Ordnung der Klassennamen.
///
/// Sie ist keine Geschmacksfrage, sondern die Bedingung dafür, dass die Liste
/// lesbar bleibt: `06.2` vor `11` ist das, was jemand erwartet, und genau das
/// liefert ein reiner Zeichenkettenvergleich **nicht** – dort käme `10` vor
/// `8a`.
void main() {
  List<String> ordnen(List<String> ein) => ClassNames.sortiert(ein);

  group('Zahlen zählen als Zahlen', () {
    test('06.2 steht vor 11', () {
      expect(ordnen(<String>['11', '06.2']), <String>['06.2', '11']);
    });

    test('10 steht nicht vor 8a', () {
      // Der Fehler, den ein Zeichenkettenvergleich macht: '1' < '8'.
      expect(ordnen(<String>['8a', '10']), <String>['8a', '10']);
      expect(ordnen(<String>['10', '8a']), <String>['8a', '10']);
    });

    test('9 steht vor 10 und 100', () {
      expect(ordnen(<String>['100', '9', '10']), <String>['9', '10', '100']);
    });

    test('führende Nullen ändern die Zahl nicht', () {
      expect(ClassNames.compare('06', '6.2'), lessThan(0));
      expect(ClassNames.compare('006', '6'), lessThan(0),
          reason: 'bei gleicher Zahl entscheidet die Schreibweise');
    });

    test('ein Punkt trennt, er wird nicht ignoriert', () {
      // `6.2` ist nicht `62` – sonst stünde `62` zwischen `6` und `7`.
      expect(ClassNames.compare('6.2', '62'), isNot(0));
      expect(ordnen(<String>['62', '6.2', '7']), <String>['6.2', '7', '62']);
    });
  });

  group('Gemischte Namen', () {
    test('Zahlen vor Buchstaben, wie man es liest', () {
      expect(
        ordnen(<String>['Oberstufe', '10b', '9z', 'Abitur']),
        <String>['9z', '10b', 'Abitur', 'Oberstufe'],
      );
    });

    test('Groß- und Kleinschreibung spielt keine Rolle', () {
      expect(ClassNames.compare('8A', '8a'), isNot(0),
          reason: 'es muss entschieden werden');
      expect(ordnen(<String>['8a', '8A']).first, '8A',
          reason: 'bei Gleichstand entscheidet die Schreibweise');
    });

    test('eine realistische Schulklassenliste', () {
      expect(
        ordnen(<String>['11', '06.2', '8a', '10', '7b', '12', '06.1', '9b']),
        <String>['06.1', '06.2', '7b', '8a', '9b', '10', '11', '12'],
      );
    });
  });

  group('Der Vergleich ist immer entschieden', () {
    test('und hängt nicht von der Eingangsreihenfolge ab', () {
      const List<String> namen = <String>['8a', '8A', '06.2', '11', 'B', 'b'];
      expect(ordnen(namen), ordnen(namen.reversed.toList()));
    });

    test('und er ist antisymmetrisch', () {
      const List<String> namen = <String>['8a', '8A', '06.2', '11', 'B', 'b'];
      for (final String a in namen) {
        for (final String b in namen) {
          expect(ClassNames.compare(a, b), -ClassNames.compare(b, a),
              reason: '$a gegen $b');
        }
      }
    });

    test('gleiche Namen ergeben Gleichstand', () {
      expect(ClassNames.compare('8a', '8a'), 0);
      expect(ClassNames.compare('', ''), 0);
    });

    test('leere Namen stehen vorn', () {
      expect(ordnen(<String>['8a', '']), <String>['', '8a']);
    });
  });

  group('Die Originalliste bleibt unangetastet', () {
    test('sortiert gibt eine neue Liste zurück', () {
      final List<String> original = <String>['11', '06.2'];
      ClassNames.sortiert(original);
      expect(original, <String>['11', '06.2'],
          reason: 'die Liste im Speicher darf nicht verändert werden');
    });
  });
}
