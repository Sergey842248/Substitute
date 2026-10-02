import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/main.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';

/// Das Logo in der Kopfzeile muss in sein Feld passen – und darin sichtbar
/// bleiben.
///
/// Der gemeldete Fehler: „Das Logo oben links ist viel zu groß dargestellt."
/// Die Ursache war eine Zahl: Das Bild wurde mit `width: 100` geladen und in
/// ein Feld von **45 × 45** Punkten gelegt – in eine Box, die es um mehr als
/// das Doppelte überstieg. Es lief in die Kopfzeile hinein.
///
/// ## Warum beides geprüft wird
///
/// * **Nicht größer als das Feld:** Sonst läuft es über den Rand hinaus, und
///   genau das war die Meldung.
/// * **Nicht kleiner als die Hälfte:** Die andere Richtung ist genauso ein
///   Fehler. Wer die Größe aus dem Ärger heraus auf 10 stellt, hat das Logo
///   nicht repariert, sondern weggeräumt. Deshalb ist die Untergrenze
///   ausdrücklich mit im Test.
///
/// Die Größe steht als `kLogoGroesse` in `main.dart` – beide Seiten dieses
/// Tests lesen dieselbe Zahl, können also nicht auseinanderlaufen.
void main() {
  void aufraeumen() => SyncCoordinator.instance.detach();

  /// Das Logo in der Kopfzeile – an seinem Asset erkannt, nicht an seiner
  /// Position: Die Position ändert sich mit der Bildschirmbreite, das Asset
  /// nicht.
  Finder findeLogo() => find.byWidgetPredicate(
        (Widget w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/img/logo.png',
      );

  Future<void> starteApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanUsername': 'mueller',
      'firstTime': false,
      'languageCode': 'de',
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('bleibt in seinem Feld', (WidgetTester tester) async {
    await starteApp(tester);

    expect(findeLogo(), findsOneWidget);
    final Size groesse = tester.getSize(findeLogo());

    expect(groesse.width, lessThanOrEqualTo(kLogoGroesse),
        reason: 'das Logo ist ${groesse.width} breit, es soll '
            '$kLogoGroesse sein');
    expect(groesse.height, lessThanOrEqualTo(kLogoGroesse),
        reason: 'das Logo ist ${groesse.height} hoch, es soll '
            '$kLogoGroesse sein');

    aufraeumen();
  });

  testWidgets('und ist darin auch zu sehen', (WidgetTester tester) async {
    await starteApp(tester);

    final Size groesse = tester.getSize(findeLogo());
    expect(groesse.width, greaterThanOrEqualTo(kLogoGroesse * 0.9),
        reason: 'das Logo ist nur ${groesse.width} breit – es wurde '
            'weggeräumt statt verkleinert');
    expect(groesse.height, greaterThanOrEqualTo(kLogoGroesse * 0.9),
        reason: 'das Logo ist nur ${groesse.height} hoch');

    aufraeumen();
  });
}
