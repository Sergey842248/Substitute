import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expandiware/pages/dashboard/SickTrack.dart';
import 'package:expandiware/pages/vplan/VPlanAPI.dart';

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

  testWidgets('SickTrack shows checkmark for done signatures and cross for open ones', (WidgetTester tester) async {
    // Fake plan matching the Indiware xml2json Parker format for class 10A.
    final String fakePlanJson = jsonEncode({
      'date': 'Freitag, 15. August 2026',
      'week': 'A',
      'data': {
        'Kopf': {'DatumPlan': 'Freitag, 15. August 2026'},
        'Klassen': {
          'Kl': [
            {
              'Kurz': '10A',
              'Pl': {
                'Std': [
                  {
                    'St': '1',
                    'Fa': 'M',
                    'Le': 'AB',
                    'Ra': '101',
                    'Beginn': '07:45',
                    'Ende': '08:30',
                    'Ku2': 'M-1',
                  },
                  {
                    'St': '2',
                    'Fa': 'E',
                    'Le': 'CD',
                    'Ra': '102',
                    'Beginn': '08:35',
                    'Ende': '09:20',
                    'Ku2': 'E-2',
                  },
                ]
              }
            }
          ]
        }
      },
      'info': [],
      'courses': [],
      'roomChanges': {},
    });
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'pass',
      'offlineVPData': [fakePlanJson],
    });
    await VPlanAPI().addSickTrackEntry({
      'id': '1',
      'classId': '10A',
      'courses': ['M-1', 'E-2'],
      'days': ['2026-08-15'],
      'signaturesDone': ['M-1'],
    });

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SickTrack()),
    ));
    // Let the async loads (entries + missed lessons) settle.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // M-1 is done → checkmark; E-2 is still open → cross.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.text('15.08.2026 · 1. hour · M-1'), findsOneWidget);
    expect(find.text('15.08.2026 · 2. hour · E-2'), findsOneWidget);
  });
}
