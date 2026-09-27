import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/pages/vplan/VPlan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// pumpAndSettle kommt nicht in Frage: Solange Daten geladen werden, dreht
  /// sich ein Ladesymbol endlos und der Baum wird nie "settled".
  Future<void> advance(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpPersons(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': <String>['5a'],
      'persons': jsonEncode(<Map<String, dynamic>>[
        {'id': '1', 'name': 'Anna', 'classId': '5a', 'courses': <String>[]},
        {'id': '2', 'name': 'Ben', 'classId': '5a', 'courses': <String>[]},
      ]),
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: VPlan()),
    ));
    await tester.pumpAndSettle();
  }

  /// Stift-Symbol des Eintrags, dessen Zeile [personName] enthält.
  Finder editIconOf(WidgetTester tester, String personName) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(personName),
        matching: find.byType(ListItem),
      ),
      matching: find.byIcon(Icons.edit_rounded),
    );
  }

  Future<List<String>> storedPersonNames() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<dynamic> persons =
        jsonDecode(prefs.getString('persons') ?? '[]') as List<dynamic>;
    return persons
        .map((dynamic p) => (p as Map<String, dynamic>)['name'].toString())
        .toList();
  }

  testWidgets('a person can be renamed afterwards',
      (WidgetTester tester) async {
    await pumpPersons(tester);

    // Personen haben – wie Klassen – ein Stift-Symbol zum Umbenennen.
    expect(editIconOf(tester, 'Anna'), findsOneWidget);

    await tester.tap(editIconOf(tester, 'Anna'));
    await advance(tester);

    // Der Dialog ist mit dem aktuellen Namen vorbelegt.
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Anna');

    await tester.enterText(find.byType(TextField), 'Anna Schmidt');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await advance(tester);

    expect(await storedPersonNames(), <String>['Anna Schmidt', 'Ben']);
    expect(find.text('Anna Schmidt'), findsOneWidget);
  });

  testWidgets('renaming to an existing name keeps the name (no suffix)',
      (WidgetTester tester) async {
    await pumpPersons(tester);

    // "Ben" in "Anna" umbenennen: Doppelnamen sind erlaubt, es wird kein
    // Suffix vergeben.
    await tester.tap(editIconOf(tester, 'Ben'));
    await advance(tester);
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await advance(tester);

    expect(await storedPersonNames(), <String>['Anna', 'Anna']);
  });

  testWidgets('renaming a person to its own name keeps the name',
      (WidgetTester tester) async {
    await pumpPersons(tester);

    // Unverändert speichern darf nicht zu "Anna (1)" führen.
    await tester.tap(editIconOf(tester, 'Anna'));
    await advance(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await advance(tester);

    expect(await storedPersonNames(), <String>['Anna', 'Ben']);
  });
}
