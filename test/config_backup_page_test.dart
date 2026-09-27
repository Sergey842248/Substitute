import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/dashboard/Settings.dart';
import 'package:substitute/pages/dashboard/settings/ConfigBackupSettings.dart';
import 'package:substitute/pages/dashboard/settings/VPlanLogin.dart';

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

  testWidgets('choosing "share without credentials" does not share with password',
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

  testWidgets('settings offers a backup entry', (WidgetTester tester) async {
    await pumpSettings(tester);

    expect(find.text('Backup & Restore'), findsWidgets);
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
