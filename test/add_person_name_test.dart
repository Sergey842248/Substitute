import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/VPlan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// pumpAndSettle kommt hier nicht in Frage: Solange Daten geladen werden,
  /// dreht sich ein Ladesymbol endlos und der Baum wird nie "settled".
  Future<void> advance(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Legt eine Person ohne Namenseingabe an und speichert sie am Ende.
  Future<void> addPersonWithoutName(
    WidgetTester tester, {
    required List<Map<String, dynamic>> existingPersons,
    required String classId,
    Map<String, dynamic>? classNames,
  }) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': <String>[classId],
      'persons': jsonEncode(existingPersons),
      if (classNames != null) 'classNames': jsonEncode(classNames),
    });

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: VPlan()),
    ));
    await tester.pumpAndSettle();

    // "+" neben "Persons" -> Klassenauswahl -> Klasse wählen.
    await tester.tap(find.byIcon(Icons.person_add_alt_1_rounded).first);
    await advance(tester);
    await tester.tap(find.text(classId).first);
    await advance(tester);

    // Namensdialog ohne Eingabe speichern.
    expect(find.byType(TextField), findsOneWidget,
        reason: 'der Namensdialog muss geöffnet sein');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await advance(tester);

    // Kurse wählen und die Person fertig anlegen.
    await tester.tap(find.byIcon(Icons.check_rounded));
    await advance(tester);
  }

  /// Namen aller gespeicherten Personen – die Anzeige im Widget-Baum ist
  /// mehrdeutig (Titel + Klassen-Untertitel), die Speicherung nicht.
  Future<List<String>> storedPersonNames() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<dynamic> persons =
        jsonDecode(prefs.getString('persons') ?? '[]') as List<dynamic>;
    return persons
        .map((dynamic p) => (p as Map<String, dynamic>)['name'].toString())
        .toList();
  }

  testWidgets('an empty name falls back to the class name',
      (WidgetTester tester) async {
    await addPersonWithoutName(tester,
        existingPersons: <Map<String, dynamic>>[], classId: '5a');

    // Die neue Person wurde unter dem Namen der Klasse gespeichert.
    expect(await storedPersonNames(), <String>['5a']);
  });

  testWidgets('a duplicate class name gets " (1)" appended',
      (WidgetTester tester) async {
    await addPersonWithoutName(
      tester,
      existingPersons: <Map<String, dynamic>>[
        {'id': '1', 'name': '5a', 'classId': '5a', 'courses': <String>[]},
      ],
      classId: '5a',
    );

    expect(await storedPersonNames(), <String>['5a', '5a (1)']);
  });

  testWidgets('a second duplicate gets " (2)" appended',
      (WidgetTester tester) async {
    await addPersonWithoutName(
      tester,
      existingPersons: <Map<String, dynamic>>[
        {'id': '1', 'name': '5a', 'classId': '5a', 'courses': <String>[]},
        {'id': '2', 'name': '5a (1)', 'classId': '5a', 'courses': <String>[]},
      ],
      classId: '5a',
    );

    expect(
        await storedPersonNames(), <String>['5a', '5a (1)', '5a (2)']);
  });

  testWidgets('the custom class name is used as fallback',
      (WidgetTester tester) async {
    await addPersonWithoutName(
      tester,
      existingPersons: <Map<String, dynamic>>[],
      classId: '5a',
      classNames: <String, dynamic>{'5a': 'Klasse 5a'},
    );

    expect(await storedPersonNames(), <String>['Klasse 5a']);
  });

  testWidgets('an explicitly typed name is kept as typed',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': <String>['5a'],
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: VPlan()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_alt_1_rounded).first);
    await advance(tester);
    await tester.tap(find.text('5a').first);
    await advance(tester);
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await advance(tester);
    await tester.tap(find.byIcon(Icons.check_rounded));
    await advance(tester);

    expect(await storedPersonNames(), <String>['Anna']);
  });
}
