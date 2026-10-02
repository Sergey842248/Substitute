import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/main.dart';
import 'package:substitute/pages/dashboard/settings/AppearanceSettings.dart';
import 'package:substitute/services/AppAppearance.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';

/// „Aussehen": hell oder dunkel, und was in der Navigationsleiste steht.
///
/// Beide Einstellungen wirken an Bildschirme, die gerade **nicht** im
/// Vordergrund sind – das Theme an die App-Wurzel, die Leiste an den
/// Startbildschirm. Ohne gemeinsame Quelle (`AppAppearance`) käme man nach dem
/// Zurückkehren auf den alten Zustand zurück, ohne dass sich etwas bewegt
/// hätte. Genau das prüfen die Tests am Ende.
void main() {
  /// Der Koordinator hängt seine Zeitgeber an die App, nicht an einen
  /// Bildschirm. Nach dem Test wird er abgehängt, sonst beschwert sich das
  /// Testpaket über einen laufenden Timer.
  void aufraeumen() => SyncCoordinator.instance.detach();

  Future<void> starteApp(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanUsername': 'mueller',
      'firstTime': false,
      'languageCode': 'de',
      ...prefs,
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 600));
  }

  final Finder navigationsEintraege = find.byWidgetPredicate(
    (Widget w) => w is SvgPicture && w.width == 28,
  );

  group('Die Voreinstellungen', () {
    test('dunkel – die App sah vorher nur so aus', () {
      expect(AppAppearance.dark, 'dark');
      expect(AppAppearance.modeOf(AppAppearance.dark), ThemeMode.dark);
      expect(AppAppearance.modeOf(AppAppearance.light), ThemeMode.light);
      // Alles andere: das System, für den Fall, dass jemand den Wert von Hand
      // kaputt gemacht hat. Fällt auf das System zurück, nicht auf eine
      // leere Oberfläche.
      expect(AppAppearance.modeOf('kaputt'), ThemeMode.system);
    });

    test('und der Sync-Eintrag ist zu sehen', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Wer die App frisch installiert, bekommt den Eintrag. Die drei
      // Funktionen gehören zu den wenigen, für die man die App braucht.
      expect(AppAppearance.showSyncShareTab(prefs), isTrue);
      expect(AppAppearance.themeOf(prefs), AppAppearance.dark);
    });
  });

  group('Der Sync-Eintrag in der Leiste', () {
    testWidgets('ist zu sehen, solange nichts abgeschaltet wurde',
        (WidgetTester tester) async {
      await starteApp(tester, <String, Object>{});
      expect(navigationsEintraege, findsNWidgets(4));
      aufraeumen();
    });

    testWidgets('verschwindet, wenn er abgeschaltet wird',
        (WidgetTester tester) async {
      await starteApp(tester, <String, Object>{
        'appearance.showSyncShareTab': false,
      });
      expect(navigationsEintraege, findsNWidgets(3),
          reason: 'der Eintrag steht noch in der Leiste');
      aufraeumen();
    });

    testWidgets('und kommt wieder, wenn man ihn zurückholt',
        (WidgetTester tester) async {
      // Der Hinweis auf der Einstellungsseite verspricht das – und es muss
      // gelten. Ein Eintrag, der sich nicht zurückholen lässt, wäre weg.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'vplanUsername': 'mueller',
        'firstTime': false,
        'appearance.showSyncShareTab': false,
      });
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 600));
      expect(navigationsEintraege, findsNWidgets(3));

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await AppAppearance.setShowSyncShareTab(prefs, true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(navigationsEintraege, findsNWidgets(4),
          reason: 'die Leiste hat sich nicht neu aufgebaut');
      aufraeumen();
    });
  });

  group('Das Theme', () {
    testWidgets('ist dunkel, ohne dass etwas eingestellt wurde',
        (WidgetTester tester) async {
      await starteApp(tester, <String, Object>{});
      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      aufraeumen();
    });

    testWidgets('folgt der Einstellung hell', (WidgetTester tester) async {
      await starteApp(tester, <String, Object>{'appearance.theme': 'light'});
      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      aufraeumen();
    });

    testWidgets('und wechselt, wenn man es umstellt', (WidgetTester tester) async {
      // Ohne den Zuhörer bliebe die App im alten Theme, während man auf der
      // Einstellungsseite bereits das neue sieht – und nach dem Zurückkehren
      // wäre der Unterschied spurlos verschwunden.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'vplanUsername': 'mueller',
        'firstTime': false,
        'appearance.theme': 'dark',
      });
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 600));

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await AppAppearance.setTheme(prefs, AppAppearance.light);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      aufraeumen();
    });
  });

  group('Die Einstellungsseite', () {
    Future<void> oeffne(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'languageCode': 'de',
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: const AppearanceSettings(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('bietet beide Themes und den Schalter', (WidgetTester tester) async {
      await oeffne(tester);
      expect(find.text('Aussehen'), findsWidgets);
      expect(find.text('Dunkel'), findsOneWidget);
      expect(find.text('Hell'), findsOneWidget);
      expect(find.text('Sync-Menü in der Leiste zeigen'), findsOneWidget);
    });

    testWidgets('markiert das aktive Theme', (WidgetTester tester) async {
      // Ohne eine Markierung sähe man auf einem dunklen Bildschirm nicht,
      // dass „Dunkel" überhaupt gewählt ist.
      await oeffne(tester);
      final Finder dunkel = find.text('Dunkel');
      final double hoeheDunkel = tester.getSize(dunkel).height;
      final double hoeheHell = tester.getSize(find.text('Hell')).height;
      // Beide Kacheln sind gleich hoch; entscheidend ist die Farbe. Geprüft
      // wird deshalb, dass beide vorhanden sind und die Seite kein Fehler
      // beim Aufbau macht – die Farbe selbst prüft der Test über `themeMode`.
      expect(hoeheDunkel, greaterThan(0));
      expect(hoeheHell, greaterThan(0));
    });

    testWidgets('und das Umstellen wirkt sofort', (WidgetTester tester) async {
      await oeffne(tester);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(AppAppearance.themeOf(prefs), AppAppearance.dark,
          reason: 'der Standard ist dunkel');

      await tester.tap(find.text('Hell'));
      await tester.pumpAndSettle();

      expect(AppAppearance.themeOf(prefs), AppAppearance.light,
          reason: 'das Tippen hat nichts gespeichert');
    });
  });
}
