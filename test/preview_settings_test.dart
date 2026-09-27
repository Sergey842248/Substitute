import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/dashboard/settings/PlanSettings.dart';
import 'package:substitute/pages/dashboard/settings/PreviewSettings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: PreviewSettings()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('preview submenu shows class and person toggles',
      (WidgetTester tester) async {
    await pump(tester);

    // Der Titel steht in der Kopfzeile (ausgeklappt und eingeklappt).
    expect(find.text('Preview'), findsWidgets);
    expect(find.text('Hide preview for classes'), findsOneWidget);
    expect(find.text('Hide preview for persons'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
  });

  testWidgets('persons are hidden and classes shown by default',
      (WidgetTester tester) async {
    await pump(tester);

    final switches =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    // Reihenfolge: Klassen, dann Personen.
    expect(switches[0].value, isFalse, reason: 'classes default to visible');
    expect(switches[1].value, isTrue, reason: 'persons default to hidden');
  });

  testWidgets('toggling a switch persists the value', (WidgetTester tester) async {
    await pump(tester);

    await tester.tap(find.byType(SwitchListTile).at(1));
    await tester.pumpAndSettle();

    final switches =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches[1].value, isFalse);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hidePreviewPersons'), isFalse);
  });

  testWidgets('plan settings links to the preview submenu',
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
      home: Scaffold(body: PlanSettings()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsOneWidget);

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.byType(PreviewSettings), findsOneWidget);
    expect(find.text('Hide preview for classes'), findsOneWidget);
    expect(find.text('Hide preview for persons'), findsOneWidget);
  });
}
