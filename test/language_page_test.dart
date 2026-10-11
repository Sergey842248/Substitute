import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/dashboard/settings/Language.dart';
import 'package:substitute/services/AppLanguage.dart';

/// Das Menü der Sprachwahl.
///
/// Die Auswahl darf die Einstellung nicht nur anzeigen, sondern muss sie auch
/// so ablegen, dass die App beim nächsten Start in derselben Sprache startet –
/// und bei „Systemsprache" muss **kein** Sprachcode im Speicher landen.
Future<void> pumpLanguage(
  WidgetTester tester, {
  required String locale,
  String? stored,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (stored != null) AppLanguage.storageKey: stored,
  });
  await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(600, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: Locale(locale, ''),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: Language()),
  ));
  await tester.pumpAndSettle();
}

/// Die gerade gewählte Option.
String gewaehlt(WidgetTester tester) {
  final RadioListTile<String> gewaehltTile = tester.widgetList<
      RadioListTile<String>>(find.byType(RadioListTile<String>)).firstWhere(
    // ignore: deprecated_member_use
    (RadioListTile<String> tile) => tile.groupValue == tile.value,
  );
  return gewaehltTile.value!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('das Menü bietet drei Möglichkeiten',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de');

    expect(find.text('Systemsprache'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsNWidgets(3));
  });

  testWidgets('ohne Einstellung ist die Systemsprache gewählt',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de');

    // Vorher stand hier fest "Deutsch".
    expect(gewaehlt(tester), AppLanguage.system);
  });

  testWidgets('"Systemsprache" steht oben', (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de');

    final double system = tester.getTopLeft(find.text('Systemsprache')).dy;
    final double deutsch = tester.getTopLeft(find.text('Deutsch')).dy;
    final double english = tester.getTopLeft(find.text('English')).dy;
    expect(system, lessThan(deutsch));
    expect(deutsch, lessThan(english),
        reason: 'Die Reihenfolge ist: Systemsprache, Deutsch, Englisch.');
  });

  testWidgets('eine bereits getroffene Wahl wird angezeigt',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de', stored: 'en');
    expect(gewaehlt(tester), 'en');
  });

  testWidgets('"Systemsprache" speichert keinen Sprachcode',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de', stored: 'de');

    await tester.tap(find.text('Systemsprache'));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Kein Code, sondern der eigene Wert: Sonst wäre „auf Deutsch" von
    // „der Systemsprache, die Deutsch ist" nicht mehr zu unterscheiden.
    expect(prefs.getString(AppLanguage.storageKey), AppLanguage.system);
    expect(AppLanguage.forMaterialApp(prefs), isNull,
        reason: 'null heißt für MaterialApp: der Systemsprache folgen.');
    expect(gewaehlt(tester), AppLanguage.system);
  });

  testWidgets('"Deutsch" speichert den Sprachcode',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de');

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppLanguage.storageKey), 'de');
    expect(AppLanguage.forMaterialApp(prefs), const Locale('de', ''));
    expect(gewaehlt(tester), 'de');
  });

  testWidgets('"English" speichert den Sprachcode',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de');

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppLanguage.storageKey), 'en');
    expect(AppLanguage.forMaterialApp(prefs), const Locale('en', ''));
    expect(gewaehlt(tester), 'en');
  });

  testWidgets('zurück zur Systemsprache geht jederzeit',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'de', stored: 'en');

    await tester.tap(find.text('Systemsprache'));
    await tester.pumpAndSettle();
    expect(gewaehlt(tester), AppLanguage.system);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(gewaehlt(tester), 'en');
  });

  testWidgets('das Menü ist auf Englisch ebenfalls übersetzt',
      (WidgetTester tester) async {
    await pumpLanguage(tester, locale: 'en');

    expect(find.text('System language'), findsOneWidget);
    // Die Sprachnamen selbst bleiben in ihrer eigenen Sprache – das ist bei
    // "English" und "Deutsch" sowieso richtig, und sonst fände jemand, der
    // Englisch spricht, auf einmal ein deutsches Wort in der Liste.
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}