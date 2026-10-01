import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/main.dart';
import 'package:substitute/pages/share/SyncShareHub.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';

/// Sync und Share müssen einen eigenen Platz in der Navigationsleiste haben.
///
/// Vorher lagen die drei Funktionen als Einträge in den Einstellungen – tief in
/// einer Liste, die man aufsuchen musste. Das trifft besonders die, für die man
/// die App braucht: Wer ein zweites Gerät koppeln will, tippt nicht zuerst auf
/// „Einstellungen".
void main() {
  Future<void> starteApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanUsername': 'mueller',
      'firstTime': false,
      'languageCode': 'de',
    });
    await tester.pumpWidget(
      const MyApp(),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Der Koordinator hängt seine Zeitgeber an die App, nicht an einen
  /// Bildschirm – er soll weiterlaufen, auch wenn jemand den Bildschirm
  /// verlässt. Nach dem Test wird er deshalb abgehängt, sonst beschwert sich
  /// das Testpaket über einen Timer, der noch läuft.
  void aufraeumen() => SyncCoordinator.instance.detach();

  /// Das Symbol des neuen Eintrags.
  ///
  /// Gesucht wird nach dem **Asset**, nicht nach der Position: Eine Nummer wäre
  /// stumm falsch, sobald sich die Reihenfolge der Leiste ändert.
  final Finder syncSymbol = find.byWidgetPredicate(
    (Widget w) => w is SvgPicture && w.toString().contains('sync.svg'),
  );

  group('Die Navigationsleiste', () {
    testWidgets('hat einen vierten Eintrag', (WidgetTester tester) async {
      await starteApp(tester);
      // Die Fußzeile zeigt zu jedem Eintrag zwei Symbole: das Icon und die
      // „aktiv"-Markierung. Vier Einträge also acht Symbole – vorher waren es
      // sechs, weil es nur drei Einträge gab.
      expect(find.byType(SvgPicture), findsNWidgets(8));
      expect(syncSymbol, findsOneWidget, reason: 'das neue Symbol fehlt');
      aufraeumen();
    });

    testWidgets('die Leiste führt zu „Sync & Share"', (WidgetTester tester) async {
      await starteApp(tester);
      expect(syncSymbol, findsOneWidget);
      await tester.tap(syncSymbol);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SyncShareHub), findsOneWidget);
      expect(find.text('Sync & Share'), findsWidgets);
      aufraeumen();
    });
  });

  group('Die Seite bietet die drei Wege', () {
    testWidgets('mit Überschrift und Erklärung', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: const SyncShareHub(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync & Share'), findsWidgets);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Teilen'), findsOneWidget);
      expect(find.text('Shares finden'), findsOneWidget);
    });

    testWidgets('in der Reihenfolge: erst die eigenen Geräte', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: const SyncShareHub(),
        ),
      );
      await tester.pumpAndSettle();

      // Die Reihenfolge ist Absicht: erst „mir" (eigene Geräte), dann „uns"
      // (mit anderen teilen), dann deren Angebote durchsuchen. Sie als [Map]
      // zu bauen würde sie nicht garantieren.
      final List<String> reihenfolge = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((ListTile t) => (t.title as Padding).child.toString().length.toString())
          .toList();
      expect(reihenfolge, hasLength(3));

      final double syncY = tester.getTopLeft(find.text('Sync')).dy;
      final double shareY = tester.getTopLeft(find.text('Teilen')).dy;
      final double browseY = tester.getTopLeft(find.text('Shares finden')).dy;
      expect(syncY, lessThan(shareY));
      expect(shareY, lessThan(browseY));
    });

    testWidgets('jeder Eintrag führt weiter', (WidgetTester tester) async {
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
      final Iterable<ListTile> kacheln = tester.widgetList<ListTile>(find.byType(ListTile));
      for (final ListTile kachel in kacheln) {
        expect(kachel.onTap, isNotNull, reason: 'eine Kachel ohne onTap tut nichts');
      }
    });
  });
}
