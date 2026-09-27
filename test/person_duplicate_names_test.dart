import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
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

  Future<List<String>> storedPersonNames() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<dynamic> persons =
        jsonDecode(prefs.getString('persons') ?? '[]') as List<dynamic>;
    return persons
        .map((dynamic p) => (p as Map<String, dynamic>)['name'].toString())
        .toList();
  }

  /// Legt eine Person an. [typeName] == null bedeutet: Namen leer lassen.
  Future<void> addPerson(
    WidgetTester tester, {
    required String classId,
    String? typeName,
    required List<Map<String, dynamic>> existing,
    required List<String> selectableClasses,
  }) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': selectableClasses,
      'persons': jsonEncode(existing),
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
    await tester.tap(find.text(classId).first);
    await advance(tester);

    if (typeName != null) {
      await tester.enterText(find.byType(TextField), typeName);
    }
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await advance(tester);
    await tester.tap(find.byIcon(Icons.check_rounded));
    await advance(tester);
  }

  testWidgets('a duplicate name in the same class gets " (1)"',
      (WidgetTester tester) async {
    await addPerson(
      tester,
      classId: '5a',
      typeName: 'Anna',
      selectableClasses: <String>['5a'],
      existing: <Map<String, dynamic>>[
        {'id': '1', 'name': 'Anna', 'classId': '5a', 'courses': <String>[]},
      ],
    );

    expect(await storedPersonNames(), <String>['Anna', 'Anna (1)']);
  });

  testWidgets('a third person with that name gets " (2)"',
      (WidgetTester tester) async {
    await addPerson(
      tester,
      classId: '5a',
      typeName: 'Anna',
      selectableClasses: <String>['5a'],
      existing: <Map<String, dynamic>>[
        {'id': '1', 'name': 'Anna', 'classId': '5a', 'courses': <String>[]},
        {'id': '2', 'name': 'Anna (1)', 'classId': '5a', 'courses': <String>[]},
      ],
    );

    expect(
        await storedPersonNames(), <String>['Anna', 'Anna (1)', 'Anna (2)']);
  });

  testWidgets('the same name in a different class needs no suffix',
      (WidgetTester tester) async {
    await addPerson(
      tester,
      classId: '7b',
      typeName: 'Anna',
      selectableClasses: <String>['5a', '7b'],
      existing: <Map<String, dynamic>>[
        {'id': '1', 'name': 'Anna', 'classId': '5a', 'courses': <String>[]},
      ],
    );

    // Gleicher Name, andere Klasse -> kein Suffix.
    expect(await storedPersonNames(), <String>['Anna', 'Anna']);
  });

  testWidgets('the stored suffix uses plain ASCII parentheses',
      (WidgetTester tester) async {
    await addPerson(
      tester,
      classId: '5a',
      typeName: 'Anna',
      selectableClasses: <String>['5a'],
      existing: <Map<String, dynamic>>[
        {'id': '1', 'name': 'Anna', 'classId': '5a', 'courses': <String>[]},
      ],
    );

    final String name = (await storedPersonNames()).last;
    expect(name, 'Anna (1)');
    expect(name.codeUnitAt(5), 0x28, reason: "'(' U+0028");
    expect(name.codeUnitAt(7), 0x29, reason: "')' U+0029");
    expect(name.codeUnits.every((int unit) => unit < 0x80), isTrue,
        reason: 'keine Sonderzeichen im Namen: $name');
  });
}
