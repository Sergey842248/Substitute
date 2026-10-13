import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/services/NativeShell.dart';

/// Der Platz am unteren Rand einer nativen Ansicht.
///
/// ## Der Fehler, den diese Tests festhalten
///
/// Der Abschluss am Listenende stand an **zwei** Stellen, aber nicht an der
/// dritten, und er prüfte die **falsche** Rolle:
///
/// * `ListPage` setzte ihn nur in den `ListView`-Zweig. Die Variante
///   `fillHeight` – eine [Column] ohne Scrollen – vergaß ihn ganz. Genau die
///   Wochenansicht benutzt [fillHeight], und dadurch lag die letzte Stunde
///   hinter der Tab-Leiste.
/// * Geprüft wurde [NativeShell.isSection]. Ein Werkzeug wie „Lehrerkürzel
///   festlegen“ hat aber keine Reiter-Rolle, sondern [NativeShellRole.tool] –
///   es bekam also keinen Abspruch, obwohl es sehr wohl bis an den unteren Rand
///   reicht.
///
/// [NativeShell.extendsToNativeBottom] ist die eine Aussage, auf die es
/// ankommt: „Reicht diese Ansicht bis an den unteren Rand der nativen Hülle?“
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    NativeShell.ueberdeckung.value = 0;
    NativeShell.debugSetRole(NativeShellRole.full);
  });

  /// Eine [ListPage] mit [fillHeight] – die Variante ohne Scrollen.
  Widget fuellHoehe() => MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<Object>>[],
        home: ListPage(
          title: 'Test',
          fillHeight: true,
          children: const <Widget>[Expanded(child: Text('Inhalt'))],
        ),
      );

  group('Wer den Abschluss am Listenende bekommt', () {
    test('ein Reiter', () {
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      expect(NativeShell.extendsToNativeBottom, isTrue);
    });

    test('ein Werkzeug – auch ohne Reiter-Rolle', () {
      // Das ist der eigentliche Fehler gewesen: „Lehrerkürzel festlegen“ ist
      // kein Reiter. Nach der alten Prüfung (`isSection`) wäre es durchgefallen,
      // obwohl es in einer nativen Hülle liegt und bis an deren unteren Rand
      // reichen muss.
      NativeShell.debugSetRole(NativeShellRole.tool);
      expect(NativeShell.isSection, isFalse,
          reason: 'ein Werkzeug ist ausdrücklich kein Reiter');
      expect(NativeShell.extendsToNativeBottom, isTrue,
          reason: '… reicht aber trotzdem bis an den unteren Rand');
    });

    test('die ganze App auf Android nicht', () {
      // Ohne native Schale gibt es keine Leiste, und [SafeArea] setzt den
      // sicheren Bereich bereits. Ein zusätzlicher Abschnitt wäre doppelt.
      NativeShell.debugSetRole(NativeShellRole.full);
      expect(NativeShell.extendsToNativeBottom, isFalse);
    });
  });

  group('Die Liste hängt den Abschluss an', () {
    /// Die Höhe, die der Abschluss am Ende wirklich einnimmt.
    ///
    /// Geprüft wird die **Höhe** und nicht das Vorhandensein des Widgets:
    /// [NativeShellScrollEndInset] steht immer im Baum – es baut sich nur ohne
    /// native Schale zu einem [SizedBox] der Höhe `0`. „Vorhanden“ wäre damit
    /// kein Befund; „so hoch“ schon.
    Future<double> hoehe(WidgetTester tester) async {
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(NativeShellScrollEndInset)).height;
    }

    testWidgets('auch dann, wenn sie nicht scrollt',
        (WidgetTester tester) async {
      // Der [fillHeight]-Zweig. Er hatte den Abschluss nicht – und die
      // Wochenansicht ist genau dieser Zweig.
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      NativeShell.ueberdeckung.value = 80;

      await tester.pumpWidget(fuellHoehe());

      expect(await hoehe(tester), greaterThan(0),
          reason: 'ohne Scrollen muss der Platz fest eingeplant sein – '
              'sonst liegt die letzte Stunde hinter der Leiste');
    });

    testWidgets('im scrollenden Zweig wie bisher', (WidgetTester tester) async {
      NativeShell.debugSetRole(NativeShellRole.sectionPlan);
      NativeShell.ueberdeckung.value = 80;

      await tester.pumpWidget(MaterialApp(
        home: ListPage(
          title: 'Test',
          children: const <Widget>[Text('Zeile')],
        ),
      ));

      expect(await hoehe(tester), greaterThan(0));
    });

    testWidgets('beim Werkzeug – „Lehrerkürzel festlegen“',
        (WidgetTester tester) async {
      // Der gemeldete Fehler: Das Werkzeug hat keine Reiter-Rolle und bekam
      // deshalb nach der alten Prüfung keinen Abspruch.
      NativeShell.debugSetRole(NativeShellRole.tool);
      NativeShell.ueberdeckung.value = 34;

      await tester.pumpWidget(fuellHoehe());

      expect(await hoehe(tester), greaterThan(0),
          reason: 'ein Werkzeug reicht bis an den unteren Rand und braucht '
              'deshalb den Platz genauso');
    });

    testWidgets('nicht auf Android', (WidgetTester tester) async {
      // Ohne native Schale gibt es weder Leiste noch Abschnitt; [SafeArea]
      // setzt den sicheren Bereich bereits.
      NativeShell.debugSetRole(NativeShellRole.full);

      await tester.pumpWidget(fuellHoehe());

      expect(await hoehe(tester), 0);
    });
  });
}
