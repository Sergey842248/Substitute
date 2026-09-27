import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/Plan.dart';
import 'package:substitute/pages/vplan/DemoData.dart';
import 'package:substitute/services/AppClock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> offlinePlan(DateTime date) {
    final String dateStr = DemoData.germanDate(date);
    return {
      'date': dateStr,
      'data': {
        'Kopf': {'DatumPlan': dateStr},
      },
    };
  }

  testWidgets('newer-plans badge shows the number of available newer plans',
      (WidgetTester tester) async {
    final List<DateTime> newer = [
      DateTime(2026, 9, 24),
      DateTime(2026, 9, 25),
      DateTime(2026, 9, 28),
    ];
    final DateTime older = DateTime(2026, 9, 22);

    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': ['5a'],
      'offlineVPData': [
        jsonEncode(offlinePlan(older)),
        for (final DateTime d in newer) jsonEncode(offlinePlan(d)),
      ],
    });
    await AppClock.setOverriddenNow(DateTime(2026, 9, 23, 8, 0));

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Plan(classId: '5a')),
    ));
    await tester.pumpAndSettle();

    final Finder badge = find.byKey(const ValueKey<String>('newerPlanBadge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('${newer.length}')),
      findsOneWidget,
      reason: 'badge must show the count of newer plans, not always "1"',
    );

    await AppClock.setOverriddenNow(null);
  });
}
