import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/pages/dashboard/SickTrack.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// pumpAndSettle kommt nicht in Frage: Solange die verpassten Stunden geladen
  /// werden, dreht sich ein Ladesymbol endlos und der Baum wird nie "settled".
  Future<void> advance(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpSickTrack(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await VPlanAPI().saveSickTrackEntries(<Map<String, dynamic>>[
      {'id': 'a', 'classId': '10A', 'courses': <String>['M-1'], 'days': <String>[]},
      {'id': 'b', 'classId': '7B', 'courses': <String>['E-2'], 'days': <String>[]},
    ]);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SickTrack()),
    ));
    await advance(tester);
  }

  /// Papierkorb-Symbol des Eintrags der Klasse [classId].
  Finder deleteIconOfClass(WidgetTester tester, String classId) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(classId),
        matching: find.byType(ListItem),
      ),
      matching: find.byIcon(Icons.delete_rounded),
    );
  }

  Future<List<String>> storedClassIds() async {
    final entries = await VPlanAPI().getSickTrackEntries();
    return entries.map((e) => e['classId'].toString()).toList();
  }

  testWidgets('deleting a sick track entry asks for confirmation',
      (WidgetTester tester) async {
    await pumpSickTrack(tester);

    await tester.tap(deleteIconOfClass(tester, '10A'));
    await advance(tester);

    expect(find.text('Delete entry?'), findsOneWidget);
    expect(find.textContaining('10A'), findsWidgets);

    // Abbrechen: Der Eintrag bleibt erhalten.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await advance(tester);

    expect(find.text('Delete entry?'), findsNothing);
    expect(await storedClassIds(), <String>['10A', '7B']);
  });

  testWidgets('confirming deletes the sick track entry',
      (WidgetTester tester) async {
    await pumpSickTrack(tester);

    await tester.tap(deleteIconOfClass(tester, '10A'));
    await advance(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await advance(tester);

    expect(find.text('Delete entry?'), findsNothing);
    expect(await storedClassIds(), <String>['7B']);
  });
}
