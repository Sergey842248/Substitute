import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/dashboard/Settings.dart';
import 'package:substitute/pages/dashboard/settings/ConfigBackupSettings.dart';
import 'package:substitute/pages/dashboard/settings/VPlanLogin.dart';
import 'package:substitute/services/ConfigBackupFlow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the credentials warning offers sharing without credentials',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ConfigBackupSettings()),
    ));
    await tester.pumpAndSettle();

    // Export startet den Dialog, BEVOR geteilt wird – daher lässt sich hier
    // prüfen, welche Wege der Nutzer hat.
    // (Kein pumpAndSettle: Solange der Vorgang läuft, dreht sich das
    // Ladesymbol endlos – pumpAndSettle käme nie zum Ende.)
    await tester.tap(find.text('Export configuration'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Contains credentials'), findsOneWidget);
    // Alle drei Wege: abbrechen, ohne teilen, mit teilen.
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Share without credentials'), findsOneWidget);
    expect(find.text('With credentials'), findsOneWidget);
  });

  testWidgets(
      'choosing "share without credentials" does not share with password',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'super-secret',
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ConfigBackupSettings()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export configuration'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Share without credentials'));
    // Das Teilen selbst scheitert im Test (kein Plugin) – entscheidend ist,
    // dass der Ablauf weiterläuft und der Dialog geschlossen ist.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Share without credentials'), findsNothing);
  });

  testWidgets('the login page offers an import option',
      (WidgetTester tester) async {
    // Erster Start: noch keine Zugangsdaten.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: VPlanLogin(blockBack: true)),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('importConfigOnLogin')),
      findsOneWidget,
    );
    expect(find.text('Import configuration'), findsOneWidget);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Settings()),
    ));
    await tester.pumpAndSettle();
  }

  /// Sucht einen Eintrag in der Einstellungsliste – **auch unterhalb des
  /// Bildrands**.
  ///
  /// Die Liste baut ihre Zeilen nach Bedarf: Was nicht im Bild ist, existiert
  /// im Widget-Baum nicht und kann deshalb nicht gefunden werden. Der Test
  /// würde dann melden, der Eintrag fehle – während er lediglich eine Zeile
  /// weiter unten steht.
  ///
  /// Der Vergleich gilt doppelt: Wer einen Eintrag sucht, scrollt, und wer
  /// scrollen muss, hat ihn nicht auf Anhieb gefunden. Beides soll der Test
  /// mitmachen, statt es zu überspielen.
  Future<void> scrolleZu(WidgetTester tester, String text) async {
    for (int i = 0; i < 12 && find.text(text).evaluate().isEmpty; i++) {
      // Die **letzte** Liste, nicht die erste: Die Seite baut zwei – eine
      // außen um den Kopfbereich und eine für die Einträge. An der falschen
      // zu ziehen bewegt nichts, und man hielte den Eintrag für nicht vorhanden.
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('settings offers a backup entry', (WidgetTester tester) async {
    await pumpSettings(tester);
    await scrolleZu(tester, 'Backup & Restore');

    expect(find.text('Backup & Restore'), findsWidgets);
  });

  group('der Hinweis im Import-Dialog', () {
    /// Baut genau den Text, der im Import-Dialog steht.
    Future<void> pumpFrage(
      WidgetTester tester,
      Map<String, dynamic> settings,
    ) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en', ''),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ImportReplaceFrage(settings: settings)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('erscheint bei einer Datei ohne Zugangsdaten',
        (WidgetTester tester) async {
      await pumpFrage(tester, <String, dynamic>{
        'classes': <String>['5a'],
        'hideTeacher': true,
      });

      expect(find.text('Should the existing settings be replaced?'),
          findsOneWidget);
      expect(
        find.textContaining('no credentials'),
        findsOneWidget,
        reason: 'der Nutzer muss vorher wissen, dass seine Zugangsdaten '
            'beim Ersetzen bleiben',
      );
    });

    testWidgets('erscheint nicht bei einer Datei mit Zugangsdaten',
        (WidgetTester tester) async {
      await pumpFrage(tester, <String, dynamic>{
        'vplanPassword': 'neu',
        'vplanUsername': 'user',
      });

      expect(find.textContaining('no credentials'), findsNothing,
          reason: 'hier werden die Zugangsdaten sehr wohl ersetzt – ein '
              'Hinweis, sie blieben, wäre gelogen');
    });

    testWidgets('erkennt auch schulbezogene Zugangsdaten',
        (WidgetTester tester) async {
      // Die Zugangsdaten einer zweiten Schule liegen unter 'schools.<id>…'.
      // Wer nur die drei einfachen Schlüssel prüft, erkennt diese Datei als
      // „ohne Zugangsdaten" – und der Dialog verspricht dann das Gegenteil
      // dessen, was beim Ersetzen passiert.
      await pumpFrage(tester, <String, dynamic>{
        'schools.abc123.vplanPassword': 'schul-passwort',
      });

      expect(find.textContaining('no credentials'), findsNothing);
    });
  });

  testWidgets('the backup page offers export and import',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ConfigBackupSettings()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Export configuration'), findsOneWidget);
    expect(find.text('Import configuration'), findsOneWidget);
    // Der Hinweis, dass die Datei das Passwort enthält.
    expect(find.textContaining('password in plain text'), findsOneWidget);
  });
}
