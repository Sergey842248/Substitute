import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/Plan.dart';
import 'package:substitute/services/AppClock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPlan(WidgetTester tester, String planMode) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': ['5a'],
      'defaultPlanModeClass': planMode,
    });
    // Wednesday, after the last lesson (13:25) -> the school day is over.
    await AppClock.setOverriddenNow(DateTime(2026, 9, 23, 23, 0));

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Plan(classId: '5a')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('plan mode "today" keeps showing today after the school day',
      (WidgetTester tester) async {
    await pumpPlan(tester, 'today');

    expect(find.textContaining('23.09.2026'), findsWidgets);
    expect(find.textContaining('24.09.2026'), findsNothing);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('plan mode "auto" switches to the next day when the day is over',
      (WidgetTester tester) async {
    await pumpPlan(tester, 'auto');

    expect(find.textContaining('24.09.2026'), findsWidgets);

    await AppClock.setOverriddenNow(null);
  });
}
