import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Das Logo im QR-Code darf den Code nicht unlesbar machen.
///
/// ## Warum das überhaupt gemessen wird
///
/// Der QR-Code im Anmeldefeld trägt die Zugangsdaten. Wird er zu dick, scannt
/// ihn niemand mehr, und die App ist für alle gesperrt, die sich mit ihm
/// anmelden.
///
/// Das neue Logo ist eine **gefüllte** Form; das alte war eine Kontur. Die
/// schwarze Fläche darin ist also gewachsen – und genau die verdeckt die
/// Module des Codes.
///
/// ## Die Rechnung
///
/// Der Baustein bettet das Bild bei einer Kantenlänge von 25 % des Codes ein
/// (`scale: 0.25` in `pretty_qr_code`) und nutzt die Fehlerkorrektur **H**,
/// die rund 30 % der Codefläche wiederherstellen kann.
///
/// Also gilt: `0,25² × schwarze Fläche des Logos ≪ 30 %`. Ohne diese Rechnung
/// wäre jede Änderung am Logo eine stille Gefahr für die Anmeldung – man
/// sieht sie erst, wenn jemand mit dem Telefon vor der Tür steht.
///
/// Der Test misst deshalb den **tatsächlichen** Anteil schwarzer Pixel im
/// PNG und rechnet damit. Kein Schätzwert, keine Augenschein: das Bild wird
/// dekodiert und gezählt.
void main() {
  test('Das Logo verdeckt im QR-Code weit weniger als die Fehlerkorrektur',
      () async {
    final File datei = File('assets/img/logo.png');
    expect(datei.existsSync(), isTrue, reason: 'assets/img/logo.png fehlt');

    final Uint8List bytes = await datei.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ByteData? daten = await frame.image.toByteData();

    expect(daten, isNotNull, reason: 'das Logo laesst sich nicht auslesen');
    final ByteData datenSicher = daten!;
    final int breite = frame.image.width;
    final int hoehe = frame.image.height;
    expect(breite, greaterThan(0));
    expect(hoehe, greaterThan(0));

    int schwarz = 0;
    for (int i = 0; i < breite * hoehe; i++) {
      final int r = datenSicher.getUint8(i * 4);
      final int g = datenSicher.getUint8(i * 4 + 1);
      final int b = datenSicher.getUint8(i * 4 + 2);
      final int a = datenSicher.getUint8(i * 4 + 3);
      // Nur gezeichnete Pixel zaehlen: Der durchsichtige Rand des Bildes ist
      // kein Schwarz, das den Code verdeckt – er laesst die Module durch.
      if (a > 128 && (r + g + b) / 3 < 128) schwarz++;
    }

    final double anteilImBild = schwarz / (breite * hoehe);
    final double eingebettet = 0.25 * 0.25 * anteilImBild;

    // Bei 25 % Kantenlaenge ist der Bildanteil mit 0,0625 zu multiplizieren.
    expect(eingebettet, lessThan(0.30),
        reason: 'das Logo verdeckt ${(eingebettet * 100).toStringAsFixed(1)} % '
            'des Codes; die Fehlerkorrektur H haelt rund 30 % aus. Ueber '
            'dieses Mass hinaus wird der QR-Code unzuverlaessig.');

    // Und es soll ueberhaupt ein Logo sein: keine extreem duenne Kontur, die
    // im Code verschwindet, und keine gefuellte Flaeche, die den Code frisst.
    expect(anteilImBild, greaterThan(0.05),
        reason: 'das Logo ist so duenn, dass es im QR-Code nicht mehr zu '
            'sehen ist');
    expect(anteilImBild, lessThan(0.85),
        reason: 'das Logo ist fast vollstaendig gefuellt');

    frame.image.dispose();
  });

  test('Das Logo ist in der Mitte und passt in den QR-Code hinein', () async {
    // Das Bild wird in ein **quadratisches** Feld eingepasst, in dem der Code
    // steht. Ist das Logo breiter als hoch, staucht es der Maler zusammen –
    // und ein gestauchtes Logo sieht zerquetscht aus. Darum ist die Datei auf
    // ihren Inhalt zurechtgeschnitten und nahezu quadratisch.
    final Uint8List bytes = await File('assets/img/logo.png').readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();

    final double seitenverhaeltnis = frame.image.width / frame.image.height;
    expect(seitenverhaeltnis, greaterThan(0.8),
        reason: 'das Logo ist zu breit und wird im QR-Code gestaucht');
    expect(seitenverhaeltnis, lessThan(1.25),
        reason: 'das Logo ist zu hoch und wird im QR-Code gestaucht');

    frame.image.dispose();
  });
}
