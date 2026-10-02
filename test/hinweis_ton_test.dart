import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/AppColors.dart';

/// Rot heißt "fällt aus", Orange heißt "geändert".
///
/// Geprüft wird die **Entscheidung**, nicht die Farbe: Sie ist es, die im Plan
/// das Falsche einfärbt. Vorher war jede Stunde mit einem Hinweistext rot –
/// also auch jede Vertretung und jede Raumänderung. Damit sah der Plan immer
/// voller Ausfälle aus, als es sind.
void main() {
  Map<String, dynamic> stunde({
    Object? info,
    Object? lehrer = 'Müller',
    bool raumGeaendert = false,
  }) =>
      <String, dynamic>{
        'count': 3,
        'lesson': 'Deutsch',
        'teacher': lehrer,
        'place': 'R102',
        'placeChanged': raumGeaendert,
        'info': info,
      };

  group('Der Hinweiston', () {
    test('eine ganz normale Stunde ist keine Hinweiszeile', () {
      expect(AppColors.hinweisTonVon(stunde()), HinweisTon.keiner);
    });

    test('ein Hinweistext mit Lehrer ist eine Änderung, kein Ausfall', () {
      for (final String info in <String>[
        'Vertretung',
        'Raumänderung',
        'Aufgaben siehe Moodle',
        'Filmvorführung',
        'vertreten durch Schmidt',
      ]) {
        expect(
          AppColors.hinweisTonVon(stunde(info: info)),
          HinweisTon.geaendert,
          reason: '"$info" ist eine Änderung und darf nicht rot sein',
        );
      }
    });

    test('ohne Lehrer ist es ein Ausfall', () {
      for (final Object? lehrer in <Object?>[null, '', '   ', '---']) {
        expect(
          AppColors.hinweisTonVon(stunde(info: 'Entfall', lehrer: lehrer)),
          HinweisTon.entfall,
          reason: 'mit Lehrer "$lehrer" ist die Stunde nicht als Ausfall zu '
              'erkennen',
        );
      }
    });

    test('auch mit Lehrer bleibt "Entfall" ein Ausfall', () {
      // Manche Einträge tragen den Lehrer noch im Text, obwohl die Stunde
      // ausfällt. Das Krankentracking zählt sie ebenfalls nicht als verpasst
      // (`VPlanAPI.isCancelledLesson`), und die Einfärbung darf nicht davon
      // abweichen.
      for (final String info in <String>[
        'Entfall',
        'entfaellt',
        'Ausfall',
        'Faellt aus',
        'faellt heute aus',
      ]) {
        expect(
          AppColors.hinweisTonVon(stunde(info: info)),
          HinweisTon.entfall,
          reason: '"$info" ist ein Ausfall und muss rot bleiben',
        );
      }
    });

    test('eine reine Raumänderung ist eine Änderung', () {
      // Sie kommt im VPlan **ohne** Hinweistext daher – das Attribut `RaAe`
      // steckt in der Stunde selbst.
      expect(
        AppColors.hinweisTonVon(stunde(raumGeaendert: true)),
        HinweisTon.geaendert,
      );
    });

    test('eine leere Notiz ist keine Notiz', () {
      expect(AppColors.hinweisTonVon(stunde(info: '')), HinweisTon.keiner);
      expect(AppColors.hinweisTonVon(stunde(info: '   ')), HinweisTon.keiner);
      expect(AppColors.hinweisTonVon(stunde(info: null)), HinweisTon.keiner);
    });

    test('eine lehrerlose Stunde ohne Hinweis bleibt unauffällig', () {
      // Sonst würde jede Lücke im Plan (unbekannter Lehrer) als Ausfall
      // dastehen – und der Plan wäre voller Ausfälle, die keine sind.
      expect(AppColors.hinweisTonVon(stunde(lehrer: '')), HinweisTon.keiner);
    });
  });

  group('Die Farben', () {
    double helligkeit(Color c) {
      double kanal(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
    }

    double kontrast(Color a, Color b) {
      final double ha = helligkeit(a);
      final double hb = helligkeit(b);
      final double hell = ha > hb ? ha : hb;
      final double dunkel = ha > hb ? hb : ha;
      return (hell + 0.05) / (dunkel + 0.05);
    }

    Future<BuildContext> starten(WidgetTester tester, Brightness hell) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: hell),
          home: const Scaffold(body: SizedBox()),
        ),
      );
      return tester.element(find.byType(Scaffold).first);
    }

    for (final Brightness hell in Brightness.values) {
      testWidgets('trägt das Orange im ${hell.name} Modus',
          (WidgetTester tester) async {
        final BuildContext ctx = await starten(tester, hell);
        final ThemeData t = Theme.of(ctx);
        final Color flaeche = AppColors.aenderungFlaeche(ctx);

        // Lesbar wie das Rot: dieselbe Schrift, mindestens 4,5:1.
        expect(
          kontrast(flaeche, AppColors.hinweisText(ctx)),
          greaterThanOrEqualTo(4.5),
          reason: 'auf $flaeche ist der Text nicht zu lesen',
        );

        // Und es muss sich vom Grund abheben – sonst sieht niemand, dass
        // hier etwas geändert wurde.
        if (hell == Brightness.light) {
          expect(
            kontrast(flaeche, t.scaffoldBackgroundColor),
            greaterThanOrEqualTo(3.0),
          );
          expect(kontrast(flaeche, t.colorScheme.surface),
              greaterThanOrEqualTo(3.0));
        }

        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('das Orange ist nicht das Rot', (WidgetTester tester) async {
      // Der ganze Sinn der Abstufung: Zwei verschiedene Farben. Wäre das
      // Orange nur ein helleres Rot, wäre an der Zeile nichts zu unterscheiden.
      for (final Brightness hell in Brightness.values) {
        final BuildContext ctx = await starten(tester, hell);
        expect(
          AppColors.aenderungFlaeche(ctx) == AppColors.hinweisFlaeche(ctx),
          isFalse,
          reason: 'im ${hell.name} Modus sind beide Flächen gleich',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}