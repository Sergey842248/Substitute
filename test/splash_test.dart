import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/splash.dart';

/// Der Startbildschirm: prüft die Zusagen, die er macht.
///
/// 1. Er hält die App **nicht** auf – kein Warten, kein Nachfragen. Das war
///    einmal anders (eine Mindestzeit von 1,5 Sekunden) und ist wieder rückgängig
///    gemacht: Sie hat die App um eine Sekunde verzögert, ohne dass jemand
///    dafür etwas bekommen hätte.
/// 2. Er steht, **solange** das Laden dauert – sonst sähe man eine leere
///    Fläche, und das wäre schlimmer als eine Verzögerung.
/// 3. Beim Übergang wird er **über** die App geblendet, nicht weggeworfen: Die
///    App muss schon stehen und schon benutzbar sein, während er noch auf ihr
///    liegt.
/// 4. Scheitert das Laden, sagt er das – statt endlos weiterzulaufen.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// Lädt eine App, die man von aussen erkennt.
  Widget tuApp() => const MaterialApp(
        home: Scaffold(body: Center(child: Text('DIE APP'))),
      );

  group('SplashGate', () {
    testWidgets('hält die App nicht auf: nach dem Laden nur noch die Blende',
        (WidgetTester t) async {
      // Der Test, der vor dieser Änderung fehlte – und deshalb ihr Dasein
      // verlängerte. Das Laden hier ist **sofort** fertig, und gemessen wird
      // die Zeit von da an bis zum Verschwinden des Startbildschirms.
      //
      // Früher stand hier eine Mindestzeit von 1500 ms, und dieser Test prüfte
      // ihr Gegenteil. Damit wurde sichergestellt, dass die App **langsamer**
      // startet als nötig.
      await t.pumpWidget(SplashGate(starten: () async => tuApp()));

      // Ein Bild: Die App ist geladen und steht hinter dem Startbildschirm.
      await t.pump();
      expect(find.text('DIE APP'), findsOneWidget);

      // Gemessen wird in Schritten statt mit einer festen Zahl: Wann die Blende
      // genau beginnt, hängt davon ab, in welchem Bild das Laden fertig wird.
      // Eine feste Zahl müsste man beim nächsten Umbau neu suchen – und würde
      // stillschweigend falsch, sobald sich etwas verschiebt.
      final Duration gebraucht = await _bisDerStartbildschirmWegIst(t);

      // Erlaubt sind die Blende und **ein Bild** darüber hinaus: Das Bild, in
      // dem das Ende der Animation sichtbar wird und der Bildschirm abgebaut
      // wird. Das ist keine Wartezeit, sondern das Ende jeder Animation.
      const Duration bild = Duration(milliseconds: 17);
      expect(
        gebraucht.inMicroseconds,
        lessThan((kSplashAusblenden + bild * 2).inMicroseconds),
        reason: 'nach dem Laden darf nur noch die Blende kommen, '
            'sonst hält der Startbildschirm künstlich fest',
      );
    });

    testWidgets('die Blende ist die einzige Zeit zwischen Laden und App',
        (WidgetTester t) async {
      await t.pumpWidget(SplashGate(starten: () async => tuApp()));

      // Kurz vor dem Ende der Blende steht er noch – das ist die Überblendung,
      // keine Wartezeit.
      await t.pump();
      await t.pump(kSplashAusblenden ~/ 2);
      expect(find.byType(SplashScreen), findsOneWidget,
          reason: 'die Blende muss man noch sehen');

      await t.pump(kSplashAusblenden);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('gibt Eingaben an die App durch, während sie noch da steht',
        (WidgetTester t) async {
      // Solange der Startbildschirm noch auf der App liegt, ist die App
      // darunter **bereits benutzbar**: Kein `IgnorePointer`, kein Warten auf
      // das Ende der Blende. Sonst wäre die Blende eine Sperre und keine
      // Überblendung.
      int getippt = 0;
      await t.pumpWidget(
        SplashGate(
          starten: () async => MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onTap: () => getippt++,
                child: const Text('DIE APP'),
              ),
            ),
          ),
        ),
      );
      await t.pump();

      expect(find.byType(SplashScreen), findsOneWidget,
          reason: 'der Startbildschirm steht noch über der App');

      await t.tap(find.text('DIE APP'));
      await t.pump();
      expect(getippt, 1,
          reason: 'ein Tipp muss durch den Startbildschirm durchgehen');
    });

    testWidgets('steht, solange das Laden dauert, und hält danach nicht',
        (WidgetTester t) async {
      // Das Gegenstück zum ersten Test: Hier dauert das Laden **länger**, und
      // der Startbildschirm muss die ganze Zeit über stehen.
      await t.pumpWidget(
        SplashGate(
          starten: () async {
            await Future<void>.delayed(const Duration(milliseconds: 2000));
            return tuApp();
          },
        ),
      );

      await t.pump(const Duration(milliseconds: 1500));
      expect(find.byType(SplashScreen), findsOneWidget,
          reason: 'während des Ladens steht der Startbildschirm');

      // Und direkt nach dem Laden ist er weg – ohne eine weitere Sekunde.
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(find.text('DIE APP'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing,
          reason: 'direkt nach dem Laden, ohne zusätzliche Wartezeit');
    });

    testWidgets('blendet über die App, statt sie zu ersetzen',
        (WidgetTester t) async {
      await t.pumpWidget(SplashGate(starten: () async => tuApp()));
      await t.pump();

      // Beide gleichzeitig: die App ist gebaut, der Startbildschirm liegt noch
      // auf ihr. Genau das ist der Punkt von `SplashGate` – und das, was den
      // Übergang von einem Sprung zu einer Überblendung macht.
      expect(find.text('DIE APP'), findsOneWidget);
      expect(find.byType(SplashScreen), findsOneWidget);

      await t.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('zeigt einen Hinweis, wenn das Laden scheitert',
        (WidgetTester t) async {
      // Ohne diesen Test wäre ein Fehler im Laden ein **endloser
      // Startbildschirm**: Man drückt auf das Icon, es passiert etwas, und
      // nach einer Sekunde ist es wieder weg. Schlechter als ein Absturz, weil
      // es sich nicht wie ein Fehler anfühlt.
      await t.pumpWidget(
        SplashGate(
            starten: () async => throw StateError('Laden fehlgeschlagen')),
      );
      await t.pump();
      await t.pump();

      expect(find.textContaining('nicht geladen werden'), findsOneWidget,
          reason: 'der Nutzer muss sehen, dass etwas schiefging');
      expect(find.byType(SplashScreen), findsNothing,
          reason: 'der Startbildschirm darf nicht weiterlaufen');
    });
  });

  group('SplashScreen', () {
    testWidgets('ist im Dunkeln, wenn nichts eingestellt ist',
        (WidgetTester t) async {
      // Ohne Eintrag ist die App dunkel – so sieht sie aus, wenn der Nutzer
      // die Einstellung nie geöffnet hat.
      await t.pumpWidget(_huelle(SplashScreen()));
      await t.pump();
      expect(_grund(t), SplashFarben.grundDunkel);
    });

    testWidgets('folgt der themes Einstellung', (WidgetTester t) async {
      // Eigener Test, eigener Zustand: `SharedPreferences` merkt sich die
      // Instanz einmalig. Ein zweites `setMockInitialValues` im selben Test
      // ändert daran nichts mehr – der Bildschirm bliebe dunkel, und man
      // sucht den Fehler im Bildschirm statt in der Vorbereitung.
      SharedPreferences.setMockInitialValues(
          <String, Object>{'appearance.theme': 'light'});
      await t.pumpWidget(_huelle(SplashScreen()));
      await t.pump();
      await t.pump();
      expect(_grund(t), SplashFarben.grundHell);
    });

    testWidgets('zeichnet den Kalender und dreht den Ring',
        (WidgetTester t) async {
      await t.pumpWidget(_huelle(SplashScreen()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // Der Ring steht bei zwei verschiedenen Zeitpunkten an anderer Stelle:
      // Er dreht sich also, statt zu pulsieren.
      final double erst = _ringBogen(t);
      await t.pump(const Duration(milliseconds: 600));
      final double dann = _ringBogen(t);
      expect(erst, isNot(dann), reason: 'der Tauschring muss sich drehen');
    });
  });
}

/// Die Hülle, in der der Startbildschirm in Tests steht.
///
/// Ohne `MaterialApp`, weil er selbst keine braucht: Er baut kein Theme auf,
/// weil es beim Start noch keins gibt.
Widget _huelle(Widget kind) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 390, height: 844, child: kind),
    );

/// Der Grund, auf dem der Startbildschirm steht.
Color _grund(WidgetTester t) =>
    t.widgetList<ColoredBox>(find.byType(ColoredBox)).first.color;

/// Wieviel des Rings gezeichnet ist – ein Mass dafür, ob er sich bewegt.
///
/// Gelesen wird die Drehung, die der Maler bekommen hat, und nicht das Bild:
/// Das Bild zu messen hiesse, über eine Farbe zu raten.
double _ringBogen(WidgetTester t) {
  final CustomPaint rahmen = t.widget<CustomPaint>(
    find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(CustomPaint),
    ),
  );
  final Object? maler = rahmen.painter;
  return (maler! as dynamic).drehung as double;
}

/// Misst, wie lange von jetzt an noch vergeht, bis der Startbildschirm weg ist.
///
/// In Schritten von 17 ms – einem Bild bei 60 Hz – statt in einem Sprung:
/// Der Zeitpunkt, an dem die Blende endet, ist eine Rechnung über Bilder, und
/// eine Rechnung prüft man nicht, indem man eine Zahl nachschlägt.
///
/// Der Endwert kommt zurück, **nicht** das Ergebnis: Aufrufer sollen selbst
/// entscheiden, was erlaubt ist.
Future<Duration> _bisDerStartbildschirmWegIst(WidgetTester t) async {
  const Duration schritt = Duration(milliseconds: 17);
  Duration vergangen = Duration.zero;
  while (find.byType(SplashScreen).evaluate().isNotEmpty) {
    await t.pump(schritt);
    vergangen += schritt;
    // Eine Sicherung gegen Endlosschleifen: Der Startbildschirm muss weggehen.
    // Ohne diese bricht ein Fehler in `SplashGate` den Testlauf hier ab, statt
    // er weiterzulaufen, bis das Test-Framework nachgibt.
    if (vergangen > const Duration(seconds: 5)) {
      return vergangen;
    }
  }
  return vergangen;
}
