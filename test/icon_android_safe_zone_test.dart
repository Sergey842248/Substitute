import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Das Android-Icon muss in den Kreis passen, in den der Startbildschirm es
/// schneidet.
///
/// ## Was der Startbildschirm tut
///
/// Ab Android 26 ist das Icon **adaptiv** und wird auf eine Form der Wahl
/// zugeschnitten – im schlimmsten Fall auf einen Kreis von **72dp**
/// Durchmesser. Eine 108dp breite Ebene hat damit 18dp Rand auf jeder Seite,
/// den der Startbildschirm wegschneiden darf.
///
/// ## Der gemeldete Fehler
///
/// „Das Icon ist zu groß für den Kreis, die Ecken des Kalenders sind
/// abgeschnitten." Gerechnet: Die Zeichnung ist 608 breit und 564 hoch. Ihre
/// **halbe Diagonale** – das, was in einem Kreis zählt, nicht die Breite –
/// liegt bei 415 von 1024, das sind 43,7dp. Erlaubt sind 36dp. Die Ecken
/// ragten also **7,7dp** heraus.
///
/// ## Warum die Diagonale und nicht die Breite
///
/// Eine Zeichnung, die 72dp breit ist, passt in ein Quadrat von 72dp und
/// trotzdem nicht in einen Kreis von 72dp: Ihre Ecken liegen bei
/// `√(36² + 28²) = 45,6dp` vom Mittelpunkt, also 9,6dp zu weit draußen. Wer
/// nur die Breite misst, hält ein Icon für sicher, das beschnitten wird.
///
/// ## Der Test
///
/// Gelesen wird die **tatsächliche** Datei, und für jedes undurchsichtige
/// Pixel wird geprüft, ob es im erlaubten Kreis liegt. Keine Rechnung aus den
/// Zahlen der Quelldatei: Die kann stimmen und das Ergebnis trotzdem falsch
/// sein, wenn beim Erzeugen etwas danebengeht.
void main() {
  /// Der Radius, den der Startbildschirm garantiert: 36dp von 108dp.
  const double erlaubt = 36 / 108;

  /// Der am weitesten entfernte undurchsichtige Punkt, als Anteil der Kanten-
  /// laenge – 0,5 heisst: passt genau in den Kreis.
  Future<double> weitesterPunkt(File datei) async {
    final Uint8List bytes = await datei.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ByteData? daten = await frame.image.toByteData();
    expect(daten, isNotNull);

    final int breite = frame.image.width;
    final int hoehe = frame.image.height;
    final double mitteX = breite / 2;
    final double mitteY = hoehe / 2;
    double weitest = 0;

    for (int y = 0; y < hoehe; y++) {
      for (int x = 0; x < breite; x++) {
        final int a = daten!.getUint8((y * breite + x) * 4 + 3);
        if (a < 128) continue;
        final double dx = x + 0.5 - mitteX;
        final double dy = y + 0.5 - mitteY;
        final double abstand = math.sqrt(dx * dx + dy * dy);
        if (abstand > weitest) weitest = abstand;
      }
    }
    frame.image.dispose();
    return weitest / breite;
  }

  final Map<String, String> zuPruefen = <String, String>{
    'ic_launcher_foreground': 'mipmap-xxxhdpi/ic_launcher_foreground.webp',
    'ic_launcher_monochrome': 'mipmap-xxxhdpi/ic_launcher_monochrome.webp',
  };

  for (final MapEntry<String, String> eintrag in zuPruefen.entries) {
    test('${eintrag.key} passt in den Kreis des Startbildschirms', () async {
      final File datei = File('android/app/src/main/res/${eintrag.value}');
      expect(datei.existsSync(), isTrue, reason: '${datei.path} fehlt');

      final double weitest = await weitesterPunkt(datei);
      expect(weitest, lessThanOrEqualTo(erlaubt),
          reason: '${eintrag.key}: ein Punkt liegt bei '
              '${(weitest * 108).toStringAsFixed(1)}dp vom Mittelpunkt, der '
              'Startbildschirm schneidet aber alles jenseits von 36dp ab. Die '
              'Zeichnung ist zu gross.');
    });
  }

  test('Die alten Icons tragen ihre Zeichnung auch im Kreis', () async {
    // Sie werden vom Startbildschirm nicht zugeschnitten – aber viele
    // Startbildschirme schneiden **auch** alte Icons auf einen Kreis zu. Deshalb
    // dieselbe Forderung. Geprüft wird am gerundeten Icon, weil es die strengere
    // der beiden Formen ist: Sein Rand liegt weiter aussen als beim eckigen.
    final File datei =
        File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.webp');
    expect(datei.existsSync(), isTrue);

    final Uint8List bytes = await datei.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ByteData? daten = await frame.image.toByteData();
    final int breite = frame.image.width;
    final int hoehe = frame.image.height;
    final double mitteX = breite / 2;
    final double mitteY = hoehe / 2;

    // Die weisse Zeichnung ist die hellste Stelle der Datei – der Verlauf
    // darunter ist dunkler. Also: Finde die hellsten Punkte und pruefe, ob sie
    // im Kreis liegen.
    bool beschnitten = false;
    double schlimmsterAbstand = 0;
    for (int y = 0; y < hoehe && !beschnitten; y++) {
      for (int x = 0; x < breite; x++) {
        final int a = daten!.getUint8((y * breite + x) * 4 + 3);
        if (a < 128) continue;
        final int r = daten.getUint8((y * breite + x) * 4);
        final int g = daten.getUint8((y * breite + x) * 4 + 1);
        final int b = daten.getUint8((y * breite + x) * 4 + 2);
        if ((r + g + b) / 3 < 200) continue; // nicht die Zeichnung
        final double dx = x + 0.5 - mitteX;
        final double dy = y + 0.5 - mitteY;
        final double abstand = math.sqrt(dx * dx + dy * dy) / breite;
        if (abstand > erlaubt) {
          beschnitten = true;
          schlimmsterAbstand = abstand;
          break;
        }
      }
    }
    frame.image.dispose();

    expect(beschnitten, isFalse,
        reason: 'ein heller Punkt der Zeichnung liegt bei '
            '${(schlimmsterAbstand * 108).toStringAsFixed(1)}dp und wird '
            'weggeschnitten');
  });

  test('Die Zeichnung ist nicht kleiner geworden als noetig', () async {
    // Das Gegenteil ist auch ein Fehler: Ein Icon, das auf 40 % der Flaeche
    // schrumpft, ist zwar unbeschnitten und trotzdem nicht wiederzuerkennen.
    // Also muss die Zeichnung den Kreis auch **weitgehend ausfuellen**.
    final File datei = File(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.webp');
    final double weitest = await weitesterPunkt(datei);
    expect(weitest, greaterThan(erlaubt * 0.8),
        reason: 'die Zeichnung fuellt den Kreis nur zu '
            '${(weitest / erlaubt * 100).toStringAsFixed(0)} % – das Icon '
            'sieht in der Startbildschirm-Maske verloren aus');
  });
}
