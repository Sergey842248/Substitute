import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/main.dart';

/// Nur zum Ansehen: die Kopfzeile als Bild.
void main() {
  testWidgets('kopf', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanUsername': 'mueller',
      'firstTime': false,
      'languageCode': 'de',
    });

    final GlobalKey schluessel = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: schluessel, child: const MyApp()),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final RenderRepaintBoundary rand =
        schluessel.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image bild = await rand.toImage(pixelRatio: 2.0);
    final ByteData? daten =
        await bild.toByteData(format: ui.ImageByteFormat.png);
    // Nur die oberen 25% – die Kopfzeile.
    final ByteData ganz = daten!;
    final ui.Image oben = await _ausschnitt(ganz, 0, 0,
        ganz.lengthInBytes == 0 ? 0 : bild.width, (bild.height * 0.28).round());
    File('/tmp/kopf.png').writeAsBytesSync(
      (await oben.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List(),
    );
    bild.dispose();
    oben.dispose();
  });
}

Future<ui.Image> _ausschnitt(ByteData png, int x, int y, int b, int h) async {
  // Absichtlich einfach: das ganze Bild wird geschrieben, die Kopfzeile ist
  // ohnehin oben.
  final ui.Codec codec = await ui.instantiateImageCodec(
    png.buffer.asUint8List(),
  );
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}