import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/main.dart';
import 'package:substitute/services/NativeShell.dart';

/// Der Weg von der nativen Seite zum Bildschirm.
///
/// ## Worum es hier geht
///
/// Die native Seite nennt ihren Abschnitt auf **zwei** Wegen: als Startargument
/// (`--substitute-role=…`) und als Route (`/abschnitt/plan`). Beide müssen
/// übereinstimmen, und es ist wichtig, was passiert, wenn eine davon
/// ausfällt – denn die Wege sind nicht gleich gut:
///
/// * Fehlt der **Weg** zu einer Route, findet `Navigator` keinen Generator und
///   die App stürzt **beim Start** ab.
/// * Fehlt die **Rolle**, steht die ganze App da, statt eines Abschnitts. Das
///   ist falsch, aber niemand verliert daran etwas.
///
/// Deshalb ist der Weg immer da und die Rolle nur ein Hinweis.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NativeShell.debugSetRole(NativeShellRole.full);
  });

  group('Der Reiter zu einer Route', () {
    test('steht in der Route, nicht in der Rolle', () {
      // Ohne irgendeine Rolle – so, als kämen die Startargumente nicht an.
      //
      // **Englische** Namen: Die native Seite baut die Route aus der Rolle,
      // und die ist englisch (`search`). Ein deutscher Name hier – so naheliegend
      // er auch wäre – liess den Reiter ins Leere laufen.
      expect(MyApp.startTabForRoute('/abschnitt/plan'), 'vplanStudents');
      expect(MyApp.startTabForRoute('/abschnitt/search'), 'search');
      expect(MyApp.startTabForRoute('/abschnitt/sync'), 'syncShare');
    });

    test('ist ohne native Schale leer', () {
      // `null` heisst: die ganze App, mit ihrer eigenen Leiste. Genau das ist
      // auf Android, im Web und in den meisten Tests der Fall.
      expect(MyApp.startTabForRoute('/'), '');
    });

    test('übersteht eine unbekannte Route', () {
      // Kein Absturz und keine leere Seite: Wer eine Route aufruft, die es
      // nicht gibt, soll die ganze App sehen und nicht nichts.
      for (final String route in <String>[
        '/abschnitt/erfunden',
        '/gibtsnicht',
        '/abschnitt/',
        '',
      ]) {
        expect(MyApp.startTabForRoute(route), '',
            reason: '"$route" ist keine Abschnittsroute');
      }
    });

    test('nimmt den Namen, den die native Seite wirklich sendet', () {
      // Der Fehler, der den Such-Reiter auf „loading…" festhalten ließ:
      // Die native Seite sandte `/abschnitt/search`, hier stand aber
      // `/abschnitt/suche`. Der Rückfall war der leere Wert – und der leere
      // Wert passte zu keinem Eintrag der Seitenliste.
      //
      // Deshalb steht hier ausdrücklich der englische Name. Die Namen auf
      // beiden Seiten müssen **gleich** sein; welcher Sprache sie folgen, ist
      // zweitrangig – wichtig ist nur, dass keiner von ihnen leer ausfällt.
      expect(MyApp.startTabForRoute('/abschnitt/search'), 'search');
      expect(MyApp.startTabForRoute('/abschnitt/suche'), '',
          reason: 'die deutsche Form wird nicht gesendet – siehe oben');
    });

    test('entspricht dem, was die native Seite sendet', () {
      // Die beiden Seiten müssen dasselbe sprechen: Was `RootTabBarController`
      // als `initialRoute` setzt, muss hier wieder ankommen.
      //
      // Der Abschnitt in der Route ist englisch und ohne Bindestrich – die
      // Rolle im Argument ebenfalls. Deshalb heisst es hier "suche" und dort
      // "search": Sie sind verschiedene Stellen, und sie haben verschiedene
      // Namen, aber dieselbe Bedeutung.
      const Map<String, String> erwartet = <String, String>{
        'plan': '/abschnitt/plan',
        'search': '/abschnitt/search',
        'sync': '/abschnitt/sync',
      };
      erwartet.forEach((String rolle, String route) {
        NativeShell.readRole(<String>['--substitute-role=$rolle']);
        // Genau das prüft der Test: Die Rolle wird zu einer Route, und die
        // Route wird wieder zu einem Reiter. Fehlt ein Glied in dieser Kette,
        // bleibt der Bildschirm leer.
        expect(
          MyApp.startTabForRoute(route),
          isNot(''),
          reason: 'die Rolle "$rolle" muss ihre Route "$route" kennen',
        );
      });
    });
  });

  group('Die Rolle', () {
    test('ohne Argument die ganze App', () {
      NativeShell.readRole(<String>[]);
      expect(NativeShell.isSection, isFalse);
    });

    test('mit Argument ein Abschnitt', () {
      NativeShell.readRole(<String>['--substitute-role=plan']);
      expect(NativeShell.isSection, isTrue);
    });
  });
}
