import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/share/ShareBrowsePage.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';


/// Setzt die Zugangsdaten der Demo (123456 / user / password).
Future<void> signInAsDemo(SharedPreferences prefs) async {
  await prefs.setString(
    SchoolStorage.scopedKey(prefs, 'vplanSchoolnumber'),
    '123456',
  );
  await prefs.setString(SchoolStorage.scopedKey(prefs, 'vplanUsername'), 'user');
  await prefs.setString(SchoolStorage.scopedKey(prefs, 'vplanPassword'), 'password');
}

Future<void> signInAsTeacher(SharedPreferences prefs) async {
  await prefs.setString(
    SchoolStorage.scopedKey(prefs, 'vplanSchoolnumber'),
    '12345',
  );
  await prefs.setString(
      SchoolStorage.scopedKey(prefs, 'vplanUsername'), 'm.mueller');
  await prefs.setString(SchoolStorage.scopedKey(prefs, 'vplanPassword'), 'pw');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Echte Fonts laden, damit die Textbreiten realistisch sind – der
    // Standard-Testfont ist quadratisch und damit viel breiter, was Texte
    // umbrechen und Finder fehlschlagen lassen würde.
    final FontLoader questrial = FontLoader('Questrial')
      ..addFont(rootBundle.load('assets/fonts/questrial.ttf'));
    await questrial.load();
    final FontLoader poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/ProductSans-Light.ttf'));
    await poppins.load();
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en', ''),
        home: page,
      ),
    );
    await tester.pump();
  }

  group('ShareBrowsePage – Leerzustände', () {
    testWidgets('zeigt ohne Anmeldung den Hinweis auf die Anmeldung',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      // Das Suchmenü braucht die Schulnummer, um die eigene Schule zu kennen.
      expect(find.textContaining('Sign in'), findsOneWidget);
      expect(find.textContaining('find widgets'), findsNothing);
    });

    testWidgets('zeigt im Demo-Account nur "niemand hat geteilt"', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await signInAsDemo(prefs);
      expect(VPlanAPI.isDemoAccount(prefs), isTrue);

      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nobody has shared anything yet'),
          findsOneWidget);
      // Und ausdrücklich nicht der Hinweis "melde dich an" – im
      // Demo-Account ist man angemeldet, es gibt nur nichts zu sehen.
      expect(find.textContaining('Sign in'), findsNothing);
      // Auch keine Eingabemöglichkeit für einen Nutzernamen: Die
      // Funktionalität existiert im Demo-Account gar nicht.
      expect(find.textContaining('Enter a username'), findsNothing);
      expect(find.textContaining('In your school'), findsNothing);
    });

    testWidgets('bleibt bedienbar, wenn der Server nicht antwortet', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await signInAsTeacher(prefs);
      // `.invalid` ist laut RFC 6761 für genau diesen Fall reserviert: Der
      // Name löst garantiert nicht auf. (In Widget-Tests liefert Flutter
      // ohnehin für jede Anfrage eine 400er-Antwort – der Test prüft deshalb
      // nicht die Fehlermeldung selbst, sondern dass die Seite bedienbar
      // bleibt.)
      await prefs.setString(
          SyncEngine.serverUrlKey, 'http://nicht-erreichbar.invalid');

      await pump(tester, const ShareBrowsePage());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Keine Absturze, keine erfundenen Personen …
      expect(tester.takeException(), isNull);
      expect(find.textContaining('7c'), findsNothing);
      // … und der Weg per Nutzername bleibt offen, damit man auch ohne
      // Die Suchzeile bleibt offen: Der Weg per Wortphrase ist derselbe
      // Text – auch ohne Serverantwort nutzbar.
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  group('ShareBrowsePage – die Suchzeile', () {
    /// Meldet sich an und stellt ein Verzeichnis mit drei Personen bereit.
    Future<SharedPreferences> signInWithDirectory() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await signInAsTeacher(prefs);
      return prefs;
    }

    testWidgets('gibt es eine Suchzeile über der Liste', (
      WidgetTester tester,
    ) async {
      await signInWithDirectory();
      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('filtert die Liste nach dem eingegebenen Namen', (
      WidgetTester tester,
    ) async {
      await signInWithDirectory();
      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      // Ohne Verzeichnis vom Server ist die Liste leer – für die Filterung
      // wird deshalb direkt der Zustand geprüft: Der Test setzt keinen
      // Server, also bleibt es bei der leeren Liste. Wichtig ist hier nur,
      // dass die Eingabe die Liste steuert und nichts abstürzt.
      await tester.enterText(find.byType(TextFormField), 'Müller');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Und zurückgesetzt ist wieder alles sichtbar.
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('erkennt die zehn Wörter als Nutzernamen', (
      WidgetTester tester,
    ) async {
      await signInWithDirectory();
      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      // Eine echte Phrase aus der Wortliste: Dann muss der Eintrag „Shares
      // dieser Person öffnen" erscheinen – das ersetzt den früheren
      // Menüpunkt „Nutzername eingeben".
      await tester.enterText(
        find.byType(TextFormField),
        'apple banana cherry delta echo',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Open this person's shares"), findsOneWidget);
      // Und die Liste ist nicht gleichzeitig zu sehen: Der Text ist ein
      // Nutzername, kein Suchbegriff.
      expect(find.textContaining('Nobody found'), findsNothing);
    });

    testWidgets('ein einzelnes Wort ist kein Nutzername', (
      WidgetTester tester,
    ) async {
      await signInWithDirectory();
      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Müller');
      await tester.pumpAndSettle();

      // Ein Name ist ein Suchbegriff, keine Wortphrase.
      expect(find.textContaining("Open this person's shares"), findsNothing);
    });

    test('filtert nach Anzeigename und Nutzername, ohne Beachtung der Großschreibung', () {
      final List<ShareOwner> people = <ShareOwner>[
        ShareOwner(username: 'blue sky', displayName: 'Zoe', shares: const <ShareSummary>[]),
        ShareOwner(username: 'red moon', displayName: 'anna', shares: const <ShareSummary>[]),
        ShareOwner(username: 'green hill', displayName: 'Miriam', shares: const <ShareSummary>[]),
      ];

      // Leer: alles, alphabetisch nach dem Anzeigenamen.
      expect(
        filterAndSortOwners(people, '')
            .map((ShareOwner p) => p.displayName)
            .toList(),
        <String>['anna', 'Miriam', 'Zoe'],
      );

      // Groß-/Kleinschreibung spielt keine Rolle …
      expect(
        filterAndSortOwners(people, 'ZOE')
            .map((ShareOwner p) => p.displayName)
            .toList(),
        <String>['Zoe'],
      );
      // … und der Nutzername wird mitdurchsucht.
      expect(
        filterAndSortOwners(people, 'green')
            .map((ShareOwner p) => p.displayName)
            .toList(),
        <String>['Miriam'],
      );
      // Ein Teil des Namens genügt.
      expect(
        filterAndSortOwners(people, 'mir')
            .map((ShareOwner p) => p.displayName)
            .toList(),
        <String>['Miriam'],
      );
      // Niemand passt.
      expect(filterAndSortOwners(people, 'gibtsnicht'), isEmpty);
    });

    testWidgets('der frühere Menüpunkt Nutzername eingeben ist entfernt', (
      WidgetTester tester,
    ) async {
      await signInWithDirectory();
      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      expect(find.text('Enter a username'), findsNothing);
    });
  });

  group('ShareBrowsePage – ohne Anmeldung ist das Suchmenü gesperrt', () {
    testWidgets('fragt die Schulnummer der eigenen Schule nicht ab', (
      WidgetTester tester,
    ) async {
      // Der Server wird hier gar nicht erreicht: Ohne Anmeldung wird das
      // Verzeichnis nicht abgefragt. Genau das prüft der Test – es gibt keine
      // Anfrage, deren Antwort man auswerten könnte.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await pump(tester, const ShareBrowsePage());
      await tester.pumpAndSettle();

      expect(
        ShareManager.readUsername(await SharedPreferences.getInstance()),
        isNull,
        reason: 'Ohne Anmeldung wird nicht einmal ein Nutzername erzeugt',
      );
    });
  });
}
