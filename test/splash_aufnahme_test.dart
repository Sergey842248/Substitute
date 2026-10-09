import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/splash.dart';

/// Nimmt den Startbildschirm als Bild auf.
///
/// Kein Prüfding für die App, sondern ein Werkzeug für den Startbildschirm:
/// Die Animation ist gerechnet, nicht gezeichnet – da kann ein Zahlendreher
/// den Kalender auf die Kante legen, und man sieht es erst im Bild. Die Bilder
/// landen bei jedem Lauf in `build/aufnahmen/`.
///
/// Aufrufen:
///
///     flutter test test/splash_aufnahme_test.dart
///
/// Die Bilder sind nicht eingecheckt: Sie sind jedes Mal neu, und was im Bild zu
/// sehen ist, steht in `lib/splash.dart`.
void main() {
  // **Kein** `FontLoader` – und das ist Absicht, nicht Vergessenheit:
  //
  // Lädt man den echten `Crackman`, verschwindet der Schriftzug auf der
  // Aufnahme ersatzlos: Der Test zeichnet einen geladenen Font nicht in das
  // Bild, das er mit `toImage` bekommt. Ohne den Loader greift der
  // Framework-Ersatzfont, und der macht aus jedem Zeichen ein gefülltes
  // Quadrat: Der Schriftzug ist als Folge von Kästchen da, man sieht also,
  // dass er da ist und wo. Wie er in der App aussieht, steht im Font.
  //
  // Fünf Stände, weil die Animation aus mehreren Abschnitten besteht und man
  // sehen will, dass keiner davon kipp: Der Kalender wird gezeichnet (0,3),
  // die Trennlinie zieht sich quer (0,45), der Kalender ist fertig (0,55), der
  // Schriftzug steigt auf (0,75), und alles steht (1,0).
  for (final double stand in <double>[0.3, 0.45, 0.55, 0.75, 1.0]) {
    for (final bool dunkel in <bool>[true, false]) {
      testWidgets('Startbildschirm bei $stand, ${dunkel ? "dunkel" : "hell"}',
          (WidgetTester t) async {
        // Ohne das rendert der Test in eine Fläche von **800 x 600** Punkten,
        // und der Startbildschirm bekommt die – nicht die Grösse eines
        // Telefons. Man sähe eine Zeichnung, die auf einem Bildschirm steht,
        // den es nicht gibt, und der Schriftzug rutschte aus dem Bild.
        //
        // `devicePixelRatio` 3 auf 1170 x 2532 ergibt wieder 390 x 844
        // logische Punkte: das ist die Grösse, für die der Bildschirm
        // entworfen ist.
        t.view.devicePixelRatio = 3;
        t.view.physicalSize = const Size(1170, 2532);
        addTearDown(t.view.reset);

        // Der Startbildschirm liest die themes Einstellung selbst – so, wie er
        // es auch am echten Start tut. Damit die Aufnahme den hellen Fall
        // wirklich zeigt, muss die Einstellung auch wirklich hell sein.
        SharedPreferences.setMockInitialValues(<String, Object>{
          if (!dunkel) 'appearance.theme': 'light',
        });

        final GlobalKey schluessel = GlobalKey();

        await t.pumpWidget(
          RepaintBoundary(
            key: schluessel,
            // Kein `MaterialApp` und keine Hülle: `SplashScreen` baut beides
            // nicht und braucht beides nicht – er ist der oberste Bildschirm
            // und läuft vor jedem `MaterialApp`.
            child: const SplashScreen(),
          ),
        );

        // Die Zeit der Animationen wird im Test durch das Pumpen bestimmt und
        // ist damit berechenbar: Der Aufbau des Kalenders braucht 1240 ms (die
        // erste Hälfte ist das Zeichnen, die zweite die Pause, in der der
        // Schriftzug kommt), der Ring eine Umdrehung 2200 ms.
        //
        // Nach dem gewünschten Stand wird **bis zum Ende geblendet** – nicht
        // nur ein Stück weiter. Sonst hinge die halbe Blende des Schriftzugs
        // im Bild, und die frühere Fassung dieses Tests machte genau das: Sie
        // zeigte bei Stand 1,0 ein Bild ganz ohne Schriftzug, und man suchte
        // den Fehler im Bildschirm statt in der Aufnahme.
        await t.pump(Duration(milliseconds: (1240 * stand).round()));
        await t.pump(const Duration(milliseconds: 600));

        // Der Schriftzug wird **nicht** ins Bild gezeichnet – der
        // Framework-Font des Tests hat keine lesbaren Glyphen, und der echte
        // `Crackman` lässt sich im Test nicht in ein Bild zeichnen. Damit er
        // nicht stillschweigend verloren geht, wird hier geprüft, dass er
        // **im Bildschirm** steht: ganz da, und die Blende ist zu Ende.
        //
        // Ohne diese Prüfung wäre ein Fehler am Schriftzug – etwa ein
        // `Opacity`, das nie auf 1 kommt – auf den Aufnahmen nur daran zu
        // sehen, dass etwas fehlt. Und was auf Bildern fehlt, sucht niemand.
        final FadeTransition? schrift = t
            .widgetList<FadeTransition>(
              find.byType(FadeTransition),
            )
            .cast<FadeTransition?>()
            .firstWhere(
              (FadeTransition? e) => e!.opacity.value > 0.0,
              orElse: () => null,
            );
        // Bei den frühen Ständen ist der Schriftzug noch gar nicht da, das ist
        // richtig. Geprüft wird er dort also nicht – dort zählt der Kalender.
        if (schrift != null) {
          expect(schrift.opacity.value, 1.0,
              reason: 'ein angefangener Schriftzug muss zu Ende da sein');
        }

        final RenderRepaintBoundary rand =
            t.renderObject<RenderRepaintBoundary>(find.byKey(schluessel));

        // `runAsync` ist Pflicht, nicht Kosmetik: `toImage` rendert über die
        // Grafikpipeline des Engines, und die wartet auf echte Zeit. Ausserhalb
        // von `runAsync` kehrt dieser Aufruf nie zurück – der Test hängt sich
        // dann ohne jede Fehlermeldung auf, was man nur schwer findet.
        await t.runAsync(() async {
          final ui.Image bild = await rand.toImage();
          final ByteData? daten =
              await bild.toByteData(format: ui.ImageByteFormat.png);

          final Directory ziel = Directory('build/aufnahmen')
            ..createSync(recursive: true);
          File(
            '${ziel.path}/splash_${dunkel ? "dunkel" : "hell"}_$stand.png',
          ).writeAsBytesSync(daten!.buffer.asUint8List());
        });
      });
    }
  }
}
