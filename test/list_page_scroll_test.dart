import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:substitute/models/ListPage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final FontLoader questrial = FontLoader('Questrial')
      ..addFont(rootBundle.load('assets/fonts/questrial.ttf'));
    await questrial.load();
    final FontLoader poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/ProductSans-Light.ttf'));
    await poppins.load();
  });

  /// Bildschirm 390x844, SafeArea oben 47 / unten 34.
  void setUpView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
  }

  Widget buildPage(double contentHeight, {double extraBelow = 0}) {
    return MaterialApp(
      home: Scaffold(
        body: ListPage(
          title: 'Test',
          children: [
            SizedBox(height: contentHeight, child: const Text('INHALT')),
            SizedBox(height: extraBelow, key: const ValueKey('last')),
          ],
        ),
      ),
    );
  }

  ScrollPosition position(WidgetTester tester) {
    final List<Scrollable> scrollables = tester
        .widgetList<Scrollable>(find.byType(Scrollable))
        .where((Scrollable w) => w.controller != null)
        .toList();
    // Der Content-ListView ist der letzte (der erste ist die Kopfzeile).
    return scrollables.last.controller!.position;
  }

  /// Höhe des Inhaltsbereichs, damit [extraBelow] Pixel unterhalb des
  /// Sichtbaren überstehen - die Situation aus dem Bugreport.
  Future<void> pumpWithOverflow(
    WidgetTester tester,
    double extraBelow, {
    double tail = 0,
  }) async {
    await tester.pumpWidget(buildPage(400));
    await tester.pumpAndSettle();
    final double viewport = position(tester).viewportDimension;
    await tester.pumpWidget(buildPage(viewport + extraBelow, extraBelow: tail));
    await tester.pumpAndSettle();
  }

  testWidgets('knapp scrollbare Liste wird ohne Sprung durchgescrollt',
      (WidgetTester tester) async {
    setUpView(tester);
    // 60px Überstand: weniger als die Höhe der Kopfzeile (10% von 844 = 84).
    await pumpWithOverflow(tester, 60);

    expect(position(tester).maxScrollExtent, greaterThan(0),
        reason: 'Testaufbau: es muss etwas zu scrollen geben.');

    final double before = tester.getTopLeft(find.text('INHALT')).dy;

    await tester.drag(find.text('INHALT'), const Offset(0, -40));
    await tester.pumpAndSettle();

    // Nach dem Loslassen muss die Liste unten bleiben. Vor dem Fix klappte die
    // Kopfzeile ein, der sichtbare Bereich wuchs, maxScrollExtent schrumpfte
    // unter den Offset und die Liste sprang auf 0 zurueck.
    expect(position(tester).pixels, greaterThan(10),
        reason: 'Liste springt nach dem Scrollen zurueck: offset='
            '${position(tester).pixels}, maxExtent='
            '${position(tester).maxScrollExtent}');

    // Der Inhalt wandert exakt mit dem Scrollen mit (die Kopfzeile bleibt
    // offen, weil sie mehr Platz wegnehmen würde, als die Liste scrollbar ist).
    final double offset = position(tester).pixels;
    expect(before - tester.getTopLeft(find.text('INHALT')).dy,
        closeTo(offset, 2),
        reason: 'Inhalt ist nicht 1:1 mitgescrollt.');
  });

  testWidgets('lange Liste: Kopfzeile klappt synchron zum Scrollen ein',
      (WidgetTester tester) async {
    setUpView(tester);
    await pumpWithOverflow(tester, 600);

    final double headerBefore =
        tester.getSize(find.byKey(const ValueKey('listpage_header'))).height;

    await tester.drag(find.text('INHALT'), const Offset(0, -40));
    await tester.pumpAndSettle();

    // Die Kopfzeile ist um genau den Betrag eingeklappt, der gescrollt wurde.
    // Dadurch waechst der sichtbare Bereich im selben Mass wie der Offset und
    // `maxScrollExtent` schrumpft nie unter den Offset - die Liste kann also
    // nicht zurueckgeschnellt werden.
    expect(
      tester.getSize(find.byKey(const ValueKey('listpage_header'))).height,
      closeTo(headerBefore - position(tester).pixels, 1),
    );
  });

  testWidgets('lange Liste: das Listenende bleibt erreichbar',
      (WidgetTester tester) async {
    setUpView(tester);
    await pumpWithOverflow(tester, 600, tail: 120);

    await tester.fling(find.text('INHALT'), const Offset(0, -500), 2000);
    await tester.pumpAndSettle();

    // Nach dem Loslassen kommt die Liste am Ende an und der Offset geht nicht
    // verloren: Der unterste Inhalt steht am unteren Bildschirmrand.
    expect(position(tester).pixels,
        closeTo(position(tester).maxScrollExtent, 1));
    expect(tester.getBottomLeft(find.byKey(const ValueKey('last'))).dy,
        lessThanOrEqualTo(844 - 34 + 0.5),
        reason: 'Der letzte Inhalt ist nicht mehr sichtbar.');
  });

  testWidgets('lange Liste: Kopfzeile klappt beim Scrollen weiterhin ein',
      (WidgetTester tester) async {
    setUpView(tester);
    await pumpWithOverflow(tester, 600);

    final Finder header = find.byKey(const ValueKey('listpage_header'));
    expect(tester.getSize(header).height, greaterThan(50));

    await tester.drag(find.text('INHALT'), const Offset(0, -200));
    await tester.pumpAndSettle();

    // Vollstaendig eingeklappt, Inhalt beginnt am oberen Rand.
    expect(tester.getSize(header).height, lessThan(1));
    expect(position(tester).pixels, greaterThan(80),
        reason: 'Der Offset darf beim Einklappen nicht zurueckgesetzt werden.');
  });

  testWidgets('Inhalt, der ohnehin passt, erzeugt keinen Scrollbereich',
      (WidgetTester tester) async {
    setUpView(tester);
    await tester.pumpWidget(buildPage(200));
    await tester.pumpAndSettle();

    expect(position(tester).maxScrollExtent, lessThanOrEqualTo(0));
    await tester.drag(find.text('INHALT'), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(position(tester).pixels, lessThanOrEqualTo(0));
    // Der sichtbare Bereich darf nicht gewachsen sein.
    expect(tester.getTopLeft(find.text('INHALT')).dy, greaterThan(150));
  });
}