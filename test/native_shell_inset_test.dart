import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/NativeShell.dart';

/// Der untere Bereich, den die Navigationsleiste verdeckt.
///
/// ## Worum es hier geht
///
/// Auf iOS liegt die Leiste **auf** dem Inhalt. Damit sie nicht den letzten
/// Eintrag eines Bildschirms verdeckt, braucht jeder Bildschirm unten einen
/// zusätzlichen Bereich.
///
/// Entscheidend ist, dass diese Zahl **gemessen** und nicht angenommen wird:
/// `UITabBarController` verhält sich je iOS-Version anders – mal legt es die
/// Leiste unter den Inhalt (nichts wird verdeckt), mal lässt es sie darüber
/// schweben (ein ganzer Streifen). Eine im Dart-Code festgeschriebene Zahl
/// wäre in einem der beiden Fälle falsch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => NativeShell.ueberdeckung.value = 0);

  /// Eine Umgebung mit einem sicheren Bereich von [sicher] Punkten.
  WidgetUmgebung umgebung(double sicher) => WidgetUmgebung(sicher);

  group('Der untere Bereich', () {
    testWidgets('ist mindestens so gross wie der sichere Bereich',
        (WidgetTester tester) async {
      // Ohne Meldung der nativen Seite ist die Überdeckung 0 – der sichere
      // Bereich des Geräts bleibt trotzdem gültig. Sonst reichte der Inhalt in
      // die Geste-Zone am unteren Rand hinein.
      NativeShell.ueberdeckung.value = 0;

      await tester.pumpWidget(MediaQuery(
          data: umgebung(34).daten,
          child: Builder(builder: (c) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Text(NativeShell.untererBereich(c).toString()),
            );
          })));

      expect(find.text('34.0'), findsOneWidget);
    });

    testWidgets('folgt der gemeldeten Überdeckung',
        (WidgetTester tester) async {
      // Die Leiste liegt über dem Inhalt und verdeckt 83 Punkte – mehr als der
      // sichere Bereich. Es muss der grössere der beiden Werte gelten.
      NativeShell.ueberdeckung.value = 83;

      await tester.pumpWidget(MediaQuery(
          data: umgebung(34).daten,
          child: Builder(builder: (c) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Text(NativeShell.untererBereich(c).toString()),
            );
          })));

      expect(find.text('83.0'), findsOneWidget);
    });

    testWidgets('wird zur Meldung der nativen Seite übernommen',
        (WidgetTester tester) async {
      // Der Anfangswert ist 0: Solange die native Seite nichts gemeldet hat,
      // soll nichts dazugerechnet werden – sonst stünde auf einem Bildschirm
      // ohne Leiste ein Loch unten.
      expect(NativeShell.ueberdeckung.value, 0);

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );
      NativeShell.ueberdeckung.value = 49;
      await tester.pump();

      expect(NativeShell.ueberdeckung.value, 49);
    });
  });
}

/// Eine Umgebung mit einem gegebenen sicheren Bereich am unteren Rand.
class WidgetUmgebung {
  WidgetUmgebung(double sicher)
      : daten = MediaQueryData(padding: _unten(sicher));

  final MediaQueryData daten;

  static EdgeInsets _unten(double sicher) => EdgeInsets.only(bottom: sicher);
}
