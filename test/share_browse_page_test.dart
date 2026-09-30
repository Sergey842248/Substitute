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
      // Suchmenü an einen Share kommt.
      expect(find.textContaining('Enter a username'), findsOneWidget);
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
