import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expandiware/pages/dashboard/SickTrack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('SickTrack renders empty state with title', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SickTrack()),
    ));
    // One frame to mount; second to let async _load settle
    await tester.pump();
    await tester.pump();

    expect(find.text('Sick-Track'), findsOneWidget);
    expect(find.text('No sick periods yet. Add one to see which lessons you missed.'), findsOneWidget);
    // "Add" button should be visible (FAB in actions)
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('SickTrackEditor renders course and days sections when no class selected', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SickTrackEditor()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Add sick period'), findsOneWidget);
    expect(find.text('Select courses'), findsOneWidget);
    expect(find.text('Select sick days'), findsOneWidget);
  });
}
