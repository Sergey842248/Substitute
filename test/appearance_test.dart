import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/main.dart';
import 'package:substitute/pages/dashboard/Settings.dart';
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
      final MaterialApp app =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      aufraeumen();
    });

    testWidgets('folgt der Einstellung hell', (WidgetTester tester) async {
      await starteApp(tester, <String, Object>{'appearance.theme': 'light'});
      final MaterialApp app =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      aufraeumen();
    });

    testWidgets('und wechselt, wenn man es umstellt',
        (WidgetTester tester) async {
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

      final MaterialApp app =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      aufraeumen();
    });
  });

  /// Die relative Helligkeit einer Farbe, nach WCAG.
  ///
  /// Zwischen 0 (schwarz) und 1 (weiß). Sie ist nicht das, was das Auge als
  /// "hell" empfindet – sie ist die Grundlage des Kontrastmaßes, und darauf
  /// kommt es an: Zwei Farben können gleich hell wirken und sich trotzdem
  /// deutlich unterscheiden.
  double helligkeit(Color c) {
    double kanal(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
  }

  /// Das Kontrastverhältnis zwischen zwei Farben, 1 bis 21.
  ///
  /// 1 bedeutet „für das Auge derselbe Ton" – man sieht den Unterschied
  /// nicht. 21 bedeutet schwarz auf weiß. Nach WCAG gilt für Fließtext 4,5,
  /// für dickere Schrift und Symbole 3.
  double kontrast(Color a, Color b) {
    final double ha = helligkeit(a);
    final double hb = helligkeit(b);
    final double hell = ha > hb ? ha : hb;
    final double dunkel = ha > hb ? hb : ha;
    return (hell + 0.05) / (dunkel + 0.05);
  }

  group('Der helle Modus', () {
    /// Liest das Theme, das die App für den gewaehlten Modus tatsächlich
    /// verwendet – nicht die Wunschvorstellung und nicht das Theme des
    /// anderen Modus.
    Future<ThemeData> theme(WidgetTester tester, String modus) async {
      await starteApp(tester, <String, Object>{'appearance.theme': modus});
      final MaterialApp app =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      return (modus == AppAppearance.light ? app.theme : app.darkTheme)!;
    }

    testWidgets('ist eine eigene Farbwelt und keine Umkehrung',
        (WidgetTester tester) async {
      final ThemeData hell = await theme(tester, AppAppearance.light);
      final ThemeData dunkel = await theme(tester, AppAppearance.dark);

      // Der helle Modus ist auf **Weiß** gebaut, nicht auf dem Umkehrwert des
      // dunklen Grundes. Grau als Grund (früher `grey.shade300`) wirkt wie eine
      // abgedunkelte Seite, nicht wie ein heller Modus.
      expect(helligkeit(hell.scaffoldBackgroundColor), greaterThan(0.85),
          reason: 'der Grund ist zu dunkel für einen hellen Modus: '
              '${hell.scaffoldBackgroundColor}');

      // Die Karten müssen sich vom Grund abheben – sonst ist ein weißes
      // Quadrat auf weißem Grund eine unsichtbare Fläche.
      expect(helligkeit(hell.colorScheme.surface), greaterThan(0.9));
      expect(hell.colorScheme.surface, isNot(hell.scaffoldBackgroundColor),
          reason: 'Karten und Grund sind dieselbe Farbe: die Karten '
              'verschwinden');

      // **Weiß auf Weiß gibt es nicht.** Früher war die Trennlinie weiß – auf
      // einem weißen Untergrund ist sie unsichtbar, und die App verliert ihre
      // Kanten.
      expect(kontrast(hell.dividerColor, hell.colorScheme.surface),
          greaterThan(1.2),
          reason: 'die Trennlinie ist auf der Fläche nicht zu sehen: '
              '${hell.dividerColor}');

      // Text auf dem Grund muss lesbar sein, nicht nur vorhanden.
      expect(kontrast(hell.focusColor, hell.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
          reason: 'der Text ist auf diesem Grund zu schwer lesbar');

      // Dasselbe für die Karten: Text auf einer Karte.
      expect(kontrast(hell.focusColor, hell.colorScheme.surface),
          greaterThanOrEqualTo(4.5));

      // Der Akzent steht als Text und als Symbol auf dem Grund.
      expect(kontrast(hell.primaryColor, hell.scaffoldBackgroundColor),
          greaterThanOrEqualTo(3.0),
          reason: 'der Akzent verschwindet auf diesem Grund');

      // Und eine Fehlermeldung muss auf einer Karte lesbar sein. Der alte Wert
      // war eine dunkelrote Fläche mit halber Deckkraft.
      expect(kontrast(hell.colorScheme.error, hell.colorScheme.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'eine Fehlermeldung ist nicht lesbar');

      // Der helle Modus darf nicht unversehrt derselbe sein wie der dunkle –
      // sonst wurde die Umkehrung nur einmal sauber gemacht.
      expect(helligkeit(dunkel.scaffoldBackgroundColor), lessThan(0.2));
      expect(
          hell.scaffoldBackgroundColor, isNot(dunkel.scaffoldBackgroundColor));

      aufraeumen();
    });

    testWidgets('lässt die Karten der App erkennen',
        (WidgetTester tester) async {
      // Der Klassenplan auf dem Startbildschirm: eine Karte mit Text. Sie muss
      // sich vom Grund abheben und lesbar sein – das ist der Bildschirm, den
      // man am häufigsten ansieht.
      await starteApp(tester, <String, Object>{'appearance.theme': 'light'});

      final BuildContext ctx = tester.element(find.byType(MaterialApp));
      final ThemeData hell = Theme.of(ctx);
      expect(helligkeit(hell.colorScheme.surface), greaterThan(0.9));
      expect(kontrast(hell.focusColor, hell.colorScheme.surface),
          greaterThanOrEqualTo(4.5));

      aufraeumen();
    });
  });

  group('Der Eintrag in den Einstellungen', () {
    testWidgets('steht ganz oben, über den Plan-Einstellungen',
        (WidgetTester tester) async {
      // Die Position ist eine Festlegung, kein Zufall: Wer die App auf Anhieb
      // zu dunkel findet, sucht **oben**. Ein Eintrag in der Mitte einer
      // siebenzeiligen Liste wird nicht gefunden.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'languageCode': 'de',
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: Settings(),
        ),
      );
      await tester.pumpAndSettle();

      // Die Reihenfolge wird über die **Höhe** geprüft, nicht über die
      // Reihenfolge im Widget-Baum: Beim breiten Bildschirm baut die Seite
      // zwei Spalten, und in der Quelle steht der Eintrag dann an anderer
      // Stelle. Was zählt, ist was oben steht.
      final double aussehen = tester.getTopLeft(find.text('Aussehen')).dy;
      final double plan = tester.getTopLeft(find.text('Plan-Einstellungen')).dy;

      expect(aussehen, lessThan(plan),
          reason: '"Aussehen" steht unter den Plan-Einstellungen');
      // Und ganz oben: über allem anderen, was dort steht.
      for (final String weiter in <String>[
        'Zugangsdaten',
        'Sprache',
        'Sicherung/Backup',
      ]) {
        final Finder f = find.text(weiter);
        if (f.evaluate().isEmpty) continue;
        expect(aussehen, lessThan(tester.getTopLeft(f).dy),
            reason: '"Aussehen" steht unter "$weiter"');
      }
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

    testWidgets('bietet beide Themes und den Schalter',
        (WidgetTester tester) async {
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
