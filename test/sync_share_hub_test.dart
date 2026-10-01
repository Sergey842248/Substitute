import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/main.dart';
import 'package:substitute/pages/share/SyncShareHub.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';

/// Sync und Share sind der vierte Eintrag in der Navigationsleiste.
///
/// ## Der gemeldete Header-Fehler
///
/// Als die Seite ihre eigene Kopfzeile mitbrachte, standen **zwei**
/// übereinander: Der Tab liegt bereits unter der Kopfzeile der App, und
/// `ListPage` bringt für sich noch eine mit – 10 % der Bildschirmhöhe für eine
/// Zeile, direkt unter einer 20 % hohen Leiste. Dazu der Text „Sync & Share"
/// am oberen Rand und ein ausklappender Bereich, der mit nichts anfangen
/// konnte.
///
/// Der `Dashboard`-Tab löst das einfach richtig: eine nackte Liste mit fester
/// Höhe, ganz ohne `ListPage`. Die Seite tut es genauso, und genau das prüft
/// der zweite Test unten.
void main() {
  /// Der Koordinator hängt seine Zeitgeber an die App, nicht an einen
  /// Bildschirm – er soll weiterlaufen, auch wenn jemand den Bildschirm
  /// verlässt. Nach dem Test wird er deshalb abgehängt, sonst beschwert sich
  /// das Testpaket über einen Timer, der noch läuft.
  void aufraeumen() => SyncCoordinator.instance.detach();

  Future<void> starteApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanUsername': 'mueller',
      'firstTime': false,
      'languageCode': 'de',
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Die **Einträge** der Navigationsleiste, erkennbar an ihrer Breite.
  ///
  /// Die Leiste zeigt zu jedem Eintrag zwei Symbole: das Icon (28 breit) und die
  /// „aktiv"-Markierung darunter (13 breit). Nur die 28 zählen als Einträge –
  /// über alle Symbole zu zählen ergäbe eine Zahl, die sich bei einer Änderung
  /// an der Markierung ändert, ohne dass sich ein Eintrag geändert hätte.
  final Finder navigationsEintraege = find.byWidgetPredicate(
    (Widget w) => w is SvgPicture && w.width == 28,
  );

  /// Das Sync-Symbol der Leiste. Gesucht wird nach dem **Asset**, nicht nach
  /// der Position: Eine Nummer wäre stumm falsch, sobald sich die Reihenfolge
  /// ändert.
  final Finder syncSymbol = find.byWidgetPredicate(
    (Widget w) => w is SvgPicture && w.toString().contains('sync.svg'),
  );

  group('Die Navigationsleiste', () {
    testWidgets('zeigt den Sync-Eintrag', (WidgetTester tester) async {
      await starteApp(tester);
      expect(navigationsEintraege, findsNWidgets(4),
          reason: 'vier Einträge: Start, Suche, Dashboard, Sync & Share');
      expect(syncSymbol, findsOneWidget,
          reason: 'das Sync-Symbol fehlt in der Leiste');
      aufraeumen();
    });

    testWidgets('der Sync-Eintrag steht hinten, nach dem Dashboard',
        (WidgetTester tester) async {
      await starteApp(tester);
      // Ein zusätzlicher Bildschirm, den man aus Versehen mitnimmt, gehört
      // nicht neben die Leiterstufen.
      final List<SvgPicture> eintraege = tester
          .widgetList<SvgPicture>(navigationsEintraege)
          .toList();
      expect(eintraege.last.toString(), contains('sync.svg'),
          reason: 'der Sync-Eintrag ist nicht der letzte');
      aufraeumen();
    });

    testWidgets('und er führt zum Sync-Menü', (WidgetTester tester) async {
      await starteApp(tester);
      await tester.tap(syncSymbol);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SyncShareHub), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Teilen'), findsOneWidget);
      expect(find.text('Shares finden'), findsOneWidget);
      aufraeumen();
    });
  });

  group('Die Seite', () {
    testWidgets('hat keine eigene Kopfzeile – sonst stehen zwei übereinander',
        (WidgetTester tester) async {
      await starteApp(tester);
      await tester.tap(syncSymbol);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Das ist der gemeldete Fehler, als Zusicherung festgehalten: Die Seite
      // bringt keine eigene Kopfzeile mit, weil sie als Tab bereits unter der
      // der App liegt.
      expect(find.byKey(const ValueKey('listpage_header')), findsNothing,
          reason: 'eine zweite Kopfzeile über dem Tab');
      aufraeumen();
    });

    testWidgets('bietet die drei Wege in der richtigen Reihenfolge',
        (WidgetTester tester) async {
      await starteApp(tester);
      await tester.tap(syncSymbol);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Die Reihenfolge ist Absicht: erst „mir" (eigene Geräte), dann „uns"
      // (mit anderen teilen), dann deren Angebote durchsuchen. Als [Map]
      // gebaut würde sie sie nicht garantieren.
      final double syncY = tester.getTopLeft(find.text('Sync')).dy;
      final double shareY = tester.getTopLeft(find.text('Teilen')).dy;
      final double browseY = tester.getTopLeft(find.text('Shares finden')).dy;
      expect(syncY, lessThan(shareY));
      expect(shareY, lessThan(browseY));
      aufraeumen();
    });

    testWidgets('jeder Weg führt weiter', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: const SyncShareHub(),
        ),
      );
      await tester.pumpAndSettle();

      // Ohne das könnte ein Eintrag schlicht nichts tun, und es fällt erst
      // beim Tippen auf.
      final Iterable<InkWell> beruehrungsflaechen =
          tester.widgetList<InkWell>(find.byType(InkWell));
      expect(beruehrungsflaechen, isNotEmpty);
    });
  });
}
