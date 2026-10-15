import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/VPlan.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';

/// Nach dem Import eines fremden Shares war die App **neu zu starten**, damit
/// die übernommenen Klassen und Personen überhaupt auftauchten.
///
/// Der Grund war nicht der Import: Der schreibtclasses, Personen und Pläne in
/// die Einstellungen, und von dort liest die Startseite ihre Listen. Sie las
/// sie aber nur **einmal** – beim Aufbau. Die Datei änderte sich danach, ohne
/// dass jemand davon erfuhr; das Neu Laden der Pläne im Hintergrund meldete nur
/// die „nächste Stunde" je Karte.
class _Person {
  _Person(this.id, this.name, this.classId);

  final String id;
  final String name;
  final String classId;

  String alsZeile() => jsonEncode(<String, dynamic>{
        'id': id,
        'name': name,
        'classId': classId,
        'courses': <String>[],
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// `pumpAndSettle` kommt nicht in Frage: Solange die Vorschauen der Karten
  /// nachladen, dreht sich ein Ladesymbol endlos und der Baum wird nie fertig.
  Future<void> advance(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Legt Startbildschirm und Speicher her – wie nach einem Share-Import.
  Future<void> starten(
    WidgetTester tester, {
    required List<String> klassen,
    required List<_Person> personen,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'languageCode': 'en',
      // `classes` ist eine **Liste**, `persons` eine JSON-Zeichenkette – so legt
      // die App beides ab (`VPlanAPI.savePersons`), und so schreibt es auch der
      // Share-Import. Wer hier die falsche Form wählt, prüft einen Zustand, den
      // es nicht gibt.
      'classes': klassen,
      'persons': jsonEncode(
        personen
            .map(
                (_Person p) => jsonDecode(p.alsZeile()) as Map<String, dynamic>)
            .toList(),
      ),
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', ''),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: VPlan()),
      ),
    );
    await advance(tester);
  }

  testWidgets('zeigt neue Klassen und Personen ohne Neustart',
      (WidgetTester tester) async {
    await starten(
      tester,
      klassen: <String>['7c'],
      personen: <_Person>[_Person('p1', 'Hans', '7c')],
    );

    expect(find.text('7c'), findsWidgets);
    expect(find.text('Hans'), findsWidgets);

    // Das, was der Import schreibt: eine Klasse und eine Person kommen dazu.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('classes', <String>['7c', '9z']);
    await prefs.setString(
      'persons',
      jsonEncode(<Map<String, dynamic>>[
        jsonDecode(_Person('p1', 'Hans', '7c').alsZeile())
            as Map<String, dynamic>,
        jsonDecode(_Person('p2', 'Petra', '9z').alsZeile())
            as Map<String, dynamic>,
      ]),
    );
    // Und die Seite sagt Bescheid – dasselbe Signal, über das auch die
    // Hintergrund-Aktualisierung läuft.
    notifyVPlanBackgroundRefresh();
    await advance(tester);

    expect(find.text('9z'), findsWidgets,
        reason: 'die importierte Klasse ist nicht erschienen');
    expect(find.text('Petra'), findsWidgets,
        reason: 'die importierte Person ist nicht erschienen');
  });

  testWidgets('bleibt stehen, wenn sich nichts geändert hat',
      (WidgetTester tester) async {
    // Der Hintergrund-Refresh feuert mehrfach in der Minute. Ohne den Vergleich
    // würde die Liste dabei jedes Mal neu aufgebaut – mit jeder Karte und jedem
    // Nachladen darin. Der Ortsbaum der Karten muss deshalb derselbe bleiben.
    await starten(
      tester,
      klassen: <String>['7c'],
      personen: <_Person>[_Person('p1', 'Hans', '7c')],
    );
    expect(find.byType(ClassWidget), findsOneWidget);
    final State ersteKarte = tester.state(find.byType(ClassWidget));

    notifyVPlanBackgroundRefresh();
    await advance(tester);

    expect(find.byType(ClassWidget), findsOneWidget);
    expect(tester.state(find.byType(ClassWidget)), same(ersteKarte),
        reason:
            'die Karten wurden neu gebaut, obwohl sich nichts geändert hat');
  });
}
