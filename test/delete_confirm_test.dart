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

  Future<void> pumpVPlan(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': <String>['5a', '6b'],
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

  /// Papierkorb-Symbol des Personen-Eintrags mit dem Namen [personName].
  Finder personDeleteIcon(String personName) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(personName),
        matching: find.byType(ListItem),
      ),
      matching: find.byIcon(Icons.delete_rounded),
    );
  }

  /// Papierkorb-Symbol des Klassen-Eintrags an Stelle [index]. Der Index wird
  /// verwendet, weil die Kurs-ID auch in den Personen-Einträgen auftaucht und
  /// ein Text-Finder daher nicht eindeutig wäre.
  Finder classDeleteIcon(int index) {
    return find.descendant(
      of: find.byType(ClassWidget).at(index),
      matching: find.byIcon(Icons.delete_rounded),
    );
  }

  Future<List<String>> storedClasses() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('classes') ?? <String>[];
  }

  Future<List<String>> storedPersonNames() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<dynamic> persons =
        jsonDecode(prefs.getString('persons') ?? '[]') as List<dynamic>;
    return persons
        .map((dynamic p) => (p as Map<String, dynamic>)['name'].toString())
        .toList();
  }

  group('deleting a person asks for confirmation', () {
    testWidgets('cancel keeps the person', (WidgetTester tester) async {
      await pumpVPlan(tester);

      await tester.tap(personDeleteIcon('Anna'));
      await advance(tester);

      // Der Dialog nennt die Person beim Namen.
      expect(find.text('Delete person?'), findsOneWidget);
      expect(find.textContaining('Anna'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await advance(tester);

      expect(find.text('Delete person?'), findsNothing);
      expect(await storedPersonNames(), <String>['Anna', 'Ben']);
      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets('confirm deletes the person', (WidgetTester tester) async {
      await pumpVPlan(tester);

      await tester.tap(personDeleteIcon('Anna'));
      await advance(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await advance(tester);

      expect(find.text('Delete person?'), findsNothing);
      expect(await storedPersonNames(), <String>['Ben']);
      expect(find.text('Anna'), findsNothing);
    });
  });

  group('deleting a class asks for confirmation', () {
    testWidgets('cancel keeps the class', (WidgetTester tester) async {
      await pumpVPlan(tester);

      await tester.tap(classDeleteIcon(0));
      await advance(tester);

      expect(find.text('Delete class?'), findsOneWidget);
      expect(find.textContaining('5a'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await advance(tester);

      expect(find.text('Delete class?'), findsNothing);
      expect(await storedClasses(), <String>['5a', '6b']);
    });

    testWidgets('confirm deletes the class', (WidgetTester tester) async {
      await pumpVPlan(tester);

      await tester.tap(classDeleteIcon(0));
      await advance(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await advance(tester);

      expect(find.text('Delete class?'), findsNothing);
      expect(await storedClasses(), <String>['6b']);
    });
  });
}
