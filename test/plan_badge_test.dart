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

  /// Liest die Zahl aus der Badge (oder null, wenn keine Badge angezeigt wird).
  String? badgeText(WidgetTester tester) {
    final Finder badge =
        find.byKey(const ValueKey<String>('newerPlanBadge'));
    if (badge.evaluate().isEmpty) return null;
    return tester
        .widget<Text>(
          find.descendant(of: badge, matching: find.byType(Text)).first,
        )
        .data;
  }

  testWidgets('badge counts down when navigating forward to a future plan',
      (WidgetTester tester) async {
    // Heute ist Mittwoch, 23.09.2026 – die beiden lokal verfügbaren Pläne
    // liegen in der Zukunft.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': ['5a'],
      'offlineVPData': [
        jsonEncode(offlinePlan(DateTime(2026, 9, 24))),
        jsonEncode(offlinePlan(DateTime(2026, 9, 25))),
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

    expect(badgeText(tester), '2');

    // Einen Tag vor: ein neuerer Plan ist verbraucht, einer bleibt übrig.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(badgeText(tester), '1',
        reason: 'badge must count down instead of disappearing');

    // Noch ein Tag vor: kein neuerer Plan mehr.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(badgeText(tester), isNull);

    // Und zurück: die Badge steigt wieder.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(badgeText(tester), '1');

    await AppClock.setOverriddenNow(null);
  });
}
