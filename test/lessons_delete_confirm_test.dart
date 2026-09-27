import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/pages/dashboard/settings/Lessons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> advance(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpLessons(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'lessontimes': jsonEncode(<Map<String, dynamic>>[
        {'count': 1, 'start': '08:00', 'end': '08:45'},
        {'count': 2, 'start': '08:50', 'end': '09:35'},
        {'count': 3, 'start': '09:40', 'end': '10:25'},
      ]),
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Lessons()),
    ));
    await advance(tester);
  }

  /// Papierkorb-Symbol des Eintrags, dessen Zeile mit [count] nummeriert ist.
  Finder deleteIconOfCount(WidgetTester tester, int count) {
    return find.descendant(
      of: find.ancestor(
        of: find.text('$count. Lesson'),
        matching: find.byType(ListItem),
      ),
      matching: find.byIcon(Icons.delete),
    );
  }

  List<String> shownCounts(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.textContaining('. Lesson'))
        .map((Text t) => t.data!)
        .toList();
  }

  testWidgets('deleting a lesson time asks for confirmation',
      (WidgetTester tester) async {
    await pumpLessons(tester);

    expect(shownCounts(tester), <String>[
      '1. Lesson',
      '2. Lesson',
      '3. Lesson',
    ]);

    await tester.tap(deleteIconOfCount(tester, 2));
    await advance(tester);

    expect(find.text('Delete lesson time?'), findsOneWidget);
    expect(find.textContaining('2. lesson time'), findsOneWidget);

    // Abbrechen: Es bleibt alles unverändert.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await advance(tester);

    expect(find.text('Delete lesson time?'), findsNothing);
    expect(shownCounts(tester), <String>[
      '1. Lesson',
      '2. Lesson',
      '3. Lesson',
    ]);
  });

  testWidgets('confirming deletes the lesson time and renumbers',
      (WidgetTester tester) async {
    await pumpLessons(tester);

    await tester.tap(deleteIconOfCount(tester, 2));
    await advance(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await advance(tester);

    expect(find.text('Delete lesson time?'), findsNothing);
    // Die Nummerierung wird danach neu vergeben.
    expect(shownCounts(tester), <String>[
      '1. Lesson',
      '2. Lesson',
    ]);
  });
}
