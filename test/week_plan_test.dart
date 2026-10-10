import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/SettingsSwitchTile.dart';
import 'package:substitute/pages/dashboard/settings/PlanSettings.dart';
import 'package:substitute/pages/vplan/DemoData.dart';
import 'package:substitute/pages/vplan/WeekPlan.dart';
import 'package:substitute/pages/vplan/WeekPlanGrid.dart';
import 'package:substitute/services/AppClock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mittwoch, 23.09.2026 – die Schulwoche läuft also vom 21.09. (Mo) bis
  /// zum 26.09. (Sa).
  final DateTime wednesday = DateTime(2026, 9, 23, 8, 0);

  /// Legt für jeden Schultag (Mo–Fr) einen Offline-Plan ab, damit die
  /// Wochenansicht ohne Netzwerk auskommt.
  ///
  /// Der Samstag bleibt bewusst leer: Der Demo-Account liefert für Wochenenden
  /// grundsätzlich einen leeren Plan – er ist also kein Schul- bzw.
  /// Unterrichtstag.
  void seedOfflineWeek() {
    final List<String> entries = [];
    for (int i = 0; i < 5; i++) {
      final DateTime day = DateTime(2026, 9, 21).add(Duration(days: i));
      entries.add(jsonEncode(DemoData.buildDayPlan(day)));
    }
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': ['5a'],
      'offlineVPData': entries,
    });
  }

  Future<void> pumpWeekPlan(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    await AppClock.setOverriddenNow(wednesday);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: WeekPlan(classId: '5a')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('week view shows start and end date of the displayed week',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    expect(find.textContaining('21.09.2026'), findsWidgets);
    expect(find.textContaining('26.09.2026'), findsWidgets);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('week view shows the week type from the server plan',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    expect(find.textContaining('Week:'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the days stand next to each other, not below one another',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    // Die Positionen der Spaltenüberschriften: Sie müssen auf **einer** Höhe
    // liegen (gleiches y) und unterschiedliche x haben – nebeneinander, nicht
    // untereinander.
    final Map<String, Offset> headers = <String, Offset>{};
    for (final String weekday in <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      headers[weekday] = tester.getCenter(find.text(weekday));
    }

    expect(headers.keys, hasLength(5));
    final Set<double> rows = headers.values.map((Offset o) => o.dy).toSet();
    expect(rows, hasLength(1), reason: 'all day headers must share one row');

    final List<double> xs = headers.values.map((Offset o) => o.dx).toList();
    expect(xs.toSet(), hasLength(5), reason: 'each day needs its own column');
    // Von links nach rechts sortiert, damit "nebeneinander" auch die Reihenfolge
    // der Wochentage meint.
    for (int i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]),
          reason: 'days must run from left to right');
    }

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the whole week fits on the screen without scrolling',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester, size: const Size(400, 800));

    // Nichts darf außerhalb des Bildschirms liegen – insbesondere nicht die
    // letzte Stundenzeile, die bei einem Scroll-Grid abgeschnitten wäre.
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect grid = tester.getRect(find.byType(WeekPlanGrid));
    expect(grid.bottom, lessThanOrEqualTo(screen.height),
        reason: 'the grid must not overflow the screen');

    // Der Inhalt steht in einer Column, nicht in einer scrollbaren Liste.
    // (Die [ListView] der Kopfzeile von [ListPage] ist davon unberührt – sie
    // ist ohnehin nicht scrollbar.)
    expect(
      find.descendant(
        of: find.byType(WeekPlanGrid),
        matching: find.byType(ListView),
      ),
      findsNothing,
    );

    // Und auf der Seite ist **nirgends** etwas vertikal scrollbar. Die
    // Scrollables, die es gibt (Kopfzeile, Aktionsleiste), sind mit
    // `NeverScrollableScrollPhysics` ausdrücklich darauf festgelegt.
    for (final Scrollable scrollable
        in tester.widgetList<Scrollable>(find.byType(Scrollable))) {
      if (scrollable.axisDirection != AxisDirection.down) continue;
      expect(
        scrollable.physics,
        const NeverScrollableScrollPhysics(),
        reason: 'no vertical scrolling on the week view',
      );
    }

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('lessons of all days are visible at the same time',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    // Jeder Tag hat 6 Stunden. Ohne Scrollen müssen also 5 × 6 Zellen
    // gleichzeitig im Baum sein.
    expect(find.byType(InkWell), findsWidgets);
    // Die erste Stunde des Montags und die letzte des Freitags beide sichtbar.
    expect(find.text('1'), findsNWidgets(5));
    expect(find.text('6'), findsNWidgets(5));

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('a small screen with many lessons still fits without overflow',
      (WidgetTester tester) async {
    // Viele Stunden auf einem kleinen Bildschirm ist der Fall, in dem ein
    // Grid überläuft: Die Zellen werden sehr flach. Genau dafür gibt es das
    // Herunterskalieren im Grid – dieser Test wacht darüber, dass es wirkt.
    final Map<String, dynamic> bigPlan = DemoData.buildDayPlan(DateTime(2026, 9, 21));
    final List<dynamic> kl =
        bigPlan['data']['Klassen']['Kl'] as List<dynamic>;
    final Map<String, dynamic> kl0 = Map<String, dynamic>.from(kl.first as Map);
    final Map<String, dynamic> pl =
        Map<String, dynamic>.from(kl0['Pl'] as Map);
    // Aus jeder Stunde werden fünf, damit es deutlich zu viele werden.
    final List<dynamic> std = List<dynamic>.from(pl['Std'] as List<dynamic>);
    final List<dynamic> many = <dynamic>[];
    for (int i = 0; i < std.length; i++) {
      for (int j = 0; j < 5; j++) {
        final Map<String, dynamic> lesson = Map<String, dynamic>.from(std[i] as Map);
        lesson['St'] = '${i * 5 + j + 1}';
        many.add(lesson);
      }
    }
    pl['Std'] = many;
    kl0['Pl'] = pl;
    kl[0] = kl0;
    bigPlan['data']['Klassen']['Kl'] = kl;

    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': ['5a'],
      'offlineVPData': <String>[
        for (int i = 0; i < 5; i++)
          jsonEncode(i == 0 ? bigPlan : DemoData.buildDayPlan(DateTime(2026, 9, 21).add(Duration(days: i)))),
      ],
    });

    await pumpWeekPlan(tester, size: const Size(360, 640));

    // 30 Stundenzeilen auf 640 Pixel Höhe: Ohne Skalierung wäre die unterste
    // Zeile abgeschnitten. `tester.takeException` fängt genau das ab, was ein
    // RenderFlex-Überlauf meldet.
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(WeekPlanGrid)).bottom,
      lessThanOrEqualTo(640.0),
    );

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the week view is off by default and can be switched on',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PlanSettings()),
    ));
    await tester.pumpAndSettle();

    final Finder tile = find.ancestor(
      of: find.text('Show whole week'),
      matching: find.byType(SettingsSwitchTile),
    );
    expect(tile, findsOneWidget);
    expect(tester.widget<SettingsSwitchTile>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SettingsSwitchTile>(tile).value, isTrue);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('showWeekView'), isTrue);
  });

  testWidgets('week view can navigate to the previous and next week',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.textContaining('28.09.2026'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.textContaining('14.09.2026'), findsWidgets);

    await AppClock.setOverriddenNow(null);
  });
}