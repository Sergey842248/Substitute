import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/dashboard/settings/PlanModeSettings.dart';
import 'package:substitute/services/PlanModePreferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // Die Seite baut ihre Gruppen in einer ListView auf; mit hoher Testfläche
    // sind alle vier Gruppen sofort vorhanden.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: PlanModeSettings()),
    ));
    await tester.pumpAndSettle();
    return SharedPreferences.getInstance();
  }

  testWidgets('offers a plan mode for classes, persons and both previews',
      (WidgetTester tester) async {
    await pumpSettings(tester);

    expect(find.text('Persons'), findsOneWidget);
    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('Preview of classes'), findsOneWidget);
    expect(find.text('Preview of persons'), findsOneWidget);
  });

  testWidgets('the two preview modes are selected independently',
      (WidgetTester tester) async {
    final prefs = await pumpSettings(tester);

    // In der Klassen-Vorschau "Latest" wählen, die Personen-Vorschau bleibt
    // auf "Auto".
    final Finder classPreviewLatest = find.descendant(
      of: find.ancestor(
        of: find.text('Preview of classes'),
        matching: find.byType(Column),
      ),
      matching: find.widgetWithText(RadioListTile<String>, 'Latest'),
    );
    await tester.tap(classPreviewLatest);
    await tester.pumpAndSettle();

    expect(await PlanModePreferences.readPreviewClass(prefs), 'latest');
    expect(await PlanModePreferences.readPreviewPerson(prefs), 'auto');

    // Und umgekehrt für die Personen-Vorschau.
    final Finder personPreviewToday = find.descendant(
      of: find.ancestor(
        of: find.text('Preview of persons'),
        matching: find.byType(Column),
      ),
      matching: find.widgetWithText(RadioListTile<String>, 'Today'),
    );
    await tester.tap(personPreviewToday);
    await tester.pumpAndSettle();

    expect(await PlanModePreferences.readPreviewClass(prefs), 'latest');
    expect(await PlanModePreferences.readPreviewPerson(prefs), 'today');
  });
}
