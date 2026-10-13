import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/services/NativeShell.dart';

/// Der Platz am unteren Rand einer nativen Ansicht.
///
/// ## Der Fehler, den diese Tests festhalten
///
/// Der Platz für die native Tab-Leiste gehört ans **Ende einer Scrollstrecke**.
/// Als fester Rand um den Bildschirm ist er immer sichtbar und sieht aus wie
/// eine Schicht zwischen Inhalt und Leiste.
///
/// Genau das ist zweimal passiert:
///
/// * In [ListPage] stand er nur im `ListView`-Zweig. Die Wochenansicht
///   benutzt [ListPage.fillHeight] – die Variante ohne Scrollen – und bekam
///   daraufhin gar keinen Platz; die letzte Stunde lag hinter der Leiste.
/// * Der Ausweg „dann halt dauerhaft einplanen“ brachte den **festen Streifen**
///   hervor, den der Nutzer als Schicht beschrieben hat.
///
/// Die Auflösung ist beides nicht: Der Bildschirm bringt sein **eigenes**
/// Scrollen mit (`WeekPlanGrid`), und der Platz steht am Ende davon.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    NativeShell.ueberdeckung.value = 0;
    NativeShell.debugSetRole(NativeShellRole.full);
  });

  /// Eine [ListPage] mit [ListPage.fillHeight] – die Variante ohne Scrollen.
  Widget fuellHoehe() => MaterialApp(
        home: ListPage(
          title: 'Test',
          fillHeight: true,
          children: const <Widget>[Expanded(child: Text('Inhalt'))],
        ),
      );

  /// Eine [ListPage] mit [ListView] – die scrollende Variante.
  Widget scrollend() => MaterialApp(
        home: ListPage(
          title: 'Test',
          children: const <Widget>[Text('Zeile')],
        ),
      );

  /// Die Höhe, die der Abschluss am Ende wirklich einnimmt.
  ///
  /// Geprüft wird die **Höhe** und nicht nur das Vorhandensein, denn
  /// [NativeShellScrollEndInset] baut sich ohne native Schale zu einem
  /// [SizedBox] der Höhe `0` – „im Baum“ wäre also kein Befund, „so hoch“ schon.
  ///
  /// Fehlt das Widget **ganz** – so wie im Zweig ohne Scrollen –, zählt das
  /// ebenfalls als `0`. Beides bedeutet: Dieser Bildschirm reserviert keinen
  /// Platz, und genau darum geht es in den Tests.
  Future<double> hoehe(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final Finder abschluss = find.byType(NativeShellScrollEndInset);
    if (abschluss.evaluate().isEmpty) return 0;
    return tester.getSize(abschluss).height;
  }

  group('Wer den Abspruch am Listenende bekommt', () {
    test('ein Reiter', () {
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      expect(NativeShell.extendsToNativeBottom, isTrue);
    });

    test('ein Werkzeug – auch ohne Reiter-Rolle', () {
      // „Lehrerkürzel festlegen“ ist kein Reiter. Nach einer Prüfung auf
      // [NativeShell.isSection] wäre es durchgefallen, obwohl es sehr wohl bis
      // an den unteren Rand reicht.
      NativeShell.debugSetRole(NativeShellRole.tool);
      expect(NativeShell.isSection, isFalse,
          reason: 'ein Werkzeug ist ausdrücklich kein Reiter');
      expect(NativeShell.extendsToNativeBottom, isTrue,
          reason: '… reicht aber trotzdem bis an den unteren Rand');
    });

    test('die ganze App auf Android nicht', () {
      NativeShell.debugSetRole(NativeShellRole.full);
      expect(NativeShell.extendsToNativeBottom, isFalse);
    });
  });

  group('Die scrollende Liste', () {
    testWidgets('hat den Abschluss am Ende', (WidgetTester tester) async {
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      NativeShell.ueberdeckung.value = 80;

      await tester.pumpWidget(scrollend());

      expect(await hoehe(tester), greaterThan(0));
    });

    testWidgets('beim Werkzeug ebenfalls', (WidgetTester tester) async {
      NativeShell.debugSetRole(NativeShellRole.tool);
      NativeShell.ueberdeckung.value = 34;

      await tester.pumpWidget(scrollend());

      expect(await hoehe(tester), greaterThan(0),
          reason: 'ein Werkzeug reicht bis an den unteren Rand und braucht '
              'deshalb den Platz genauso');
    });

    testWidgets('auf Android nicht', (WidgetTester tester) async {
      NativeShell.debugSetRole(NativeShellRole.full);

      await tester.pumpWidget(scrollend());

      expect(await hoehe(tester), 0);
    });
  });

  group('Die Liste ohne Scrollen', () {
    testWidgets('bekommt **keinen** festen Platz', (WidgetTester tester) async {
      // Das ist der eigentliche Fehler: Ein fester Rand am unteren Bildschirm
      // ist **immer** sichtbar und sieht aus wie eine Schicht zwischen Inhalt
      // und Leiste. Der Platz gehört ans Ende einer Scrollstrecke – und die
      // bringt dieser Bildschirm selbst mit (`WeekPlanGrid`).
      //
      // Ein zweiter Platz wäre hier auch doppelt: `WeekPlanGrid` setzt ihn
      // bereits ans Ende seines eigenen Scrollens.
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      NativeShell.ueberdeckung.value = 80;

      await tester.pumpWidget(fuellHoehe());

      expect(await hoehe(tester), 0);
    });
  });
}
