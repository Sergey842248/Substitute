import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/main.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';

/// Der letzte Klassenplan muss **über** der Navigationsleiste landen können.
///
/// Der gemeldete Fehler: Bei mehreren Klassenplänen bleibt der unterste hinter
/// der Leiste, und egal wie stark man runterscrollt, er erscheint nur während
/// der Bewegung und springt dann zurück.
///
/// Die Ursache liegt nicht am Startbildschirm, sondern im Inhaltsbereich von
/// `main.dart`: Der Stapel reicht bis zum unteren Rand, und die Leiste liegt
/// darüber. Ein scrollbarer Bildschirm erreicht deshalb sein Ende nie über der
/// Leiste – der Bereich zwischen dem letzten Eintrag und dem Leistenoberrand
/// war null, und die Leiste selbst ist zu hoch, als dass ein Stück von ihr
/// helfen würde.
void main() {
  void aufraeumen() => SyncCoordinator.instance.detach();

  /// Mehrere Klassenpläne **und** mehrere Personen, wie sie nach einiger Zeit
  /// dastehen.
  ///
  /// **Beides ist nötig, um den gemeldeten Fall überhaupt zu erzeugen:**
  ///
  /// * Die Klassenliste ist nur halb so hoch wie der Bildschirm. Ohne Personen
  ///   endet sie bei gut zwei Dritteln und damit über der Leiste – der Fehler
  ///   tritt gar nicht auf.
  /// * Erst eine lange Personenliste schiebt sie so weit nach unten, dass ihr
  ///   Ende hinter die Leiste rutscht. Dann ist der äußere Bereich länger als
  ///   das Sichtbare, man scrollt bis zum Anschlag – und kommt trotzdem nicht
  ///   hoch, weil das Ende bereits erreicht ist. Genau das ist der gemeldete
  ///   Fall: unten weg, egal wie stark man scrollt.
  ///
  /// Die Schlüssel sind **schultbezogen** (`SchoolStorage.scopedKey`), denn so
  /// legt die App sie ab. Mit den einfachen Namen bliebe alles leer, und der
  /// Test würde prüfen, ob eine leere Liste hinter der Leiste verschwindet.
  Future<void> mitKlassenUndPersonen(int klassen, int personen) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanUsername': 'mueller',
      'vplanSchoolnumber': '12345',
      'firstTime': false,
      'languageCode': 'de',
    });
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setStringList(
      SchoolStorage.scopedKey(p, 'classes'),
      <String>[for (int i = 0; i < klassen; i++) '8$i'],
    );
    await p.setString(
      SchoolStorage.scopedKey(p, 'classNames'),
      jsonEncode(<String, dynamic>{
        for (int i = 0; i < klassen; i++) '8$i': 'Klasse 8$i',
      }),
    );
    await p.setString(
      SchoolStorage.scopedKey(p, 'initializedClasses'),
      jsonEncode(<String, dynamic>{
        for (int i = 0; i < klassen; i++) '8$i': true,
      }),
    );
    await p.setString(
      SchoolStorage.scopedKey(p, 'persons'),
      jsonEncode(<Map<String, dynamic>>[
        for (int i = 0; i < personen; i++)
          <String, dynamic>{'id': 'p$i', 'name': 'Person $i'},
      ]),
    );
  }

  /// Die Oberseite der Navigationsleiste.
  ///
  /// Erkennbar an den „aktiv"-Markierungen: Sie sitzen in der Leiste, und die
  /// Leiste ist der einzige Bereich, in dem sie überhaupt vorkommen. Es sind
  /// mehrere (einer je Eintrag), deshalb das **oberste** – und nicht einfach
  /// das erste, denn die Reihenfolge im Baum sagt nichts über die Höhe aus.
  double leistenOberseite(WidgetTester tester) {
    final Finder markierungen = find.byWidgetPredicate(
      (Widget w) => w is SvgPicture && w.width == 13,
    );
    expect(markierungen, findsWidgets);
    double hoechste = double.infinity;
    for (final Element e in markierungen.evaluate()) {
      final double dy = tester.getTopLeft(find.byWidget(e.widget)).dy;
      if (dy < hoechste) hoechste = dy;
    }
    return hoechste;
  }

  /// Die Höhe der **obersten** Karte im Bildschirmkoordinatensystem.
  ///
  /// `double.infinity`, solange keine gebaut ist: Die Karten entstehen erst beim
  /// Aufbau, und das kann einen Moment dauern. Ein Fehler an dieser Stelle
  /// wäre eine Auskunft über den Test und nicht über die App.
  double kartenOben(WidgetTester tester) {
    double hoechste = double.infinity;
    for (int i = 0; i < 40; i++) {
      final Finder f = find.text('Klasse 8$i');
      if (f.evaluate().isEmpty) continue;
      final double y = tester.getRect(f).top;
      if (y < hoechste) hoechste = y;
    }
    return hoechste;
  }

  group('Der Platz unter dem Inhalt', () {
    // Der gemeldete Fall: mehrere Klassenpläne, der unterste bleibt hinter der
    // Leiste und lässt sich nicht herschieben.
    testWidgets('der unterste Klassenplan ist erreichbar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await mitKlassenUndPersonen(14, 10);
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 800));

      final double leiste = leistenOberseite(tester);

      // **Der Zug beginnt auf einer Karte.** So macht man es in der App: Man
      // will die Karten sehen, also zieht man an den Karten. Vorher stand dort
      // eine eigene Liste, die den Zug abfing – der Bildschirm blieb stehen,
      // die Liste bewegte sich, und ganz unten federte sie zurück. Genau das
      // war der gemeldete Fehler.
      //
      // Nur die ersten Züge kommen von oben, solange die Karten noch gar nicht
      // im Bild sind. Danach ausschließlich von der Karte aus.
      for (int i = 0; i < 20; i++) {
        final double oben = kartenOben(tester);
        if (oben > 200 && oben < leiste - 300) break;
        await tester.dragFrom(const Offset(180, 200), const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pumpAndSettle();

      for (int i = 0; i < 20; i++) {
        final double oben = kartenOben(tester);
        if (!oben.isFinite) break;
        // Auf einer Karte ziehen – aber auf einer, die gerade wirklich im
        // Bild ist. Die oberste Karte wandert mit dem Scrollen nach oben und
        // irgendwann aus dem Bild heraus; ein Zug, der daneben ins Leere
        // geht, scrollt nichts, und man hielte den Fehler für behoben.
        final double y = oben.clamp(210.0, leiste - 60.0);
        await tester.dragFrom(Offset(180, y), const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pumpAndSettle();

      // Der unterste Klassenplan: In der Liste der Klassen steht er zuletzt.
      final Finder letzteKlasse = find.text('Klasse 813');
      expect(letzteKlasse, findsOneWidget,
          reason: 'die letzte Klasse wurde gar nicht aufgebaut – sie steckt '
              'in einer Liste, die den Bildschirm verdeckt');
      expect(tester.getRect(letzteKlasse).bottom, lessThanOrEqualTo(leiste),
          reason: 'der letzte Plan liegt hinter der Leiste, auch nachdem man '
              'an ihm gezogen hat');

      aufraeumen();
    });

    testWidgets('und derselbe Bereich gilt für alle Bildschirme',
        (WidgetTester tester) async {
      // Der Platz wird an **einer** Stelle reserviert. Prüfbar daran, dass der
      // Inhaltsbereich den Platz für die Leiste von sich aus freihält – und
      // nicht erst dadurch, dass jeder Bildschirm es selbst tut.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await mitKlassenUndPersonen(2, 4);
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 800));

      final double leiste = leistenOberseite(tester);

      // Der Bereich, in dem die Bildschirme stehen, endet über der Leiste.
      //
      // Gemessen wird der **Animationscontainer**, nicht der Rahmen drumherum:
      // Der Rahmen reicht immer bis zum unteren Rand, und der Platz für die
      // Leiste ist ein Innenabstand – er liegt im Rahmen, nicht daneben.
      // Erst der Container *in* diesem Abstand ist der Bereich, in dem der
      // letzte Eintrag eines Bildschirms landet.
      // Es gibt zwei: einen in der Kopfzeile der App und einen im Inhalts-
      // bereich. Der gesuchte ist der mit der kurzen Dauer.
      final Rect rahmen = tester.getRect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is AnimatedSwitcher &&
              w.duration == const Duration(milliseconds: 250),
        ),
      );
      expect(rahmen.bottom, lessThanOrEqualTo(leiste),
          reason: 'der Bildschirmbereich reicht bis ${rahmen.bottom}, die '
              'Leiste beginnt bei $leiste – der letzte Eintrag bliebe dahinter');

      // Und es ist mindestens so viel Platz, wie die Leiste braucht.
      //
      // Mehr ist unkritisch – die Leiste hat über ihren Symbolen noch einen
      // eigenen Rand. **Weniger** wäre der Fehler: Dann schöbe sich der letzte
      // Eintrag unter die Leiste.
      final Size bildschirm =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final double reserve = bildschirm.height - rahmen.bottom;
      expect(reserve, greaterThanOrEqualTo(bildschirm.height * 0.1),
          reason: 'es sind nur $reserve Pixel Platz reserviert, die Leiste ist '
              'aber ${bildschirm.height * 0.1} hoch');

      aufraeumen();
    });
  });
}
