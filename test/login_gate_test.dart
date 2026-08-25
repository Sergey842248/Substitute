import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/main.dart';
import 'package:substitute/pages/dashboard/settings/VPlanLogin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Echte Fonts laden, damit die Textbreiten realistisch sind (der
    // Standard-Testfont ist quadratisch und damit viel breiter).
    final FontLoader questrial = FontLoader('Questrial')
      ..addFont(rootBundle.load('assets/fonts/questrial.ttf'));
    await questrial.load();
    final FontLoader poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/ProductSans-Light.ttf'));
    await poppins.load();
  });

  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MyApp(initialPage: VPlanLogin(blockBack: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  double scrollOffset(WidgetTester tester) {
    final Scrollable scrollable = tester.widget<Scrollable>(
      find.byType(Scrollable).first,
    );
    return scrollable.controller!.position.pixels;
  }

  testWidgets('gate login page starts with expanded header (not pushed up)',
      (WidgetTester tester) async {
    await pumpGate(tester);

    final Finder firstInput = find.byType(TextFormField).first;
    expect(firstInput, findsOneWidget);
    final double dy = tester.getTopLeft(firstInput).dy;

    // Erweiterte Kopfzeile: Inhalt beginnt unterhalb von 10% Höhe + Eckenradius
    // + Statusleiste, also deutlich unter 200px bei 844px Bildschirmhöhe.
    // Eingeklappt ("wie heruntergescrollt") läge der erste Input bei ~120px.
    expect(scrollOffset(tester), 0.0);
    expect(dy, greaterThan(150),
        reason: 'Header der Anmeldeseite ist eingeklappt, Inhalt beginnt bei '
            'y=$dy – die Seite sieht hochgeschoben aus.');
  });

  testWidgets('header stays expanded when the keyboard pushes content up',
      (WidgetTester tester) async {
    await pumpGate(tester);

    // Tippe ins Feld und simuliere die geöffnete Tastatur.
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final double dy = tester.getTopLeft(find.byType(TextFormField).first).dy;
    expect(dy, greaterThan(150),
        reason: 'Kopfzeile wurde durch den Tastatur-Scroll eingeklappt '
            '(y=$dy, offset=${scrollOffset(tester)}).');
  });
}
