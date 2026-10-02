import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/main.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/services/AppAppearance.dart';
import 'package:substitute/services/AppColors.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';

/// Die roten Farben müssen in **beiden** Themes tragen.
///
/// Der gemeldete Fehler: Im hellen Modus war die Fläche einer ausgefallenen
/// Stunde ein fest eingetragenes dunkles Rot mit halber Deckkraft, und der
/// Text darauf erbte die Theme-Farbe – also fast Schwarz. Fast schwarzer Text
/// auf dunklem Rot ist unlesbar, und die Fläche sieht braun aus.
///
/// Geprüft wird deshalb nicht die Farbe selbst, sondern die **Zusage**, die sie
/// macht: Der geerbte Text muss auf der Fläche lesbar sein, und der Aktionston
/// muss auf der Fläche stehen, auf der er steht.
void main() {
  void aufraeumen() => SyncCoordinator.instance.detach();

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

  /// Lädt die App im gewünschten Modus und gibt Theme und Bildschirm zurück.
  Future<BuildContext> starten(WidgetTester tester, String modus) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanUsername': 'mueller',
      'firstTime': false,
      'languageCode': 'de',
      'appearance.theme': modus,
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 700));

    // **Ausdrücklich** beruhigen lassen. Das Theme wird erst asynchron
    // gesetzt (die Einstellung kommt aus den Einstellungen), und der Wechsel
    // läuft über `AnimatedTheme` – also über eine Animation von 200 ms. Nach
    // einem einzigen `pump` stand im Baum noch das *vorherige* Theme. Bei
    // „hell" fällt das nicht auf, weil es dann schon das richtige ist – man
    // prüft also den dunklen Modus und merkt es nicht.
    await tester.pumpAndSettle();

    // **Nicht** der Kontext von `MaterialApp` selbst: Der liegt *über* der
    // App, und `Theme.of` liefert dort den Ersatz aus dem Framework – also
    // immer das helle Standardtheme. Man hätte die hellen Farben geprüft und
    // wäre sich sicher, den dunklen Modus geprüft zu haben.
    return tester.element(find.byType(AnimatedSwitcher).first);
  }

  for (final String modus in <String>[
    AppAppearance.light,
    AppAppearance.dark
  ]) {
    final bool hell = modus == AppAppearance.light;

    group('Im ${hell ? 'hellen' : 'dunklen'} Modus', () {
      testWidgets('ist der Text auf der Hinweisflaeche zu lesen',
          (WidgetTester tester) async {
        final BuildContext ctx = await starten(tester, modus);

        // Die Zeile setzt ihre eigene Schriftfarbe – nicht die geerbte. Geprüft
        // wird genau diese, denn das ist die Zusage: Auf der Hinweisfläche
        // steht lesbare Schrift.
        expect(
          kontrast(AppColors.hinweisFlaeche(ctx), AppColors.hinweisText(ctx)),
          greaterThanOrEqualTo(4.5),
          reason: 'auf ${AppColors.hinweisFlaeche(ctx)} ist '
              '${AppColors.hinweisText(ctx)} nicht zu lesen',
        );

        aufraeumen();
      });

      testWidgets('faellt die ausgefallene Stunde sofort auf',
          (WidgetTester tester) async {
        final BuildContext ctx = await starten(tester, modus);
        final ThemeData t = Theme.of(ctx);

        if (!hell) {
          // **Im dunklen Modus wird das nicht verlangt.** Sein Rot liegt mit
          // halber Deckkraft über der dunklen Karte und hebt sich nur um 1,7:1
          // ab – schwach, aber so sieht es seit jeher aus, und der dunkle
          // Modus ist der, den niemand ändern wollte. Ihn hier auf 3:1 zu
          // ziehen hieße, das Aussehen zu ändern, das man behalten wollte.
          //
          // Lesbar muss es trotzdem sein – und das wird oben geprüft.
          expect(
              kontrast(
                  AppColors.hinweisFlaeche(ctx), AppColors.hinweisText(ctx)),
              greaterThanOrEqualTo(4.5));
          aufraeumen();
          return;
        }

        // **Zwei Forderungen zugleich**, und sie ziehen gegeneinander:
        //
        // * Die Fläche muss sich deutlich vom Grund abheben – unter 3:1
        //   überliest man sie, egal wie schön sie aussieht.
        // * Der Text muss darauf stehen – unter 4,5:1 ist er nicht lesbar.
        //
        // Eine blasse Fläche erfüllt die erste nicht, eine kräftige mit
        // schwarzem Text die zweite nicht. Deshalb wird beides verlangt.
        expect(
          kontrast(AppColors.hinweisFlaeche(ctx), t.scaffoldBackgroundColor),
          greaterThanOrEqualTo(3.0),
          reason: 'die Fläche hebt sich zu wenig vom Grund ab, man überliest '
              'die ausgefallene Stunde',
        );
        expect(
          kontrast(AppColors.hinweisFlaeche(ctx), t.colorScheme.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'die Fläche hebt sich zu wenig von der Karte ab',
        );

        aufraeumen();
      });

      testWidgets('stehen die roten Texte auf der Fläche, auf der sie stehen',
          (WidgetTester tester) async {
        final BuildContext ctx = await starten(tester, modus);
        final ThemeData t = Theme.of(ctx);

        for (final Color ton in <Color>[
          AppColors.aktionston(ctx),
          AppColors.fehlerton(ctx),
        ]) {
          expect(
              kontrast(ton, t.colorScheme.surface), greaterThanOrEqualTo(4.5),
              reason: '$ton ist auf der Karte nicht zu lesen');
          expect(kontrast(ton, t.scaffoldBackgroundColor),
              greaterThanOrEqualTo(4.5),
              reason: '$ton ist auf dem Grund nicht zu lesen');
        }

        aufraeumen();
      });
    });
  }

  testWidgets('bleibt der dunkle Modus, wie er war',
      (WidgetTester tester) async {
    // Vier Werte, die vorher fest eingetragen waren. Sie zu ändern wäre eine
    // Entscheidung, die niemand getroffen hat – der dunkle Modus ist der, den
    // die App seit jeher zeigt, und der Auftrag lautete ausdrücklich, ihn zu
    // lassen.
    final BuildContext ctx = await starten(tester, AppAppearance.dark);
    expect(
        AppColors.hinweisFlaeche(ctx), const Color.fromARGB(158, 119, 18, 18));
    expect(AppColors.aktionston(ctx), Colors.red);
    expect(AppColors.fehlerton(ctx), Colors.red.shade300);
    // Die Fläche behält ihre Deckkraft, und die Schrift dort ist die der App.
    expect(AppColors.hinweisText(ctx), Theme.of(ctx).focusColor);

    aufraeumen();
  });

  testWidgets(' erreicht die Schriftfarbe auch die Texte der Zeile',
      (WidgetTester tester) async {
    // Bisher war nur geprüft, **welche** Farben die App berechnet. Geprüft
    // werden muss, dass die Zeile sie auch verwendet – sonst wäre alles
    // richtig berechnet und trotzdem schwarz geblieben.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: ListItem(
            onClick: () {},
            // Die Farbe steht hier fest: Geprüft wird die Verdrahtung, nicht
            // noch einmal die Wahl der Farbe.
            color: const Color(0xffc62828),
            foreground: Colors.white,
            leading: const Icon(Icons.info),
            // Ein Icon **im Titel** – der Fall, den `ListTile` nicht abdeckt.
            title: const Row(
              children: <Widget>[
                Text('Kurs'),
                Icon(Icons.location_on_rounded, size: 16),
              ],
            ),
            subtitle: const Text('Entfall'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Der Text erbt die Farbe der Zeile, statt die schwarze der App.
    final BuildContext ctx = tester.element(find.text('Entfall'));
    expect(DefaultTextStyle.of(ctx).style.color, Colors.white);
    expect(
        DefaultTextStyle.of(ctx).style.color, isNot(Theme.of(ctx).focusColor));

    // Die Icons ebenso – sonst waere das Symbol schwarz auf Rot. Sowohl das
    // neben der Zeile als auch das im Titel.
    for (final IconData symbol in <IconData>[
      Icons.info,
      Icons.location_on_rounded,
    ]) {
      expect(
        IconTheme.of(tester.element(find.byIcon(symbol))).color,
        Colors.white,
        reason: '$symbol ist schwarz auf der roten Flaeche',
      );
    }

    await tester.pumpWidget(const SizedBox());
  });
}
