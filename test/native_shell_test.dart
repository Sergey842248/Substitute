import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/NativeShell.dart';

/// Die Brücke zur nativen `UIKit`-Schale.
///
/// Der Schwerpunkt liegt auf den zwei Entscheidungen, die ein Fehler still
/// treffen würde: **welche** Rolle eine Ansicht hat und **wer** den
/// Hintergrundauftrag macht. Der zweite Punkt ist der gefährlichere – ein
/// dreifacher Sync sieht man erst, wenn die Anfragen beim Server ankommen.
void main() {
  // Nötig, weil [NativeShell] über den Methodenkanal spricht – und der
  // braucht die Bindung, auch dann, wenn es niemanden gibt, der antwortet.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Die Rolle ist ein Zustand der App und überlebt sonst zwischen den
    // Tests. Ohne das würde der letzte Test den nächsten verfälschen.
    NativeShell.debugSetRole(NativeShellRole.full);
  });

  group('Die Rolle aus den Startargumenten', () {
    test('ohne Argumente ist es die ganze App', () {
      // Android, Web und jeder Test hier. Die App verhält sich exakt wie
      // vorher – inklusive eigener Navigationsleiste.
      NativeShell.readRole(<String>[]);
      expect(NativeShell.role, NativeShellRole.full);
      expect(NativeShell.isSection, isFalse);
    });

    test('aus dem Argument der nativen Schale', () {
      NativeShell.readRole(<String>['--substitute-role=plan']);
      expect(NativeShell.role, NativeShellRole.sectionPlan);

      NativeShell.readRole(<String>['--substitute-role=search']);
      expect(NativeShell.role, NativeShellRole.sectionSearch);

      NativeShell.readRole(<String>['--substitute-role=sync']);
      expect(NativeShell.role, NativeShellRole.sectionSync);
    });

    test('Fremde Argumente stören nicht', () {
      // Auf iOS kommen weitere Argumente dazu; die darf `readRole` nicht
      // übersehen und sich für „keine Schale" entscheiden.
      NativeShell.readRole(<String>[
        '--dart-flags=--enable-asserts',
        '--substitute-role=sync',
        '--trace-startup',
      ]);
      expect(NativeShell.role, NativeShellRole.sectionSync);
    });

    test('ein unbekannter Abschnitt ergibt die ganze App', () {
      // Lieber eine ganze App als eine, die auf einen Abschnitt wartet, den
      // es nicht gibt – die bliebe leer ststehen.
      NativeShell.readRole(<String>['--substitute-role=erfunden']);
      expect(NativeShell.role, NativeShellRole.full);
    });

    test('das erste Argument gewinnt', () {
      // Zwei Rollen zugleich sind widersprüchlich; stillschweigend die erste
      // zu nehmen ist besser, als eine zu erfinden.
      NativeShell.readRole(<String>[
        '--substitute-role=search',
        '--substitute-role=sync',
      ]);
      expect(NativeShell.role, NativeShellRole.sectionSearch);
    });
  });

  group('Wer den Hintergrundauftrag macht', () {
    test('ohne Schale die ganze App', () {
      NativeShell.debugSetRole(NativeShellRole.full);
      expect(NativeShell.runsBackgroundWork, isTrue);
    });

    test('bei der nativen Schale **nur** die Plan-Ansicht', () {
      // Der Kern dieser ganzen Konstruktion.
      //
      // Unter der nativen Schale laufen drei Flutter-Ansichten, jede mit ihrem
      // eigenen Zustand im Speicher zu. Lief der Auftrag in allen, würde er
      // dreimal stattfinden – und die Ansichten könnten einander nicht
      // abwehren, weil jede nur weiß, ob **sie** gerade läuft.
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      expect(NativeShell.runsBackgroundWork, isTrue);

      NativeShell.debugSetRole(NativeShellRole.sectionSearch);
      expect(NativeShell.runsBackgroundWork, isFalse,
          reason: 'Suche und Sync holen nichts im Hintergrund.');

      NativeShell.debugSetRole(NativeShellRole.sectionSync);
      expect(NativeShell.runsBackgroundWork, isFalse,
          reason: 'Nur einmal Sync, nicht einmal je Abschnitt.');
    });
  });

  group('Die Startroute', () {
    test('passt zur Rolle', () {
      NativeShell.readRole(<String>['--substitute-role=plan']);
      expect(NativeShell.initialRoute, '/abschnitt/plan');

      NativeShell.readRole(<String>['--substitute-role=search']);
      expect(NativeShell.initialRoute, '/abschnitt/suche');

      NativeShell.readRole(<String>['--substitute-role=sync']);
      expect(NativeShell.initialRoute, '/abschnitt/sync');
    });

    test('ohne Schale ist sie die Wurzel', () {
      NativeShell.debugSetRole(NativeShellRole.full);
      expect(NativeShell.initialRoute, '/');
    });
  });

  group('Was an die native Seite gemeldet wird', () {
    test('aus einem Abschnitt heraus gar nichts', () {
      // Die Abschnitte melden nichts: Es gibt nichts, was die Leiste aus
      // ihnen erfahren müsste, und die Einstellungen stehen in derselben
      // Ablage. Jede Meldung wäre ein Umweg ohne Ziel.
      //
      // Und sie könnten nicht einmal ankommen: Der Kanal einer Ansicht, die
      // gerade nicht gebaut wurde, existiert auf der nativen Seite noch gar
      // nicht.
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      expect(NativeShell.isSection, isTrue);
    });

    testWidgets('aus der ganzen App heraus – ohne zu scheitern',
        (WidgetTester tester) async {
      // Ohne native Seite gibt es den Kanal nicht. Der Aufruf muss trotzdem
      // vorübergehen: Ein `MissingPluginException` hier wäre ein Absturz nur
      // wegen einer Meldung, die auf Android und im Web niemand braucht.
      //
      // Und er darf **nicht** warten – siehe [NativeShell.notifySettingsChanged].
      // Der Test würde sonst an einer Antwort hängen, die nie kommt.
      NativeShell.debugSetRole(NativeShellRole.full);

      final Stopwatch uhr = Stopwatch()..start();
      NativeShell.notifySettingsChanged();
      NativeShell.setChromeVisible(false);
      uhr.stop();

      expect(uhr.elapsedMilliseconds, lessThan(100),
          reason: 'eine Meldung darf das Warten nie aufhalten');
      await tester.pump();
    });
  });
}
