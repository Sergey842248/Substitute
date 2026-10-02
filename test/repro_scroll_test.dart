import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:substitute/models/ListPage.dart';

/// Regressionstest fuer den Bugreport "Bei einer bestimmten Inhaltslaenge
/// springt die Liste beim Scrollen wieder nach oben".
///
/// [ListPage] laesst die Kopfzeile beim Scrollen einklappen und gibt thereby
/// Sichtflaeche frei. Wenn dabei der Scrollbereich unter den aktuellen Offset
/// schrumpft, klemmt Flutter den Offset zurueck und die Liste schnellt nach
/// oben - je nach Inhaltslaenge stark oder gar nicht.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildPage(double contentHeight) {
    return MaterialApp(
      home: Scaffold(
        body: ListPage(
          title: 'Test',
          children: [
            SizedBox(height: contentHeight, child: const Text('INHALT')),
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
    return scrollables.last.controller!.position;
  }

  testWidgets('Sweep: die Liste springt bei keiner Inhaltslaenge zurueck',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    // Die Inhaltslaenge wird in kleinen Schritten ueber den kritischen Bereich
    // hinweg variiert - dort trat der Bug auf.
    for (final double extra in <double>[
      0.0, 20.0, 40.0, 60.0, 80.0, 90.0, 100.0, 110.0, 120.0, 140.0, 160.0,
      180.0, 200.0, 250.0, 300.0, 400.0, 700.0, 1200.0,
    ]) {
      await tester.pumpWidget(buildPage(400));
      await tester.pumpAndSettle();
      final double viewport = position(tester).viewportDimension;
      await tester.pumpWidget(buildPage(viewport + extra));
      await tester.pumpAndSettle();

      // Echtes Finger-Scrollen in kleinen Schritten, wie beim Tippen.
      final TestGesture gesture = await tester.startGesture(const Offset(195, 500));
      double highest = 0;
      for (int i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(0, -8));
        await tester.pump(const Duration(milliseconds: 16));
        final ScrollPosition pos = position(tester);
        final double pixels = pos.pixels;
        // Ueber den Scrollbereich hinaus federt BouncingScrollPhysics ganz
        // normal weiter - das ist gewolltes Overscroll und kein Ruecksprung.
        // Interessant ist nur, ob der Offset innerhalb des Scrollbereichs
        // zurueckfaellt.
        final double inRange = pixels > pos.maxScrollExtent
            ? pos.maxScrollExtent
            : pixels;
        expect(inRange, greaterThanOrEqualTo(highest - 0.5),
            reason: 'Offset faellt mitten im Scrollen zurueck '
                '(extra=$extra, Schritt=$i, pixels=$pixels, vorher=$highest)');
        if (inRange > highest) highest = inRange;
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Auch nach dem Loslassen (Federung) bleibt die Position erhalten:
      // Die Liste steht noch dort, wo sie beim Ziehen hingescrollt war.
      final double pixels = position(tester).pixels;
      expect(pixels, greaterThanOrEqualTo(highest - 1),
          reason: 'Die Liste springt nach dem Loslassen nach oben '
              '(extra=$extra, pixels=$pixels, vorher=$highest)');
    }
  });

  testWidgets('Bei knapp scrollbarem Inhalt bleibt die Kopfzeile offen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildPage(400));
    await tester.pumpAndSettle();
    final double viewport = position(tester).viewportDimension;
    // 60px Ueberstand: weniger als die doppelte Kopfzeilenhoehe (2 * 84).
    await tester.pumpWidget(buildPage(viewport + 60));
    await tester.pumpAndSettle();

    final Finder header = find.byKey(const ValueKey('listpage_header'));
    final double before = tester.getSize(header).height;

    // 60px Ueberstand, also 60 - 18px Touch-Slop = 42px echter Scrollweg.
    await tester.drag(find.text('INHALT'), const Offset(0, -60));
    await tester.pumpAndSettle();

    // Zu knapp scrollbar: Die Kopfzeile darf nicht eingeklappt werden, sonst
    // verliert die Liste Sichtflaeche, die sie zum Scrollen braucht. Die
    // Kopfzeile bleibt also unveraendert und der Offset laeuft nicht in den
    // zurueckgeklemmten Bereich.
    expect(tester.getSize(header).height, closeTo(before, 1));
    expect(position(tester).pixels, closeTo(42, 1));
  });

  testWidgets('Bei langem Inhalt klappt die Kopfzeile weiterhin ein',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildPage(400));
    await tester.pumpAndSettle();
    final double viewport = position(tester).viewportDimension;
    await tester.pumpWidget(buildPage(viewport + 600));
    await tester.pumpAndSettle();

    final Finder header = find.byKey(const ValueKey('listpage_header'));
    final double before = tester.getSize(header).height;

    await tester.drag(find.text('INHALT'), const Offset(0, -40));
    await tester.pumpAndSettle();

    // 1:1 mit dem Offset: Jedes eingeklappte Pixel holt ein Pixel Sichtflaeche
    // zurueck, der Scrollbereich schrumpft nie unter den Offset.
    expect(before - tester.getSize(header).height,
        closeTo(position(tester).pixels, 1));
  });
}
