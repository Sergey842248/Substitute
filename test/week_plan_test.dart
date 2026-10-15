import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/LoadingIndicator.dart';
import 'package:substitute/models/SettingsSwitchTile.dart';
import 'package:substitute/pages/dashboard/settings/AppearanceSettings.dart';
import 'package:substitute/pages/dashboard/settings/LessonInfoSettings.dart';
import 'package:substitute/pages/dashboard/settings/PlanSettings.dart';
import 'package:substitute/pages/vplan/DemoData.dart';
import 'package:substitute/pages/vplan/Plan.dart';
import 'package:substitute/pages/vplan/WeekPlan.dart';
import 'package:substitute/pages/vplan/WeekPlanGrid.dart';
import 'package:substitute/services/PlanWeek.dart';
import 'package:substitute/services/AppClock.dart';
import 'package:substitute/services/NativeShell.dart';

/// Die vier Textangaben, die eine Rasterzelle zeigt – als Widgets, nicht als
/// Zeichenketten: Raum und Lehrer wiederholen sich in der Woche, `find.text`
/// wäre damit mehrdeutig.
typedef _CellTexts = ({
  Text subject,
  Text room,
  Text teacher,
  Text time,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mittwoch, 23.09.2026 – die Schulwoche läuft also vom 21.09. (Mo) bis
  /// zum 26.09. (Sa).
  final DateTime wednesday = DateTime(2026, 9, 23, 8, 0);

  /// Ein Montagsplan mit genau [lessons] Stunden – für Tests, die es um die
  /// Zeilenzahl des Rasters gehen.
  Map<String, dynamic> _planWithLessons(int lessons) {
    final Map<String, dynamic> plan =
        DemoData.buildDayPlan(DateTime(2026, 9, 21));
    final List<dynamic> kl = plan['data']['Klassen']['Kl'] as List<dynamic>;
    final Map<String, dynamic> kl0 = Map<String, dynamic>.from(kl.first as Map);
    final Map<String, dynamic> pl = Map<String, dynamic>.from(kl0['Pl'] as Map);
    final List<dynamic> std = List<dynamic>.from(pl['Std'] as List<dynamic>);
    final List<dynamic> many = List<dynamic>.from(std);
    while (many.length < lessons) {
      // Jede Stunde bekommt eine eigene Nummer, sonst hätte das Raster
      // weniger Zeilen als gewünschte Einträge.
      final Map<String, dynamic> copy =
          Map<String, dynamic>.from(std.first as Map);
      copy['St'] = '${many.length + 1}';
      many.add(copy);
    }
    pl['Std'] = many;
    kl0['Pl'] = pl;
    kl[0] = kl0;
    plan['data']['Klassen']['Kl'] = kl;
    return plan;
  }

  /// Die Offline-Pläne der Schulwoche (Mo–Fr), fertig als JSON-Strings.
  List<String> _offlineWeek() => <String>[
        for (int i = 0; i < 5; i++)
          jsonEncode(DemoData.buildDayPlan(
              DateTime(2026, 9, 21).add(Duration(days: i)))),
      ];

  /// Wie [seedOfflineWeek], aber mit sichtbaren Zeiten und Lehrern – dann
  /// stehen alle vier Angaben in der Zelle.
  void seedOfflineWeekWithTimesAndTeacher() {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'hideLessonTimes': false,
      'hideTeacher': false,
      'offlineVPData': _offlineWeek(),
    });
  }

  /// Legt für jeden Schultag (Mo–Fr) einen Offline-Plan ab, damit die
  /// Wochenansicht ohne Netzwerk auskommt.
  ///
  /// Der Samstag bleibt bewusst leer: Der Demo-Account liefert für Wochenenden
  /// grundsätzlich einen leeren Plan – er ist also kein Schul- bzw.
  /// Unterrichtstag.
  ///
  /// **Bewusst keine Demo-Zugangsdaten** (`123456`/`user`/`password`): Im
  /// Demo-Modus erzeugt die API die Pläne frisch aus [DemoData] und lässt die
  /// hier abgelegten Daten komplett ignorieren. Tests, die einen Plan
  /// verändern (z.B. zwei Kurse in derselben Stunde), kämen dort nie an.
  void seedOfflineWeek() {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': _offlineWeek(),
    });
  }

  /// Die vier Textangaben der ersten Rasterzelle.
  ///
  /// Sie werden über die Struktur gesucht, nicht über feste Zeichenketten: Der
  /// Demo-Plan erzeugt die Inhalte zufällig, und der Test soll an der
  /// Typografie hängen, nicht an einem konkreten Demo-Fach.
  _CellTexts _firstCellTexts(
    WidgetTester tester,
  ) {
    // Nur die **erste Zelle mit einer Stunde**. Über den Schlüssel, nicht über
    // "die erste InkWell": Der Tageskopf ist auch eine InkWell und steht im
    // Baum weiter vorn.
    final Finder cell = find
        .descendant(
          of: find.byType(WeekPlanGrid),
          matching: find.byKey(
            const ValueKey<String>('lessonCell_2026-9-21_1'),
          ),
        )
        .first;

    // Der Zellenaufbau ist fest: Stundennummer, Fach, Raum, Lehrer, Zeit.
    //
    // Am Anfang stehen die reinen Ziffern (Stundennummer, ggf. die Anzahl der
    // Unterschriften) – die werden übersprungen. **Nur am Anfang**: Ein Raum
    // kann ebenfalls eine reine Zahl sein ("201"), und würde sonst mit
    // verschwinden.
    final List<Text> values = tester
        .widgetList<Text>(
          find.descendant(of: cell, matching: find.byType(Text)),
        )
        .toList();
    final int firstValue = values.indexWhere(
      (Text t) => !RegExp(r'^\d+$').hasMatch((t.data ?? '').trim()),
    );
    final List<Text> texts =
        firstValue < 0 ? <Text>[] : values.sublist(firstValue);

    return (
      subject: texts[0],
      room: texts[1],
      teacher: texts[2],
      time: texts[3],
    );
  }

  double _fontSizeOf(Text text) => text.style!.fontSize!;

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

  testWidgets('week view shows start and end date without the year',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    // „21.09. - 26.09." – ohne Jahreszahl, die Woche steht ohnehin im Kopf.
    expect(find.text('21.09. - 25.09.'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('a week across the new year keeps the year in the dates',
      (WidgetTester tester) async {
    // 28.12.2026 – 02.01.2027: Hier wäre „28.12. - 02.01." mehrdeutig.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
    });
    await AppClock.setOverriddenNow(DateTime(2026, 12, 30, 8));
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: WeekPlan(classId: '5a')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('28.12.2026 - 01.01.2027'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('week view shows the week type from the server plan',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    // Der Typ steht als eigener Text in der Zeile über dem Raster.
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

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

  testWidgets(
      'the whole week fits on the screen, and the last hour can be '
      'lifted clear of the tab bar', (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester, size: const Size(400, 800));

    // **Erstens: nichts ragt über den Bildschirm hinaus.** Das war und bleibt der
    // eigentliche Zweck des Rasters: Die ganze Woche steht auf einen Blick, ohne
    // dass eine Stundenzeile abgeschnitten wäre.
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect grid = tester.getRect(find.byType(WeekPlanGrid));
    expect(grid.bottom, lessThanOrEqualTo(screen.height),
        reason: 'the grid must not overflow the screen');

    // **Zweitens: die Stundenzeilen sind scrollbar.** Früher stand hier
    // `findsNothing`, weil die Woche gar nicht scrollte und die native
    // Navigationsleiste deshalb über der untersten Stunde lag. Scrollt sie
    // nicht, gibt es nichts, was man unter der Leiste hervorholen könnte – und
    // die letzte Stunde ist nur durch einen **festen** Rand unter dem Raster zu
    // retten, der immer sichtbar ist und wie eine Schicht zwischen Inhalt und
    // Leiste aussieht.
    //
    // Der Platz gehört deshalb ans Ende der Scrollstrecke: Erst ganz unten
    // erscheint er, beim Scrollen bleibt das Raster hinter der Leiste sichtbar.
    expect(
      find.descendant(
        of: find.byType(WeekPlanGrid),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
      reason:
          'die Stundenzeilen müssen scrollbar sein, damit die letzte Stunde '
          'unter der Navigationsleiste hervorzuholen ist',
    );

    // Und der Platz ist am Ende, nicht rundherum.
    expect(find.byType(NativeShellScrollEndInset), findsOneWidget,
        reason: 'der Platz für die Leiste gehört ans Ende der Scrollstrecke');

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
    final Map<String, dynamic> bigPlan =
        DemoData.buildDayPlan(DateTime(2026, 9, 21));
    final List<dynamic> kl = bigPlan['data']['Klassen']['Kl'] as List<dynamic>;
    final Map<String, dynamic> kl0 = Map<String, dynamic>.from(kl.first as Map);
    final Map<String, dynamic> pl = Map<String, dynamic>.from(kl0['Pl'] as Map);
    // Aus jeder Stunde werden fünf, damit es deutlich zu viele werden.
    final List<dynamic> std = List<dynamic>.from(pl['Std'] as List<dynamic>);
    final List<dynamic> many = <dynamic>[];
    for (int i = 0; i < std.length; i++) {
      for (int j = 0; j < 5; j++) {
        final Map<String, dynamic> lesson =
            Map<String, dynamic>.from(std[i] as Map);
        lesson['St'] = '${i * 5 + j + 1}';
        many.add(lesson);
      }
    }
    pl['Std'] = many;
    kl0['Pl'] = pl;
    kl[0] = kl0;
    bigPlan['data']['Klassen']['Kl'] = kl;

    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        for (int i = 0; i < 5; i++)
          jsonEncode(i == 0
              ? bigPlan
              : DemoData.buildDayPlan(
                  DateTime(2026, 9, 21).add(Duration(days: i)))),
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

  testWidgets('the cell shows subject > room > teacher > time, biggest first',
      (WidgetTester tester) async {
    seedOfflineWeekWithTimesAndTeacher();
    await pumpWeekPlan(tester);

    final _CellTexts texts = _firstCellTexts(tester);
    final double subject = _fontSizeOf(texts.subject);
    final double room = _fontSizeOf(texts.room);
    final double teacher = _fontSizeOf(texts.teacher);
    final double time = _fontSizeOf(texts.time);

    expect(subject, greaterThan(room), reason: 'subject must beat room');
    expect(room, greaterThan(teacher), reason: 'room must beat teacher');
    expect(teacher, greaterThan(time), reason: 'teacher must beat time');

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('tapping a lesson shows its additional information',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    // Die erste Stundenzelle (nicht die leeren Rasterzellen, nicht der
    // Tageskopf – beides wäre eine InkWell).
    final Finder cell = find
        .descendant(
          of: find.byType(WeekPlanGrid),
          matching: find.byKey(
            const ValueKey<String>('lessonCell_2026-9-21_1'),
          ),
        )
        .first;
    await tester.tap(cell);
    await tester.pumpAndSettle();

    // Der Dialog nennt Tag und Fach und listet die Einzelangaben auf.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('21.09.2026'), findsWidgets);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the cell text and the week header are centred',
      (WidgetTester tester) async {
    seedOfflineWeekWithTimesAndTeacher();
    await pumpWeekPlan(tester);

    // Punkt 1: Der Text in der Zelle sitzt mittig.
    final _CellTexts texts = _firstCellTexts(tester);
    for (final Text text in <Text>[
      texts.subject,
      texts.room,
      texts.teacher,
      texts.time,
    ]) {
      expect(text.textAlign, TextAlign.center);
    }

    // Punkt 2: Datumsrange und Wochentyp stehen als **Zeile** mittig.
    // Geprüft wird die Zeile, nicht der einzeln Text: Der Zeitraum steht links
    // neben dem Wochentyp, beide zusammen sind zentriert.
    expect(find.text('21.09. - 25.09.'), findsOneWidget);
    final Offset centre = tester.getCenter(find.byType(WeekPlanGrid));
    final Finder headerRow = find
        .ancestor(
          of: find.byIcon(Icons.date_range_rounded),
          matching: find.byType(Row),
        )
        .first;
    expect(tester.getRect(headerRow).center.dx, closeTo(centre.dx, 1));

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('tapping a day shows the additional information of that day',
      (WidgetTester tester) async {
    // Der Montag bekommt eine eigene Zusatzinfo, der Dienstag eine andere.
    final Map<String, dynamic> monday =
        DemoData.buildDayPlan(DateTime(2026, 9, 21));
    monday['info'] = <String>[
      'Morgen Sport in der Halle',
      'Bitte Turnsachen mitbringen'
    ];
    final Map<String, dynamic> tuesday =
        DemoData.buildDayPlan(DateTime(2026, 9, 22));
    tuesday['info'] = <String>['Nur bis zur vierten Stunde'];

    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(monday),
        jsonEncode(tuesday),
        for (int i = 2; i < 5; i++)
          jsonEncode(DemoData.buildDayPlan(
              DateTime(2026, 9, 21).add(Duration(days: i)))),
      ],
    });
    await pumpWeekPlan(tester);

    // Der Tageskopf öffnet die Informationen – erst mal nichts sichtbar.
    expect(find.text('Morgen Sport in der Halle'), findsNothing);

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Morgen Sport in der Halle'), findsOneWidget);
    expect(find.text('Bitte Turnsachen mitbringen'), findsOneWidget);
    expect(find.text('Nur bis zur vierten Stunde'), findsNothing,
        reason: 'only the tapped day is shown');

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the course selection is available in the week view',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    // Punkt 3: Der Zahnrad-Knopf aus der Tagesansicht ist auch hier da und
    // öffnet die Kurseinstellungen.
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Courses), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('every course of a doubled period gets its own row',
      (WidgetTester tester) async {
    // In der 1. Stunde liegen zwei Kurse (Parallelkurs). Beide müssen
    // erscheinen – untereinander, beide in derselben Stundennummer.
    final Map<String, dynamic> plan =
        DemoData.buildDayPlan(DateTime(2026, 9, 21));
    final List<dynamic> kl = plan['data']['Klassen']['Kl'] as List<dynamic>;
    final Map<String, dynamic> kl0 = Map<String, dynamic>.from(kl.first as Map);
    final Map<String, dynamic> pl = Map<String, dynamic>.from(kl0['Pl'] as Map);
    final List<dynamic> std = List<dynamic>.from(pl['Std'] as List<dynamic>);
    final Map<String, dynamic> second =
        Map<String, dynamic>.from(std.first as Map);
    // **Achtung:** In diesem Plan heißen die Felder noch wie im XML ('Fa' ist
    // das Fach). 'lesson' ist erst die Bezeichnung, die `parseVPlanXML` daraus
    // macht.
    second['Fa'] = 'PARALLEL';
    second['Ra'] = '999';
    std.insert(1, second);
    pl['Std'] = std;
    kl0['Pl'] = pl;
    kl[0] = kl0;
    plan['data']['Klassen']['Kl'] = kl;

    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(plan),
        for (int i = 1; i < 5; i++)
          jsonEncode(DemoData.buildDayPlan(
              DateTime(2026, 9, 21).add(Duration(days: i)))),
      ],
    });
    await pumpWeekPlan(tester);

    // Beide Kurse stehen sichtbar im Grid.
    expect(find.text('PARALLEL'), findsOneWidget);
    expect(find.text('999'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('up to eight lessons a day still fill the screen',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    // Der Demo-Plan hat 6 Stunden pro Tag. Sie teilen sich die verfügbare
    // Höhe **wie vorher** – die Stunden werden nicht kleiner, nur weil die
    // native Navigationsleiste jetzt über dem Inhalt liegt.
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect grid = tester.getRect(find.byType(WeekPlanGrid));
    expect(grid.bottom, lessThanOrEqualTo(screen.height),
        reason: 'das Raster darf nicht über den Bildschirm hinausragen');

    // Scrollbar ist es trotzdem – aber nur um den Platz am Ende. Das heißt hier
    // also gerade **nicht**, dass die Stunden kleiner geworden wären.
    expect(
      find.descendant(
        of: find.byType(WeekPlanGrid),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );

    await AppClock.setOverriddenNow(null);
  });

  /// Wie [_planWithLessons], aber **genau** [lessons] Stunden an einem Tag –
  /// auch weniger, als der Demo-Plan hat.
  Map<String, dynamic> _planWithExactly(DateTime date, int lessons) {
    final Map<String, dynamic> plan = DemoData.buildDayPlan(date);
    final List<dynamic> kl = plan['data']['Klassen']['Kl'] as List<dynamic>;
    final Map<String, dynamic> kl0 = Map<String, dynamic>.from(kl.first as Map);
    final Map<String, dynamic> pl = Map<String, dynamic>.from(kl0['Pl'] as Map);
    final List<dynamic> std = List<dynamic>.from(pl['Std'] as List<dynamic>);
    final List<dynamic> many = <dynamic>[];
    for (int i = 0; i < lessons; i++) {
      final Map<String, dynamic> lesson =
          Map<String, dynamic>.from(std[i % std.length] as Map);
      // Eigene Stundennummer, sonst hätte das Raster weniger Zeilen als
      // gewünschte Einträge.
      lesson['St'] = '${i + 1}';
      many.add(lesson);
    }
    pl['Std'] = many;
    kl0['Pl'] = pl;
    kl[0] = kl0;
    plan['data']['Klassen']['Kl'] = kl;
    return plan;
  }

  testWidgets('few lessons a day keep the row height and are not stretched',
      (WidgetTester tester) async {
    Future<double> cellHeightWith(int lessons) async {
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '999999',
        'vplanUsername': 'lehrer',
        'vplanPassword': 'geheim',
        'classes': ['5a'],
        'offlineVPData': <String>[
          for (int i = 0; i < 5; i++)
            jsonEncode(_planWithExactly(
                DateTime(2026, 9, 21).add(Duration(days: i)), lessons)),
        ],
      });
      await pumpWeekPlan(tester);
      return tester
          .getRect(
            find
                .descendant(
                  of: find.byType(WeekPlanGrid),
                  matching: find
                      .byKey(const ValueKey<String>('lessonCell_2026-9-21_0')),
                )
                .first,
          )
          .height;
    }

    // Acht Stunden sind die Menge, für die der Bereich gedacht ist: Eine
    // Zelle ist so hoch, wie sie sein soll.
    final double expected = await cellHeightWith(8);

    // Drei Stunden am Tag dürfen die Zellen **nicht** dreimal so hoch machen.
    //
    // Vor der Kappung teilte das Raster die verfügbare Höhe durch die Zahl der
    // Stunden: Aus drei wurden Zellen von über 200 Pixeln, deren Inhalt oben
    // klebt – das sehr gestreckt wirkende Raster, um das es hier geht.
    final double withThree = await cellHeightWith(3);

    expect(withThree, lessThanOrEqualTo(expected + 0.5),
        reason: 'wenige Stunden dürfen die Zellen nicht in die Höhe ziehen');
    expect(tester.takeException(), isNull);

    // Die dritte Stunde steht dicht unter der zweiten, statt am oberen Rand
    // eines dreifach hohen Feldes zu schweben.
    final Finder second = find
        .descendant(
          of: find.byType(WeekPlanGrid),
          matching:
              find.byKey(const ValueKey<String>('lessonCell_2026-9-21_1')),
        )
        .first;
    final Finder third = find
        .descendant(
          of: find.byType(WeekPlanGrid),
          matching:
              find.byKey(const ValueKey<String>('lessonCell_2026-9-21_2')),
        )
        .first;
    expect(tester.getRect(third).height, closeTo(expected, 1));
    expect(tester.getRect(third).top, closeTo(tester.getRect(second).bottom, 1),
        reason: 'the rows sit directly below each other without a gap');

    // Der frei gebliebene Raum liegt **unter** dem Raster – dort, wo er auch
    // hingehört: Der Platz für die Navigationsleiste bleibt am Ende der
    // Scrollstrecke und steht nicht mitten im leeren Band.
    expect(find.byType(NativeShellScrollEndInset), findsOneWidget);
    expect(
      tester.getRect(find.byType(NativeShellScrollEndInset)).top,
      greaterThan(tester.getRect(find.byType(WeekPlanGrid)).bottom),
      reason: 'der Platz für die Leiste liegt unter dem Raster, nicht darin',
    );

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('more than eight lessons a day make the week scrollable',
      (WidgetTester tester) async {
    // Neun Einträge am Montag.
    final Map<String, dynamic> plan = _planWithLessons(9);
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(plan),
        for (int i = 1; i < 5; i++)
          jsonEncode(DemoData.buildDayPlan(
              DateTime(2026, 9, 21).add(Duration(days: i)))),
      ],
    });
    await pumpWeekPlan(tester);

    // Ab der neunten Zeile wird gescrollt – die Stunden sind aber alle da.
    expect(
      find.descendant(
        of: find.byType(WeekPlanGrid),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('a ninth lesson is partly visible, hinting at more to scroll',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(_planWithLessons(9)),
        for (int i = 1; i < 5; i++)
          jsonEncode(DemoData.buildDayPlan(
              DateTime(2026, 9, 21).add(Duration(days: i)))),
      ],
    });
    await pumpWeekPlan(tester);

    // Die neunte Zeile liegt im Scrollbereich. Sie muss teilweise im Bild
    // sein – ohne diesen Rest sähe man nicht, dass es weitergeht.
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect ninth = tester.getRect(
      find.byKey(const ValueKey<String>('lessonCell_2026-9-21_8')),
    );
    expect(ninth.top, lessThan(screen.height),
        reason: 'the ninth lesson must start inside the screen');
    expect(ninth.bottom, greaterThan(screen.height),
        reason: 'and must be cut off by it – otherwise there is no hint');

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the header takes less space so more lessons fit on screen',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester, size: const Size(400, 800));

    // Zwischen der Kopfzeile der Seite und der ersten Rasterzeile soll kein
    // nennenswerter Leerstand mehr sein – er ginge zulasten der Stunden.
    final Rect appBar =
        tester.getRect(find.byIcon(Icons.refresh).hitTestable());
    final Rect range = tester.getRect(find.text('21.09. - 25.09.'));
    expect(range.top - appBar.bottom, lessThan(70),
        reason: 'the date row must sit close below the app bar');

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the weekday and the date below it are not scaled down',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester, size: const Size(400, 800));

    // Der Tageskopf steckt in einem [FittedBox] (scaleDown), damit er nie
    // überläuft. Dieser Test wacht darüber, dass er **nichts** skaliert – sonst
    // sähe die Schrift kleiner aus, als sie eingestellt ist, und genau das war
    // die Beschwerde.
    final Finder weekday = find.text('Mon');
    final Finder date = find.text('21');

    // Das [FittedBox] bekommt den Platz fest vorgegeben; passt sein Inhalt
    // hinein, wird nichts skaliert. Passt er nicht hinein, schrumpft die
    // Schrift unter ihre eingestellte Größe.
    final Size fitted = tester.getSize(
      find.ancestor(of: weekday, matching: find.byType(FittedBox)).first,
    );
    final Size content = tester.getSize(
      find
          .descendant(
            of: find
                .ancestor(of: weekday, matching: find.byType(FittedBox))
                .first,
            matching: find.byType(Column),
          )
          .first,
    );
    expect(content.height, lessThanOrEqualTo(fitted.height + 0.5),
        reason: 'the weekday and its date must fit without being scaled down');
    expect(content.width, lessThanOrEqualTo(fitted.width + 0.5));

    expect(
        tester.widget<Text>(weekday).style!.fontSize, greaterThanOrEqualTo(17));
    expect(tester.widget<Text>(date).style!.fontSize, greaterThanOrEqualTo(15));

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('a week with only one available day still shows all days',
      (WidgetTester tester) async {
    // Nur der **Mittwoch** hat einen Plan. Trotzdem muss die ganze Woche
    // dastehen – die anderen Tage leer.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 9, 23))),
      ],
    });
    await pumpWeekPlan(tester);

    // Alle sechs Tage der Schulwoche als Spalte – nicht nur der Mittwoch.
    const List<String> weekdayNames = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
    ];
    for (final String name in weekdayNames) {
      expect(find.text(name), findsOneWidget, reason: 'missing column "$name"');
    }

    // Der Samstag gehört nicht zur Schulwoche und wird nicht gezeigt.
    expect(find.text('Sat'), findsNothing);

    // Und sie stehen nebeneinander, nicht untereinander.
    final Set<double> rows = weekdayNames
        .map((String n) => tester.getCenter(find.text(n)).dy)
        .toSet();
    expect(rows, hasLength(1));

    // Der Mittwoch hat Stunden, die anderen Tage nicht.
    expect(find.byKey(const ValueKey<String>('lessonCell_2026-9-23_0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('lessonCell_2026-9-21_0')),
        findsNothing);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the date range stays correct for every day of the week',
      (WidgetTester tester) async {
    // Der Fehler trat am Sonntag auf: Start und Ende lagen in verschiedenen
    // Wochen (z.B. „25.10. - 24.10.“). Deshalb wird jeder Wochentag geprüft.
    for (int offset = 0; offset < 7; offset++) {
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '999999',
        'vplanUsername': 'lehrer',
        'vplanPassword': 'geheim',
        'classes': ['5a'],
        'offlineVPData': <String>[
          jsonEncode(DemoData.buildDayPlan(DateTime(2026, 9, 21))),
        ],
      });
      // Montag 21.09.2026 plus `offset` Tage.
      await AppClock.setOverriddenNow(
          DateTime(2026, 9, 21, 8).add(Duration(days: offset)));
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en', ''),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: WeekPlan(classId: '5a')),
      ));
      await tester.pumpAndSettle();

      // Immer dieselbe Woche: Montag bis Samstag, aufsteigend.
      expect(find.text('21.09. - 25.09.'), findsOneWidget,
          reason:
              'wrong range on weekday ${DateTime(2026, 9, 21).add(Duration(days: offset)).weekday}');
    }

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the arrows keep working after a week without any plan',
      (WidgetTester tester) async {
    // Ausgangswoche (14.09.) ohne jeden Plan, Zielwoche (21.09.) mit genau
    // einem. Genau dieser Übergang ist previously hängen geblieben: Der
    // Ladezustand wurde nach einem Fehler nie wieder freigegeben, wodurch
    // jeder weitere Klick auf den Pfeil verworfen wurde und die Seite in der
    // leeren Woche stehen blieb.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 9, 21))),
      ],
    });
    await AppClock.setOverriddenNow(DateTime(2026, 9, 16, 8));
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: WeekPlan(classId: '5a')),
    ));
    await tester.pumpAndSettle();

    // Woche ohne Pläne: Die Meldung steht da.
    expect(find.text('14.09. - 18.09.'), findsOneWidget);
    expect(
      find.text('No substitution plan available for this week.'),
      findsOneWidget,
    );

    // In die Woche mit dem einen Plan springen.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('21.09. - 25.09.'), findsOneWidget,
        reason: 'the week must actually change');
    expect(
      find.text('No substitution plan available for this week.'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('lessonCell_2026-9-21_0')),
        findsOneWidget);

    // Und weiter – die Pfeile dürfen nicht wieder klemmen.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(find.text('28.09. - 02.10.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('21.09. - 25.09.'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the arrow jumps over empty weeks to the next one with a plan',
      (WidgetTester tester) async {
    // Wochenabstand: 05.10. (Plan) – dann drei leere Wochen (Ferien) – dann
    // 09.11. (Plan). Ein Klick auf "weiter" muss direkt auf den 09.11. führen
    // und nicht bei 12.10. hängen bleiben.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 10, 5))),
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 11, 9))),
      ],
    });
    await AppClock.setOverriddenNow(DateTime(2026, 10, 7, 10));
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: WeekPlan(classId: '5a')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('05.10. - 09.10.'), findsOneWidget);

    // Ein Klick – drei leere Wochen werden übersprungen.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('09.11. - 13.11.'), findsOneWidget,
        reason: 'must skip the empty weeks instead of stepping through them');
    expect(find.byKey(const ValueKey<String>('lessonCell_2026-11-9_0')),
        findsOneWidget);

    // Und zurück direkt zurück zum 05.10.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('05.10. - 09.10.'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the arrow lands in the week of the found plan, not the next one',
      (WidgetTester tester) async {
    // Der Plan liegt am **Donnerstag** der übernächsten Woche. Die Woche davor
    // ist komplett leer. Gesucht wird ab dem Montag dieser Woche – und die
    // gefundene Woche ist die des Donnerstags.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 10, 5))),
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 10, 22))),
      ],
    });
    await AppClock.setOverriddenNow(DateTime(2026, 10, 7, 10));
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: WeekPlan(classId: '5a')),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    // Donnerstag 22.10. liegt in der Woche 19.10. - 23.10.
    expect(find.text('19.10. - 23.10.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('lessonCell_2026-10-22_0')),
        findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the loading indicator shows three points that move',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: LoadingIndicator())),
    ));
    await tester.pump();

    // Drei Punkte – nicht ein kreisender Balken.
    expect(find.byType(Container), findsNWidgets(3));

    // Sie bewegen sich: Ohne Animation wäre die Deckkraft konstant.
    final double before =
        tester.widget<Opacity>(find.byType(Opacity).at(0)).opacity;
    await tester.pump(const Duration(milliseconds: 220));
    final double after =
        tester.widget<Opacity>(find.byType(Opacity).at(0)).opacity;
    expect(after, isNot(equals(before)),
        reason: 'the points must animate, not stand still');
  });

  test('week arithmetic survives the change of clock (DST)', () {
    // In der Nacht zum 25.10.2026 wird die Uhr in Deutschland eine Stunde
    // ZURÜCK gestellt. Mit `add(Duration(days: 7))` sprang der Wochenanfang
    // deshalb auf Sonntag, 25.10., 23:00 – und aus dem Sonntag wurde wieder
    // der Montag derselben Woche berechnet, also der 19.10. Die Navigation
    // blieb ab da stecken.
    //
    // Der Test gilt in jeder Zeitzone: Er prüft die Kalenderrechnung selbst,
    // nicht das Ausmaß der Zeitverschiebung.
    final List<DateTime> mondays = <DateTime>[
      DateTime(2026, 10, 5), // vor der Umstellung
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 19), // die Woche, über die die Umstellung liegt
      DateTime(2026, 10, 26), // direkt danach
      DateTime(2026, 3, 30), // die Umstellung im Frühjahr
    ];

    for (final DateTime monday in mondays) {
      expect(startOfSchoolWeek(monday), monday,
          reason: 'a Monday must stay a Monday');

      for (int weeks = 1; weeks <= 3; weeks++) {
        final DateTime shifted =
            startOfSchoolWeek(addSchoolDays(monday, 7 * weeks));
        expect(shifted.weekday, DateTime.monday,
            reason: 'the week start must remain a Monday');
        expect(shifted.difference(monday).inDays, 7 * weeks,
            reason: 'jumping $weeks week(s) from $monday landed on $shifted');
        expect(shifted.hour, 0, reason: 'and must stay at midnight');
      }

      // Die fünf Schultage sind echte aufeinanderfolgende Kalendertage.
      // (Über Monatsgrenzen hinweg darf man nicht die Tageszahl vergleichen –
      // der 31. wird zum 1. des nächsten Monats.)
      final List<DateTime> week = <DateTime>[
        for (int i = 0; i < 5; i++) addSchoolDays(monday, i),
      ];
      for (int i = 0; i < week.length; i++) {
        expect(
          week[i],
          DateTime(monday.year, monday.month, monday.day + i),
          reason: 'day $i of the week is wrong',
        );
        expect(week[i].hour, 0);
      }
      expect(week.first.weekday, DateTime.monday);
      expect(week.last.weekday, DateTime.friday);
    }
  });

  testWidgets('navigating across the clock change reaches the following weeks',
      (WidgetTester tester) async {
    // Genau der gemeldete Ablauf: Woche mit Plänen → zwei leere Wochen
    // (Ferien) → Woche mit einem Plan. Die Zielwoche liegt über der
    // Zeitumstellung vom 25.10.2026; ein Klick auf "weiter" muss sie direkt
    // erreichen.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'offlineVPData': <String>[
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 10, 5))),
        jsonEncode(DemoData.buildDayPlan(DateTime(2026, 10, 26))),
      ],
    });
    await AppClock.setOverriddenNow(DateTime(2026, 10, 11, 10));
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: WeekPlan(classId: '5a')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('05.10. - 09.10.'), findsOneWidget);

    // Die beiden Ferienwochen werden in einem Schritt übersprungen.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(find.text('26.10. - 30.10.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('lessonCell_2026-10-26_0')),
        findsOneWidget);

    // Und wieder zurück, rückwärts über dieselben leeren Wochen.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('05.10. - 09.10.'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('a changed room or teacher is marked by colour only',
      (WidgetTester tester) async {
    // Ein Tag, in dem Raum **und** Lehrer dieser einen Stunde geändert wurden.
    final Map<String, dynamic> plan =
        DemoData.buildDayPlan(DateTime(2026, 9, 21));
    final List<dynamic> kl = plan['data']['Klassen']['Kl'] as List<dynamic>;
    final Map<String, dynamic> kl0 = Map<String, dynamic>.from(kl.first as Map);
    final Map<String, dynamic> pl = Map<String, dynamic>.from(kl0['Pl'] as Map);
    final List<dynamic> std = List<dynamic>.from(pl['Std'] as List<dynamic>);
    final Map<String, dynamic> first =
        Map<String, dynamic>.from(std.first as Map);
    first['placeChanged'] = true;
    first['teacherChanged'] = true;
    first['info'] = 'Vertretung';
    std[0] = first;
    pl['Std'] = std;
    kl0['Pl'] = pl;
    kl[0] = kl0;
    plan['data']['Klassen']['Kl'] = kl;

    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
      'hideLessonTimes': false,
      'hideTeacher': false,
      'offlineVPData': <String>[
        jsonEncode(plan),
        for (int i = 1; i < 5; i++)
          jsonEncode(DemoData.buildDayPlan(
              DateTime(2026, 9, 21).add(Duration(days: i)))),
      ],
    });
    await pumpWeekPlan(tester);

    final _CellTexts texts = _firstCellTexts(tester);
    final Text room = texts.room;
    final Text teacher = texts.teacher;

    // Farbe ist gesetzt …
    expect(room.style!.color, isNotNull);
    expect(teacher.style!.color, isNotNull);
    // … aber **kein** Fettdruck: Eine Änderung wird allein an der Farbe
    // erkennbar, damit Raum und Lehrer nicht aus der typografischen Reihe
    // fallen.
    expect(room.style!.fontWeight, isNot(FontWeight.bold));
    expect(teacher.style!.fontWeight, isNot(FontWeight.bold));

    // Die geänderten Angaben sind in der Zelle farbig, das Fach nicht.
    final Text subject = texts.subject;
    expect(room.style!.color, isNot(subject.style!.color));

    await AppClock.setOverriddenNow(null);
  });

  testWidgets('the week view is off by default and can be switched on',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
    });
    // Die Option liegt inzwischen in den Darstellungseinstellungen, nicht mehr
    // in den Plan-Einstellungen.
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AppearanceSettings()),
    ));
    await tester.pumpAndSettle();

    final Finder tile = find.ancestor(
      of: find.text('Weekly view'),
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

  testWidgets('the lesson information options moved into their own submenu',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '999999',
      'vplanUsername': 'lehrer',
      'vplanPassword': 'geheim',
      'classes': ['5a'],
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PlanSettings()),
    ));
    await tester.pumpAndSettle();

    // Die Plan-Einstellungen zeigen selbst keine Schalter mehr, sondern
    // verweisen auf Untermenüs.
    expect(find.byType(SettingsSwitchTile), findsNothing);
    expect(find.text('Lesson information'), findsOneWidget);

    await tester.tap(find.text('Lesson information'));
    await tester.pumpAndSettle();

    // Dort liegen die drei Schalter.
    expect(find.byType(LessonInfoSettings), findsOneWidget);
    expect(find.byType(SettingsSwitchTile), findsNWidgets(3));
    expect(find.text('Hide lesson times'), findsOneWidget);
    expect(find.text('Hide Teacher'), findsOneWidget);
    expect(find.text('Hide Persons'), findsOneWidget);

    // Und sie schalten weiterhin wie bisher: „Lehrer ausblenden" ist
    // standardmäßig aus, nach dem Tippen ein.
    await tester.tap(find.byType(SwitchListTile).at(1));
    await tester.pumpAndSettle();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hideTeacher'), isTrue);
  });

  testWidgets('week view can navigate to the previous and next week',
      (WidgetTester tester) async {
    seedOfflineWeek();
    await pumpWeekPlan(tester);

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('28.09. - 02.10.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('14.09. - 18.09.'), findsOneWidget);

    await AppClock.setOverriddenNow(null);
  });
}
