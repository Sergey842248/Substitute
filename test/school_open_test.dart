import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/main.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/pages/dashboard/settings/VPlanLogin.dart';
import 'package:substitute/services/NativeShell.dart';
import 'package:substitute/services/SchoolStorage.dart';

/// Das Öffnen einer **zweiten** Schule – und der Weg zurück zu den Schulen.
///
/// ## Was hier geprüft wird
///
/// * Eine neu angelegte Schule ohne Zugangsdaten führt **direkt** zur Anmeldung,
///   nicht erst zur Hauptansicht (der leeren Klassenauswahl).
/// * Von dieser Anmeldung aus kommt man wieder **zu den Schulen** zurück –
///   auf iOS über die native Schale, weil es dort keine Flutter-Route dorthin
///   gibt.
///
/// Der zweite Punkt ist der Grund, warum es diese Datei gibt: Ein Zurück-Pfeil,
/// der ins Leere zeigt, sieht wie ein Bedienelement aus und ist keines. Auf
/// iOS ist das besonders schlimm, weil dort die Leiste ohne Zugangsdaten
/// ausgeblendet ist – ohne funktionierenden Weg zurück bliebe man auf der
/// Anmeldeseite einer Schule fest, die man gerade erst angelegt hat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String zweiteSchule = '1701';
  const String nutzer = 'gretel';

  setUp(() {
    NativeShell.debugSetRole(NativeShellRole.full);
  });

  /// Legt einen Speicher an, in dem die erste Schule fertig eingerichtet ist und
  /// [zweiteSchule] ohne alles dasteht.
  Future<void> speicherMitNeuerSchule() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'schoolProfiles': jsonEncode(<Map<String, String>>[
        <String, String>{'id': 'default', 'name': 'Meine Schule'},
        <String, String>{'id': zweiteSchule, 'name': 'Schule 2'},
      ]),
      'activeSchoolId': zweiteSchule,
      // Zugangsdaten der **ersten** Schule. Für die zweite sind es keine –
      // genau das ist der Fall, um den es hier geht.
      'vplanUsername': nutzer,
    });
  }

  VPlanLogin anmeldeseite(Widget app) {
    final Widget? page = (app as MyApp).initialPage;
    expect(page, isA<VPlanLogin>(),
        reason: 'ohne Zugangsdaten muss die Anmeldeseite stehen');
    return page! as VPlanLogin;
  }

  group('Der Startbildschirm einer neu angelegten Schule', () {
    test('die erste Schule bleibt eine Pflicht-Anmeldung', () async {
      // Unverändert von jeher: Ohne Zugangsdaten gibt es nichts zu sehen, und
      // zurückzugehen hieße, die App zu verlassen.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final MyApp app = await wartenderAppStart() as MyApp;

      final VPlanLogin seite = anmeldeseite(app);
      expect(seite.blockBack, isTrue);
      expect(seite.onBack, isNull,
          reason:
              'ohne zweite Schule gibt es nichts, wohin zurückzugehen wäre');
    });

    test('eine neue Schule ohne Zugangsdaten landet auf der Anmeldung',
        () async {
      // Das ist der gemeldete Fehler: Statt der Anmeldung erschien die
      // Hauptansicht – die Klassenauswahl eines Bereichs, für den es keine
      // Pläne gibt.
      await speicherMitNeuerSchule();
      final MyApp app = await wartenderAppStart() as MyApp;

      expect(app.initialPage, isA<VPlanLogin>());
    });

    test('eine neue Schule ohne Zugangsdaten ist auf iOS verlassbar', () async {
      // In einem Abschnitt der nativen Schale gibt es keine Flutter-Route zu
      // den Schulen zurück – der Weg muss über die native Seite laufen.
      await speicherMitNeuerSchule();
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);

      final MyApp app = await wartenderAppStart() as MyApp;
      final VPlanLogin seite = anmeldeseite(app);

      expect(seite.blockBack, isFalse, reason: 'sonst ist man festgesetzt');
      expect(seite.onBack, isNotNull,
          reason: 'sonst gäbe es keinen Weg zu den Schulen zurück');
    });

    test('ohne native Schale bleibt die Anmeldung gesperrt', () async {
      // Android und Web: Die Schulen-Übersicht liegt im selben Stapel, dort
      // macht `Navigator.pop` den Rückweg. Für diese Seite ist er nur nicht
      // erreichbar – also gibt es dort diesen Startbildschirm nicht, und ein
      // Pfeil ohne Ziel wäre schlimmer als keiner.
      await speicherMitNeuerSchule();
      NativeShell.debugSetRole(NativeShellRole.full);

      final MyApp app = await wartenderAppStart() as MyApp;
      final VPlanLogin seite = anmeldeseite(app);

      expect(seite.blockBack, isTrue);
      expect(seite.onBack, isNull);
    });
  });

  group('Zurück von der Anmeldung', () {
    Future<void> seiteZeigen(WidgetTester tester, VPlanLogin seite) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MyApp(initialPage: seite));
      // Der Kopfzeile klappt erst nach dem Scrollen ein; erst dann ist der
      // Zurück-Pfeil der sichtbare und der antippbare.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('der Zurück-Pfeil führt zum übergebenen Weg', (tester) async {
      int zurueck = 0;
      await seiteZeigen(tester, VPlanLogin(onBack: () => zurueck++));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pump();

      expect(zurueck, 1);
      expect(
        find.byType(ListPage),
        findsOneWidget,
        reason: 'ohne Rückweg bliebe man auf dieser Seite stehen',
      );
    });

    testWidgets('ohne übergebenen Weg geht es über den Navigator',
        (tester) async {
      // Der Normalfall auf Android: Die Schulen-Übersicht liegt eine Route
      // tiefer, und `Navigator.pop` ist genau der richtige Aufruf.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: ListView(
                children: <Widget>[
                  const Text('Schulen'),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) => const VPlanLogin(),
                      ),
                    ),
                    child: const Text('öffnen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('öffnen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Schulen'), findsOneWidget,
          reason: 'Zurück muss zur Schulen-Übersicht führen');
    });

    testWidgets('als Pflicht-Anmeldung gibt es gar keinen Pfeil',
        (tester) async {
      await seiteZeigen(tester, const VPlanLogin(blockBack: true));

      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });
  });

  group('Die Meldung an die native Seite', () {
    testWidgets('fragt sie um den Weg zu den Schulen', (tester) async {
      final List<MethodCall> gesendet = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeShell.channel,
        (MethodCall call) async {
          gesendet.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(NativeShell.channel, null);
      });

      NativeShell.backToSchools();
      await tester.pump();

      expect(
          gesendet.map((MethodCall c) => c.method), contains('backToSchools'));
    });

    testWidgets('ohne native Seite läuft sie ins Leere', (tester) async {
      // Android und Web haben den Kanal nicht. Ein Fehler hier wäre ein Absturz
      // nur wegen einer Meldung, die dort niemand braucht.
      NativeShell.backToSchools();
      await tester.pump();
    });
  });

  group('Der aktive Bereich zählt', () {
    test('die zweite Schule hat keine Zugangsdaten der ersten', () async {
      await speicherMitNeuerSchule();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(await SchoolStorage.hasCredentials(prefs), isFalse);
      await SchoolStorage.setActiveSchool(SchoolStorage.defaultSchoolId);
      expect(await SchoolStorage.hasCredentials(prefs), isTrue);
    });
  });
}
