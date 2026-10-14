import 'package:substitute/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:substitute/introduction/introscreen.dart';

import 'package:substitute/models/Button.dart';
import 'package:substitute/models/ModalBottomSheet.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'models/swipe_page_transition.dart';
import './android_colors.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:page_transition/page_transition.dart';
import 'package:lottie/lottie.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/* pages */
import 'pages/vplan/VPlan.dart';
import 'pages/vplan/VPlanAPI.dart';
import 'pages/dashboard/Dashboard.dart';
import 'pages/share/SyncShareHub.dart';
import 'pages/share/ShareListPage.dart';
import 'pages/share/ShareBrowsePage.dart';
import 'pages/dashboard/settings/SyncSettings.dart';
import 'pages/search/SearchMenu.dart';
import 'pages/dashboard/settings/VPlanLogin.dart';
import 'pages/dashboard/SickTrack.dart';
import 'pages/dashboard/settings/PlanSettings.dart';
import 'pages/dashboard/settings/TeacherShorts.dart';
import 'pages/dashboard/settings/ConfigBackupSettings.dart';
import 'pages/dashboard/settings/DeveloperOptions.dart';
import 'services/AppAppearance.dart';
import 'services/AppLanguage.dart';
import 'services/StorageStartupRepair.dart';
import 'services/SchoolStorage.dart';
import 'services/sync/SyncCoordinator.dart';
import 'services/sync/SyncEngine.dart';
import 'services/AppClock.dart';
import 'services/NativeShell.dart';
import 'services/NativeScreens.dart';
import 'services/PlanTarget.dart';
import 'pages/vplan/Plan.dart';
import 'pages/vplan/PlanNativeBridge.dart';
import 'pages/vplan/WeekPlan.dart';

/// Compares two version strings (e.g. '3.7.10') numerically segment by segment.
/// Returns < 0 if [a] is older, 0 if equal, > 0 if [a] is newer.
int compareVersions(String a, String b) {
  final List<String> aParts = a.split('.');
  final List<String> bParts = b.split('.');
  final int max = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (int i = 0; i < max; i++) {
    final int aNum = i < aParts.length ? int.tryParse(aParts[i]) ?? 0 : 0;
    final int bNum = i < bParts.length ? int.tryParse(bParts[i]) ?? 0 : 0;
    if (aNum != bNum) return aNum.compareTo(bNum);
  }
  return 0;
}

/// Die Sprache der Einstellungen in Ordnung bringen, **bevor** der erste
/// Frame gezeichnet wird.
///
/// Läuft hier und nicht später: Die aufgelöste Sprache geht direkt in
/// [MyApp.startLocale] ein, und ein erst nach dem ersten Bild nachgeladener
/// Wert baut den ganzen Bildschirm ein zweites Mal um – bei der Sprache noch
/// auffälliger als beim Theme, weil sich jede Beschriftung verschiebt.
Future<void> _bereiteSprache(SharedPreferences prefs) =>
    AppLanguage.migrate(prefs);

Future<void> main([List<String> args = const <String>[]]) async {
  WidgetsFlutterBinding.ensureInitialized();

  // **Vor** allem anderen: Welche Rolle hat diese Ansicht?
  //
  // Auf iOS baut eine native `UIKit`-Schale die Navigationsleiste, und jede
  // Flutter-Ansicht bekommt nur einen Abschnitt zu zeigen. Das steht in den
  // Startargumenten (`--substitute-role=…`), gesetzt von `RootTabBarController`.
  //
  // Das muss hier gelesen werden und nicht später: Ob die App ihre eigene
  // Navigationsleiste baut und ob diese Ansicht den Hintergrund-Sync macht,
  // entscheidet sich **vor** dem ersten Frame. Einen Frame zu spät hieße hier
  // nicht nur ein spätes Nachziehen, sondern eine sichtbar doppelte Leiste.
  //
  // Auf Android, im Web und in den Tests ist `args` leer – dort bleibt es bei
  // [NativeShellRole.full], und die App verhält sich exakt wie vorher.
  NativeShell.readRole(args);

  // Auch das gehört **vor** dem ersten Frame, und aus demselben Grund wie die
  // Rolle: Die native Seite öffnet eine eigene Ansicht für den Plan einer
  // Klasse und sagt ihr in den Startargumenten, welche. Fiel das hier vorbei,
  // stünde in dieser Ansicht ein Plan ohne Klasse – eine leere Seite, die sich
  // wie ein Fehler anfühlt und nicht wie ein leerer Plan.
  //
  // Auf Android, im Web und in den Tests ist `args` leer; dort bleibt
  // [PlanTarget.isGesetzt] `false`, und es ändert sich nichts.
  PlanTarget.read(args);

  // Der Kanal für die nativen Bildschirme wird **hier** einmal angebracht und
  // nicht von jedem Bildschirm für sich. Siehe
  // [NativeScreens.ensureHandlerAttached] – `setMethodCallHandler` ersetzt den
  // bisherigen Handler, und wer es mehrfach täte, gewönne der zuletzt gebaute
  // Bildschirm: Die übrigen würden ihre Aktionen stillschweigend verlieren.
  NativeScreens.ensureHandlerAttached();

  // Und derselbe Kanal bekommt **einen** Zuhörer für die Tipps der nativen
  // Bildschirme.
  //
  // Auch das genau **einmal** und nicht je Bildschirm: Wer sich zweimal anmeldete,
  // bekäme jede Aktion zweimal – und „lösche die Person Müller" zweimal
  // auszuführen ist kein Fehlerbild, sondern eine leere Liste ohne Erklärung.
  PlanNativeBridge.install();

  // Der Systemstartbildschirm (einfarbig, ohne Icon) bleibt stehen, bis
  // `runApp` das erste Bild zeichnet. Deshalb wird hier erst geladen
  // und danach gestartet.
  Widget start;
  try {
    start = await _ladeApp();
  } catch (fehler, stack) {
    // Ohne diesen Fang bliebe der graue Bildschirm bei einem Ladefehler
    // für immer stehen.
    debugPrint('Start: die App liess sich nicht laden – $fehler\n$stack');
    start = const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Die App konnte nicht geladen werden. Bitte neu starten.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
  runApp(start);
}

/// Lädt die App und liefert den Bildschirm, der danach dasteht.
///
/// Aus [main] herausgezogen, weil dort jetzt der Startbildschirm steht und
/// nicht die App: Wäre es ein `await` in [main], hinge das Laden wieder vom
/// ersten Bild ab.
///
/// ## Was vor dem ersten Bild liegen muss – und was nicht
///
/// Vor `runApp` liegt alles, was den **ersten Frame** betrifft und nichts,
/// was man später auch noch tun kann:
///
/// * die Schulprofile (alle weiteren Speicherzugriffe sind über sie geschachtelt),
/// * die **Form** der Speicherwerte – davon hängt die Startbarkeit ab,
/// * die Vorschauen für die Startseite,
/// * die Zeitüberschreibung der Entwicklereinstellungen.
///
/// Nicht vor `runApp` liegt die **Ordnung** der Listen. Sie ist der teuerste
/// Durchgang der App überhaupt (er dekodiert jeden gespeicherten Plan, um zu
/// prüfen, ob er nach Datum sortiert ist) und niemand sieht an seinem Ergebnis:
/// Er wird deshalb nach dem ersten Bild nachgeholt – siehe [_nachDemErstenBild].
Future<Widget> _ladeApp() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await SchoolStorage.ensureInitialized(prefs);

  // Beim Start kommt alles in die Form und in die Reihenfolge, die die App
  // selbst schreibt:
  //
  // * **Form** – ein Sync, der einen Bestandteil in der falschen Form
  //   zurückgeschrieben hat, macht die App *dauerhaft* unstartbar. `VPlanAPI`
  //   liest dieselben Schlüssel mit typisierten Gettern, und die werfen bei
  //   falschem Typ einen `TypeError`, statt `null` zu liefern. Genau das ist
  //   geschehen: `persons` stand als `StringList` da, `getString` warf, `runApp`
  //   wurde nie erreicht. Dieser Durchgang liest nur den Typ und schreibt
  //   nichts, wenn nichts kaputt ist – deshalb darf er hier oben stehen.
  //
  // * **Ordnung** – Klassen sortiert nach der menschlichen Lesart (`06.2` vor
  //   `11`), Pläne nach Datum. Das betrifft jeden, der die App schon benutzt:
  //   Die Listen, die vor dem Update geschrieben wurden, folgen der Reihenfolge
  //   des Anlegens, und daran ändert das Sortieren beim Anlegen nichts mehr.
  //   Ohne diesen Durchgang bliebe es so, bis jemand zufällig eine Klasse
  //   hinzufügt – deshalb läuft er gleich, nur **hinter** dem ersten Bild.
  //
  // Beide Durchgänge prüfen vor dem Schreiben und tun bei bereits richtigen
  // Werten nichts – deshalb ist es gleichgültig, ob sie bei jedem Start laufen.
  final int formsFixed = await StorageStartupRepair.healForms(prefs);

  // Die Sprache wird **einmalig** festgeschrieben, damit ein Update die
  // eingestellte Sprache nicht verändert. Sieh [AppLanguage.migrate].
  await _bereiteSprache(prefs);

  // Zuletzt angezeigte Pläne / Vorschauen synchron in den Speicher laden,
  // damit beim Öffnen sofort (ohne Ladezeit) der letzte Stand angezeigt wird.
  // Die Pläne selbst werden dabei nur als Rohtext übernommen und erst
  // dekodiert, wenn jemand einen wirklich öffnet.
  await loadDisplayCache(prefs);

  // Eine in den Entwicklereinstellungen gesetzte Datums-Überschreibung auch
  // nach einem Neustart wieder anwenden (sie wird in SharedPreferences
  // gespeichert, aber sonst erst beim Öffnen der Entwicklereinstellungen in
  // den statischen AppClock geladen).
  await AppClock.getOverriddenNow();

  _nachDemErstenBild(() async {
    final int listsReordered = await StorageStartupRepair.repairLists(prefs);
    if (formsFixed > 0 || listsReordered > 0) {
      // ignore: avoid_print
      print('Start: repariert – $formsFixed Speicherwerte, '
          '$listsReordered Listen');
    }
  });

  if (prefs.getBool('firstTime') == null ||
      prefs.getBool('firstTime') == true) {
    return Introduction();
  }

  return wartenderAppStart(prefs);
}

/// Führt [arbeit] aus, **nachdem** der erste Frame gezeichnet wurde.
///
/// Der Aufruf kommt aus `_ladeApp`, also noch **vor** `runApp` – deshalb ist es
/// ein `addPostFrameCallback` und nicht einfach ein `unawaited`: Ein
/// `unawaited` würde neben dem ersten Frame laufen und genau das verursachen,
/// wogegen diese Änderung hier angetreten ist – der erste Frame käme nicht
/// schneller, weil er nebenbei konkurriert.
///
/// `addPostFrameCallback` überlebt den Aufruf von `runApp` unbeschadet: Der
/// Zeitgeber wird beim ersten Frame ausgelöst, den `runApp` gezeichnet hat.
void _nachDemErstenBild(Future<void> Function() arbeit) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Der Fehler wird **gefangen**. Ein `unawaited` ohne Fang lässt einen
    // Fehler aus dem `addPostFrameCallback` in die Zone der App laufen – und
    // das wäre ein Absturz mitten im Betrieb, ausgelöst von einer Aufräum-
    // oder Hintergrundaufgabe, an der niemand etwas bemerkt. Genau das darf
    // beim Start nicht passieren: Die App steht dann da und tut nichts.
    unawaited(arbeit().catchError((Object fehler, StackTrace stapel) {
      debugPrint('Nach dem ersten Bild: $fehler\n$stapel');
    }));
  });
}

/// Baut den Bildschirm, der nach dem Startbildschirm kommt.
///
/// Bei neuen Installationen die Anmeldeseite statt der Startseite – so kommt
/// man ohne Zugangsdaten nicht in die App. Hier wartet man noch auf die
/// Anmeldeseite; sie zu bauen ist billig, das Warten darauf gehört in die
/// App hinein, sonst stünde der Startbildschirm bei einer kaputten Anmeldung
/// endlos.
///
/// [prefs] ist die bereits geladene Instanz: Sie wird beim Start ohnehin
/// gebraucht, und [SharedPreferences.getInstance] ist zwar danach ein
/// Cache-Treffer – aber ein `await` pro Start ist immer noch ein Schritt, den
/// man sich sparen kann.
Future<Widget> wartenderAppStart([SharedPreferences? prefs]) async {
  final bool hasCredentials = await SchoolStorage.hasCredentials(prefs);
  // Die Darstellung wird **hier** aus dem Speicher gelesen und mitgegeben,
  // statt in `MyApp` ein zweites Mal asynchron nachgeladen zu werden. Sonst
  // hätte der allererste Frame das *System*-Theme statt des eingestellten (die
  // App ist von jeher dunkel) und die Systemsprache statt der gewählten – und
  // beide kämen einen Frame zu spät, als ein heller Blitz und ein Neubau des
  // ganzen Bildschirms.
  final SharedPreferences instance =
      prefs ?? await SharedPreferences.getInstance();
  return MyApp(
    startThemeMode: AppAppearance.modeOf(AppAppearance.themeOf(instance)),
    // `null`, wenn die App der Systemsprache folgt – siehe [AppLanguage].
    startLocale: AppLanguage.forMaterialApp(instance),
    initialPage: hasCredentials ? null : VPlanLogin(blockBack: true),
  );
}

/// Startet die App. Sind noch keine Zugangsdaten hinterlegt (z.B. direkt
/// nach der Installation), wird statt der Startseite direkt die Seite zum
/// Eintragen der Zugangsdaten angezeigt – so kommt man ohne Zugangsdaten
/// nicht in die App.
///
/// Von aussen aufrufbar, weil die Introduktion am Ende genau hiervon
/// weiterläuft: Sie ist der einzige Ort, der ohne den Startbildschirm von der
/// App zur nächsten Seite kommt.
Future<void> runSubstituteApp() async {
  runApp(await wartenderAppStart());
}

Color darken(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var f = 1 - percent / 100;
  return Color.from(
    alpha: c.a,
    red: (c.r * f).clamp(0.0, 1.0),
    green: (c.g * f).clamp(0.0, 1.0),
    blue: (c.b * f).clamp(0.0, 1.0),
  );
}

/// Groesse des Logos oben links in der Kopfzeile.
///
/// Das Feld, in dem es sitzt, ist 45 x 45 Punkte – so hoch wie die Zeile mit
/// dem Wort „Substitute“. Das Logo selbst fuellt dieses Feld aber **nicht** aus:
/// 45 Punkte sind fast so breit wie das Wort daneben und damit der mit
/// Abstand groesste Gegenstand der Kopfzeile; die Symbole der Leiste unten
/// sind 28 Punkte breit, daneben wirkt das Logo riesig.
///
/// 24 x 24 ist noch kleiner als die Symbole der Leiste unten (28 Punkte) – es
/// ist ein Erkennungszeichen, kein Gegenstand der Anzeige. Es bleibt gross
/// genug, um auf dem Startbildschirm, in der Suche und im Werkzeugkasten
/// wiedererkannt zu werden, und laesst ringsum Luft, sodass es nicht am Rand
/// klebt. `BoxFit.contain` verhindert zusaetzlich, dass das Logo verzerrt wird
/// – es ist nicht quadratisch (608 zu 564 Pixeln).
///
/// Eine Zahl an zwei Stellen, damit Taschen-Hase und Kopfzeile nach einem
/// Tippen auf das Logo nicht unterschiedlich gross aussehen.
const double kLogoGroesse = 24;

class MyApp extends StatefulWidget {
  const MyApp({
    Key? key,
    this.initialPage,
    this.startThemeMode,
    this.startLocale,
  }) : super(key: key);

  /// Optionaler Startbildschirm (z.B. die Anmeldeseite, solange noch keine
  /// Zugangsdaten hinterlegt sind). Wenn nicht gesetzt, wird die normale
  /// Startseite angezeigt.
  final Widget? initialPage;

  /// Das Theme, mit dem der **erste** Frame gezeichnet wird.
  ///
  /// Wird von `_ladeApp` aus dem bereits geladenen Speicher mitgegeben. Ohne
  /// diesen Wert beginnt [MaterialApp] im Theme des **Systems**, und die
  /// eingestellte Einstellung käme erst einen Frame später – auf einem hellen
  /// Telefon also ein weißer Blitz und danach ein Neuaufbau des ganzen
  /// Bildschirms, nur um festzustellen, dass die App dunkel ist.
  ///
  /// `null` heißt: nicht mitgegeben (etwa in einem Widget-Test) – dann wird
  /// wie vorher asynchron nachgeladen.
  final ThemeMode? startThemeMode;

  /// Die Sprache, mit der der **erste** Frame gezeichnet wird – aus demselben
  /// Grund wie [startThemeMode].
  ///
  /// `null` heißt entweder „nicht mitgegeben" (etwa in einem Widget-Test) oder
  /// ausdrücklich „**der Systemsprache folgen**". Letzteres ist kein Fehlen
  /// einer Angabe: `MaterialApp` nimmt dann die Systemsprache – und folgt ihr
  /// auch, wenn sie zur Laufzeit wechselt.
  final Locale? startLocale;

  /// Welcher Reiter zu einer Route der nativen Schale gehört.
  ///
  /// ## Warum der Reiter in der **Route** steht und nicht in der Rolle
  ///
  /// Die native Seite nennt ihren Abschnitt auf zwei Wegen: als Startargument
  /// (`--substitute-role=plan`) und als Route (`/abschnitt/plan`). Die beiden
  /// sind nicht gleich gut:
  ///
  /// * Fällt der **Weg** zu einer Route aus, findet `Navigator` keinen
  ///   Generator – und die App stürzt **beim Start** ab.
  /// * Fällt die **Rolle** aus, weiß diese App nichts darüber, welcher Reiter
  ///   gemeint war, und zeigt die ganze App.
  ///
  /// Der zweite Fall ist harmlos, der erste nicht. Deshalb wird hier nicht nach
  /// der Rolle gefragt, sondern nach der Route – die ist das, was die native
  /// Seite tatsächlich geöffnet hat, und sie ist auch dann da, wenn das
  /// Argument unterwegs verloren ging.
  ///
  /// Leer heißt: **keine** native Schale. Dann steht die ganze App, mit ihrer
  /// eigenen Leiste – so wie auf Android, im Web und in den meisten Tests.
  static String startTabForRoute(String route) {
    switch (route) {
      case '/abschnitt/search':
        return 'search';
      case '/abschnitt/sync':
        return 'syncShare';
      case '/abschnitt/plan':
        return 'vplanStudents';
      default:
        return '';
    }
  }

  /// Die Sprache der App umstellen.
  ///
  /// `null` heißt: **der Systemsprache folgen**. Das ist keine besondere
  /// Sprache, sondern die Abwesenheit einer Festlegung – `MaterialApp`
  /// übersetzt das selbst, und reagiert damit auch auf einen Wechsel der
  /// Systemsprache zur Laufzeit.
  static void setLocale(BuildContext context, Locale? newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale? _locale;
  bool _orientationLocked = false;

  /// Das gewählte Theme. `null` bedeutet: noch nicht gelesen.
  ///
  /// Ohne `themeMode` folgt `MaterialApp` dem **System**, und die App sieht auf
  /// einem hellen Telefon hell aus. Sie war aber immer dunkel – deshalb wird
  /// hier die Einstellung gesetzt, und deren Standard ist dunkel.
  late ThemeMode? _themeMode;

  /// Die Material-You-Farben – **einmal** geholt, nicht bei jedem Aufbau.
  ///
  /// Vorher stand `getMaterialYouColor()` direkt als `future:` im
  /// `FutureBuilder`. `build` läuft aber bei jeder Änderung von `_themeMode`,
  /// `_locale` oder der Palette erneut – und damit wurde die Methode bei
  /// **jedem** Aufruf neu gestartet: Jeder Wartende ein eigenes
  /// `FutureBuilder`, jeder wieder mit einem eigenen Lesevorgang und (bei
  /// aktivierten Material-You-Farben) einer eigenen Anfrage an die Plattform.
  late final Future<MaterialYouPalette?> _materialYou;

  /// Es meldet jede Änderung an den Darstellungseinstellungen. Ohne diesen
  /// Zuhörer käme man nach dem Umschalten auf den alten Bildschirm zurück und
  /// nichts hätte sich bewegt.
  late final VoidCallback _appearanceListener;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.startThemeMode;
    _locale = widget.startLocale;
    _materialYou = getMaterialYouColor();
    _appearanceListener = () {
      if (!mounted) return;
      _ladeTheme().then((ThemeMode mode) {
        if (mounted) setState(() => _themeMode = mode);
      });
    };
    AppAppearance.aenderung.addListener(_appearanceListener);

    // Auf iOS wird das Aussehen auch in den **nativen** Einstellungen
    // umgestellt. Dart hat den Wert zu diesem Zeitpunkt noch nicht gesehen –
    // `SharedPreferences` merkt sich nur, was es selbst geschrieben hat, und
    // geschrieben hat hier die native Seite.
    //
    // Ohne diesen Zuhörer würde beim Umschalten die Leiste und die
    // Einstellungsseite mitziehen, der Plan aber in der alten Helligkeit
    // stehen bleiben: zwei Helligkeiten auf einmal, und beide „richtig"
    // gerechnet.
    NativeShell.onAppearanceChanged(_themeVonDerNativenSeite);

    // Nur noch, wenn die Einstellung **nicht** schon mitgegeben wurde. Sonst
    // wäre das ein `setState` auf denselben Wert und ein zweiter Aufbau des
    // ganzen Bildschirms, kurz nach dem ersten.
    if (_themeMode == null) {
      _ladeTheme().then((ThemeMode mode) {
        if (mounted) setState(() => _themeMode = mode);
      });
    }
  }

  /// Liest Theme **und** Sprache neu ein, weil die native Seite sie geändert
  /// hat.
  ///
  /// Beides kommt über denselben Weg: Die native Seite meldet nur „ich habe
  /// etwas geschrieben", und hier wird nachgelesen. So kann es nicht zwei
  /// Stellen geben, die unterschiedliche Werte für dieselbe Sache behaupten.
  void _themeVonDerNativenSeite() {
    if (!mounted) return;
    AppAppearance.reloadTheme().then((ThemeMode mode) {
      if (mounted) setState(() => _themeMode = mode);
    });
    AppLanguage.reloadLanguage().then((Locale? sprache) {
      if (mounted) setState(() => _locale = sprache);
    });
  }

  @override
  void dispose() {
    AppAppearance.aenderung.removeListener(_appearanceListener);
    super.dispose();
  }

  Future<ThemeMode> _ladeTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppAppearance.modeOf(AppAppearance.themeOf(prefs));
  }

  setLocale(Locale? locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Wie beim Theme: nur nachladen, wenn nichts mitgegeben wurde.
    //
    // Geprüft wird dafür ein eigenes Flag und **nicht** `_locale`: `null`
    // bedeutet inzwischen „der Systemsprache folgen", nicht „noch nicht
    // bekannt". An `_locale` zu erkennen, dass noch nichts da ist, sähe nach
    // jedem Sprachwechsel auf „system" aus – und die App würde die
    // Systemsprache über die selbst gewählte Sprache legen.
    if (widget.startLocale != null || _localeGeladen) return;
    _localeGeladen = true;
    _getLocale().then((locale) {
      if (mounted) setLocale(locale);
    });
  }

  /// Ob die Sprache schon einmal bestimmt wurde.
  bool _localeGeladen = false;

  Future<Locale> _getLocale() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Nur der Weg, wenn beim Start nichts mitgegeben wurde – etwa in einem
    // Widget-Test. Die Systemsprache kommt aus dem Kontext, in dem die App
    // gerade läuft.
    return AppLanguage.localeFor(
        prefs, WidgetsBinding.instance.platformDispatcher.locale);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _materialYou,
      builder: (context, AsyncSnapshot<MaterialYouPalette?> snapshot) {
        Color primaryColor = Color(0xffAF69EE); //1fbe88); // ECA44D
        int scaffoldBGDark = snapshot.data?.neutral2.shade900 == null ? 50 : 70;

        // ---------------------------------------------------------------
        // Die beiden Farbwelten
        // ---------------------------------------------------------------
        //
        // **Hell ist keine Umkehrung von Dunkel.** Die beiden Welten sind
        // unabhängig voneinander festgelegt, weil eine Umkehrung genau das
        // ergibt, was man in der App sieht: graue Flächen, auf denen weiße
        // Karten liegen, weiße Trennlinien auf weißem Grund (also gar keine),
        // und eine Textfarbe, die für den dunklen Grund gewählt war und auf
        // hellem zu schwer wirkt.
        //
        // Die Rollen sind im ganzen Bildschirm dieselben, nur die Werte nicht:
        //
        // | Rolle            | Dunkel                    | Hell                    |
        // |------------------|---------------------------|-------------------------|
        // | Hintergrund      | `neutral2.shade900`       | `neutral2.shade50`      |
        // | Flächen (Karten) | ein wenig dunkler        | **weiß**                |
        // | Linien           | `accent3`/fast schwarz    | `neutral2.shade300`     |
        // | Text und Symbole | `focusColor` = weiß      | `focusColor` = fast Schwarz |
        // | Akzent           | `accent1.shade200` (hell)| `accent1.shade600` (dunkel) |
        //
        // Zwei Entscheidungen sind dabei nicht selbstverständlich:
        //
        // * **Der Hintergrund ist nicht weiß, die Karten sind es.** Umgekehrt
        //   heißen die Karten nicht – weißes Quadrat auf weißem Grund, und
        //   die Karte verschwindet. Ein sehr helles Grau als Grund gibt den
        //   weißen Karten ihren Rand, ohne aufzufallen.
        // * **Der Akzent wird im Hellen dunkler, nicht heller.** Der helle
        //   Akzent ist auf dunklem Grund gut lesbar, auf Weiß verschwindet
        //   er. Dasselbe gilt für die Linien: Sie mussten dort *dunkler*
        //   werden, nicht heller.
        final backgroundColor = snapshot.data?.neutral2.shade900 ??
            Color(0xff1e1f25); //Color(0xff101012);

        // Der Grund: fast weiß, aber nicht weiß – siehe die Tabelle oben.
        final backgroundColorLight =
            snapshot.data?.neutral2.shade50 ?? Color(0xfff5f5f8);

        // Die Karten und die Kopf- und Fußleiste liegen **auf** dem Grund und
        // sollen sich von ihm abheben. Auf Weiß ist das der einzige Weg.
        final surfaceLight = snapshot.data?.neutral2.shade50 ?? Colors.white;

        final primarySwatch = snapshot.data?.accent1.shade200 ?? primaryColor;
        // Im Hellen eine dunklere Stufe desselben Akzents, damit er auf Weiß
        // steht. `shade400` war hell genug, um auf dem Grund zu verschwinden.
        final primarySwatchLight =
            snapshot.data?.accent1.shade600 ?? Color(0xff7d43c4);

        // Linien: auf dunklem Grund schwarz, auf hellem ein sichtbares Grau.
        final dividerColor =
            snapshot.data?.accent3.shade100 ?? Color(0xff0d0d0f);
        final dividerColorLight =
            snapshot.data?.neutral2.shade300 ?? Color(0xffdcdae3);

        // Text und Symbole: fast schwarz statt reinem Schwarz. Reines Schwarz
        // auf Weiß ist hart und lässt den Buchstaben dicker wirken, als er ist.
        final focusColorLight = const Color(0xff1b1b1f);

        final indicatorColor = snapshot.data?.accent1.shade100 ?? primaryColor;

        final indicatorColorLight = primarySwatchLight;

        return MaterialApp(
          locale: _locale,
          themeMode: _themeMode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) {
            final MediaQueryData data = MediaQuery.of(context);
            // Handys (iPhone, Smartphone) werden im Hochformat fixiert,
            // damit die Ansicht nicht ins Querformat rotiert. Tablet, iPad
            // und Desktop (kleinste Seite >= 600 dp) dürfen frei rotieren.
            if (!_orientationLocked) {
              _orientationLocked = true;
              if (data.size.shortestSide < 600) {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
              }
            }
            return MediaQuery(
              data: data.copyWith(
                textScaler: TextScaler.linear(0.9),
              ),
              child: child!,
            );
          },
          debugShowCheckedModeBanner: false,
          navigatorObservers: [routeObserver],
          title: 'Substitute',
          darkTheme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.dark,
            primaryColor: primarySwatch,
            dividerColor: dividerColor,
            focusColor: Colors.white,
            indicatorColor: indicatorColor,
            colorScheme: ColorScheme.dark(
              error: Color.fromARGB(158, 119, 18, 18),
              surface: darken(backgroundColor, 5),
            ),
            scaffoldBackgroundColor: darken(backgroundColor, scaffoldBGDark),
            splashColor: snapshot.data == null ? Colors.white : Colors.black,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
          ),
          theme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.light,
            primaryColor: primarySwatchLight,
            indicatorColor: indicatorColorLight,
            focusColor: focusColorLight,
            dividerColor: dividerColorLight,
            colorScheme: ColorScheme.light(
              // Ein Fehler, der auf Weiß lesbar ist. Der alte Wert war eine
              // dunkelrote Fläche mit halber Deckkraft – auf dunklem Grund ein
              // Hauch von Rot, auf Weiß ein brauner Fleck.
              error: const Color(0xffc5221f),
              // Die Flächen (Karten, Kopf- und Fußleiste) sind weiß, der
              // Grund ist das helle Grau. Nicht umgekehrt – siehe die Tabelle
              // bei den Farbwerten.
              surface: surfaceLight,
              onSurface: focusColorLight,
              // Der Akzent wird auf Weiß abgedunkelt, damit er als Text und als
              // Symbol steht.
              primary: primarySwatchLight,
            ),
            scaffoldBackgroundColor: backgroundColorLight,
            splashColor: Colors.black.withValues(alpha: 0.06),
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
          ),
          // Ohne native Schale wird der Startbildschirm über `home` gesetzt – so
          // wie es immer war.
          //
          // **Mit** nativer Schale nicht: Dort liefert die native Seite eine
          // `initialRoute` (`/abschnitt/plan` und so weiter), und `home`
          // stünde daneben als zweite, widersprechende Angabe.
          home: NativeShell.isSection
              ? null
              : widget.initialPage ?? Scaffold(body: HomePage()),

          // Die native Schale sagt, welchen Abschnitt sie geöffnet hat. Ohne
          // diese beiden Zeilen fände `Navigator` zu `/abschnitt/plan` keinen
          // Weg und würde mit einem Fehler dastehen – „Could not find a
          // generator for route", und die App stürzte **beim Start** ab.
          onGenerateInitialRoutes: NativeShell.isSection
              ? (String route) => [
                    _routeFor(RouteSettings(name: route)),
                  ]
              : null,

          // Diese eine ist **immer** da, nicht nur unter der nativen Schale.
          //
          // Grund: `initialRoute` und die Rolle kommen beide von der nativen
          // Seite, und sie kommen auf **zwei** Wegen an – als Startargument
          // und als Route. Könnte eines davon ausfallen, wäre die andere noch
          // da, und ohne `onGenerateRoute` stünde der Bildschirm ohne Weg zu
          // ihr da.
          //
          // Deshalb ist die Rolle an zwei Stellen nötig, aber der Weg zu ihr
          // nur an einer: Fällt das Argument aus, wird hier `/abschnitt/plan`
          // immer noch aufgelöst – und zwar auf die ganze App, weil dann keine
          // Rolle bekannt ist. Falscher Abschnitt, aber kein Absturz: Ein
          // Absturz beim Start nimmt niemandem mehr etwas weg, ein falsch
          // angezeigter Bildschirm schon.
          onGenerateRoute: _routeFor,
        );
      },
    );
  }

  /// Der Weg, den eine Route der nativen Schale nimmt.
  ///
  /// ## Die drei Fälle
  ///
  /// * `/abschnitt/…` – ein Reiter der Leiste. Welcher das ist, steht im
  ///   Teil hinter dem Schrägstrich, **nicht** in der Rolle: Die Route ist das,
  ///   was die native Seite tatsächlich geöffnet hat, und die Rolle steht an
  ///   zwei Stellen, von denen eine ausfallen kann. Siehe [startTabForRoute].
  ///
  /// * `/werkzeug/…` – ein Werkzeug, das die native Schale **über** ihrer
  ///   Bildschirmreihe geöffnet hat. Es ist ein vollständiger Bildschirm mit
  ///   eigenem Zustand; die Leiste verschwindet dabei, denn man ist in einem
  ///   Werkzeug und nicht auf einem anderen Reiter.
  ///
  /// * Fehlen die Zugangsdaten, hat [MyApp.initialPage] Vorrang vor allem.
  ///   Wer sich nicht anmelden kann, darf nicht in den Plan kommen, und das
  ///   ist wichtiger als der Name der Route.
  Route<dynamic> _routeFor(RouteSettings settings) {
    final String name = settings.name ?? '/';
    final bool werkzeug = name.startsWith('/werkzeug/');
    // Der Plan einer Klasse, geöffnet von der nativen Übersicht. Siehe
    // [_werkzeug] – dort steht, warum auch dieser Weg dort aufgelöst wird.
    final bool plan = name.startsWith('/plan/') || name.startsWith('/sync/');

    // Die Leiste verschwindet für Werkzeuge und für die Anmeldeseite – beides
    // sind Bildschirme, die **über** allem stehen.
    //
    // Für den Plan **nicht**: Man geht dabei in einem Reiter weiter, und die
    // Leiste zu verstecken hieße, den Weg zurück suchen zu müssen, statt ihn
    // anzutippen. Genau dafür ist sie da.
    if (werkzeug || widget.initialPage != null) {
      NativeShell.setChromeVisible(false);
    }

    if (widget.initialPage != null) {
      return MaterialPageRoute(
        builder: (_) => widget.initialPage!,
        settings: settings,
      );
    }

    if (werkzeug || plan) {
      return MaterialPageRoute(
        builder: (_) => _werkzeug(name),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      // Der Reiter steht in der **Route**, nicht in der Rolle – siehe
      // [MyApp.startTabForRoute].
      builder: (_) =>
          Scaffold(body: HomePage(initialTab: MyApp.startTabForRoute(name))),
      settings: settings,
    );
  }

  /// Welches Werkzeug zu `/werkzeug/…` gehört.
  ///
  /// Bewusst ein `switch` mit einem **unbekannten** Fall und kein `??`: Eine
  /// Route, die man von Hand aufruft, soll etwas zeigen und nicht abstürzen.
  Widget _werkzeug(String name) {
    switch (name) {
      case '/werkzeug/anmelden':
        return const VPlanLogin();
      case '/werkzeug/krankheitstracker':
        return const SickTrack();
      case '/werkzeug/plan-einstellungen':
        return PlanSettings();
      case '/werkzeug/lehrerkuerzel':
        return TeacherShorts();
      case '/werkzeug/sicherung':
        return const ConfigBackupSettings();
      case '/werkzeug/entwickleroptionen':
        return DeveloperOptions();

      // Die beiden Werkzeuge, die hinter der **nativen** Plan-Übersicht liegen.
      //
      // Sie öffnen sich von dort aus, nicht aus dem Werkzeugkasten: Sie gehören
      // zum Plan und nicht zu den Einstellungen. Ihre Liste baut in Flutter,
      // weil sie aus dem VPlan kommt – siehe `PlanWerkzeugRoute` in Swift für
      // die Begründung, warum nicht auch noch die Übersicht.
      case '/werkzeug/klasse-hinzufuegen':
        return const KlasseHinzufuegen();
      case '/werkzeug/person-hinzufuegen':
        return const PersonHinzufuegen();

      // --------------------------------------------------------------
      // Der Plan einer Klasse, geöffnet von der **nativen** Übersicht.
      //
      // Diese beiden Wege sind keine Werkzeuge: Sie stehen nicht in der Liste
      // von [MoreScreen], und sie sind Reiter, keine Seiten darüber. Sie werden
      // hier trotzdem aufgelöst, weil `Navigator` sonst keinen Generator für die
      // Route fände und die App **beim Start** abstürzte – siehe
      // [onGenerateRoute].
      //
      // Die Route sagt nur, ob der **Tag** oder die **Woche** gezeigt wird. Der
      // Inhalt kommt aus [PlanTarget] – den liest [main] aus den
      // Startargumenten, und zwar **vor** dem ersten Frame.
      case '/plan/tag':
        return _planAnsicht(woche: false);
      case '/plan/woche':
        return _planAnsicht(woche: true);

      // --------------------------------------------------------------
      // Die drei Bildschirme hinter „Sync & Teilen“.
      //
      // Sie öffnen sich **aus dem Reiter heraus**: Man tippt auf eine Zeile der
      // nativen Liste, und der Bildschirm wandert in derselben Bildschirmreihe
      // nach links. Die Tab-Leiste bleibt deshalb stehen – siehe [NativeScreens]
      // und die Bemerkung bei `_routeFor`.
      case '/sync/sync':
        return const SyncSettings();
      case '/sync/teilen':
        return const ShareListPage();
      case '/sync/angebote':
        return const ShareBrowsePage();

      default:
        return const Scaffold(
          body: Center(child: Text('Diese Seite gibt es nicht.')),
        );
    }
  }

  /// Baut den Plan der in dieser Ansicht benannten Klasse oder Person.
  ///
  /// ## Warum hier ein eigener Bildschirm und kein `FutureBuilder`
  ///
  /// Weil das Nachschlagen **einmal** passiert und nicht bei jedem Aufbau. Ein
  /// `FutureBuilder` im `build` würde die Suche bei jedem Drehen des Geräts und
  /// bei jedem Wechsel der Helligkeit neu anstoßen – und die Liste der Personen
  /// jedes Mal aus dem Speicher lesen.
  ///
  /// Stattdessen passiert sie in `initState`, und das Ergebnis wird **gehalten**.
  /// Ein Plan, der sich seine Angaben nach dem ersten Aufbau nicht mehr merkt,
  /// wäre einer, der beim Scrollen wieder verschwindet.
  ///
  /// ## Warum die Person **hier** gesucht wird und nicht mitgeschickt
  ///
  /// Die native Seite kennt nur die Kennung. Sie könnte den ganzen Datensatz
  /// mitschicken – aber dann hätte sie eine **Kopie**, und die wäre veraltet,
  /// sobald jemand in Flutter den Namen ändert. Hier wird er deshalb aus dem
  /// Speicher geholt: Es gibt nur eine Quelle, und die ist die, die auch die
  /// Übersicht liest.
  ///
  /// Findet sich die Kennung nicht mehr – sie wurde zwischen dem Antippen und
  /// dem Öffnen gelöscht –, steht kein Plan da. Ein Plan ohne Angaben wäre eine
  /// Seite, die so tut, als wäre nichts passiert.
  Widget _planAnsicht({required bool woche}) {
    return _PlanAnsicht(woche: woche);
  }
}

/// Der Plan einer Klasse, den die native Übersicht geöffnet hat.
///
/// Siehe [_MyAppState._planAnsicht] – dort steht, warum das ein eigener
/// Bildschirm ist und nicht ein `FutureBuilder`.
class _PlanAnsicht extends StatefulWidget {
  const _PlanAnsicht({required this.woche});

  final bool woche;

  @override
  State<_PlanAnsicht> createState() => _PlanAnsichtState();
}

class _PlanAnsichtState extends State<_PlanAnsicht> {
  /// Der fertige Bildschirm, sobald die Angaben da sind.
  Widget? _plan;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final String classId = PlanTarget.classId;
    final String? personId = PlanTarget.personId;
    Widget Ergebnis = _gibtEsNicht();

    if (classId.isNotEmpty) {
      if (personId == null) {
        Ergebnis = widget.woche
            ? WeekPlan(classId: classId)
            : Plan(classId: classId);
      } else {
        final List<Map<String, dynamic>> alle = await VPlanAPI().getPersons();
        Map<String, dynamic>? person;
        for (final Map<String, dynamic> eintrag in alle) {
          if (eintrag['id'] == personId) {
            person = eintrag;
            break;
          }
        }
        if (person != null) {
          Ergebnis = widget.woche
              ? WeekPlan(classId: classId, person: person)
              : Plan(classId: classId, person: person);
        }
      }
    }

    if (!mounted) return;
    setState(() => _plan = Ergebnis);
  }

  /// Was ohne Plan dasteht.
  ///
  /// Ein **Text** und keine leere Seite: Eine leere Seite sähe aus wie ein Plan,
  /// in dem nichts steht – und man hätte kein Mittel, das zu unterscheiden.
  static Widget _gibtEsNicht() => const Scaffold(
        body: Center(child: Text('Diese Seite gibt es nicht.')),
      );

  @override
  Widget build(BuildContext context) {
    return _plan ?? const SizedBox.shrink();
  }
}

class HomePage extends StatefulWidget {
  final String? initialTab;

  /// Wenn true (z.B. beim Wechsel zu einer separaten Schule aus der
  /// Schulen-Übersicht), wird ein Zurück-Pfeil in der Kopfzeile angezeigt,
  /// mit dem man zur Schulen-Übersicht zurückkehren kann.
  final bool showBackButton;

  const HomePage({
    Key? key,
    this.initialTab,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class HomePageWithVPlanTab extends StatelessWidget {
  final bool showBackButton;

  const HomePageWithVPlanTab({Key? key, this.showBackButton = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HomePage(
      initialTab: 'vplanStudents',
      showBackButton: showBackButton,
    );
  }
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late String activeText;
  bool _hasCheckedForUpdates = false;

  @override
  void initState() {
    super.initState();
    eastereggController = AnimationController(vsync: this);
    // Set initial tab based on constructor parameter, default to vplanStudents
    //
    // Auf iOS entscheidet **nicht** dieser Bildschirm, welcher Abschnitt
    // sichtbar ist, sondern die native Schale: Sie baut die Leiste und legt
    // für jeden Eintrag eine eigene Flutter-Ansicht an. Diese Ansicht zeigt
    // dann genau den Abschnitt, für den sie angelegt wurde – deshalb steht
    // hier die Rolle, nicht der `initialTab`.
    //
    // **Und** `initialTab` wird gegen '' geprüft, nicht nur gegen `null`. Das
    // ist kein theoreticaler Punkt: `MyApp.startTabForRoute` liefert '' für
    // alles, was keine Abschnittsroute ist, und `'' ?? …` greift **nicht** –
    // `??` prüft nur `null`. Ein leerer Wert hier landete in `activeText`, und
    // dort passte er zu keinem Eintrag der Seitenliste: Der Bildschirm stand
    // dann dauerhaft auf „loading…" (das war der Fehler im Such-Reiter).
    activeText = (widget.initialTab?.isEmpty ?? true)
        ? _startKeyFuerRolle()
        : widget.initialTab!;

    // Refresh all VPlans in the background when app opens – aber erst, wenn der
    // erste Frame steht.
    //
    // `initState` läuft **während** des ersten Aufbaus. Ein Netzaufruf von hier
    // fängt genau dann an, wenn die App den Startbildschirm noch verlassen
    // muss, und konkurriert mit dem Aufbau, der als nächstes kommt: XML parsen,
    // JSON aufbauen, den ganzen Plan zurückschreiben – alles Dinge, die den
    // Haupt-Thread belegen, während Flutter den ersten Frame zeichnen will.
    // Nach dem Frame kostet es nichts, weil es ohnehin nur im Hintergrund
    // passiert.
    //
    // Auf iOS macht das **nur die Plan-Ansicht** – siehe [NativeShell.runsBackgroundWork].
    _nachDemErstenBild(_refreshAllPlans);

    // Der automatische Sync. Ohne ihn passiert ein Sync nur, wenn jemand die
    // Einstellungen öffnet und auf den Knopf tippt – wer die Einstellungen
    // nie aufsucht, überträgt nie etwas. Der Koordinator richtet sich selbst
    // aus, ist ohne eingerichtete Kette ein wirkungsloses Nichts und bricht
    // nach Fehlern mit wachsender Wartezeit ab.
    //
    // Auch dieser Auftrag gehört nur einer Ansicht. Lief er in allen, würde er
    // mehrfach stattfinden, und die Ansichten merken sich nur **jeweils selbst**,
    // dass er läuft – sie könnten einander nicht abwehren.
    if (NativeShell.runsBackgroundWork) {
      SyncCoordinator.instance.attach();
    }

    // Der Sync-Eintrag in der Leiste folgt der Einstellung aus „Aussehen".
    // Der Zuhörer sorgt dafür, dass die Leiste sich auch dann neu aufbaut,
    // wenn die Einstellung auf einer **anderen** Seite geändert wurde – ohne
    // ihn käme man auf eine Leiste zurück, die den Eintrag noch zeigt.
    _appearanceListener = _ladeEintrag;
    AppAppearance.aenderung.addListener(_appearanceListener);
    unawaited(_ladeEintrag());

    // Die nativen Bildschirme brauchen ihre Werte, und zwar aus **dieser**
    // Maschine – sie ist die, die den Speicher kennt und den VPlan fragen kann.
    //
    // Auf Android, im Web und in den Tests geschieht hier nichts: `publishPlan`
    // gibt dann sofort zurück, weil es keine native Schale gibt. Die beiden
    // Bildschirme dort sehen deshalb **genau** so aus wie vorher.
    unawaited(PlanNativeBridge.publishPlan());

    // Fremde Daten können mitten in der Sitzung eintreffen. Wer sie nicht
    // bemerkt, glaubt, der Sync hätte nicht funktioniert – die Daten waren ja
    // da, nur nirgends sichtbar.
    _syncSubscription = SyncCoordinator.instance.changes.listen((outcome) {
      if (!mounted) return;
      // ignore: avoid_print
      print('Sync hat ${outcome.merged} Änderungen gebracht');
      setState(() {});
      // Ein Sync kann Klassen und Personen mitbringen. Unter der nativen Schale
      // ist die Übersicht ein Bildschirm aus `UIKit`, und der weiss davon
      // nichts, bis er es gesagt bekommt.
      unawaited(PlanNativeBridge.publishPlan());
    });
  }

  StreamSubscription<SyncOutcome>? _syncSubscription;

  /// Welcher Abschnitt in dieser Ansicht steht.
  ///
  /// Ohne native Schale (`full`) ist es der normale Startabschnitt. Mit
  /// nativer Schale ist es der, für den die Ansicht angelegt wurde.
  static String _startKeyFuerRolle() {
    switch (NativeShell.role) {
      case NativeShellRole.sectionSearch:
        return 'search';
      case NativeShellRole.sectionSync:
        return 'syncShare';
      case NativeShellRole.sectionPlan:
      case NativeShellRole.tool:
      case NativeShellRole.full:
        return 'vplanStudents';
    }
  }

  Future<void> _refreshAllPlans() async {
    // Auf iOS holt nur die Plan-Ansicht die Pläne. Jede Ansicht hätte sonst
    // ihre eigene, und drei gleichzeitige Durchgänge bedeuten drei Anfragen
    // an dieselbe Adresse und drei Schreibvorgänge in dieselbe Datei.
    if (!NativeShell.runsBackgroundWork) return;
    try {
      await VPlanAPI().refreshAllPlansInBackground();
      // Benachrichtige die VPlan-Übersicht, damit sie ihre Vorschauen
      // abgleicht (aktualisiert wird nur, wenn sich etwas geändert hat).
      notifyVPlanBackgroundRefresh();
      print('Background refresh completed');
    } catch (e) {
      print('Error during background refresh: $e');
    }
  }

  /// Ob der Sync-Eintrag in der Leiste steht.
  ///
  /// `true` bis die Einstellung gelesen ist, damit der Eintrag beim allerersten
  /// Aufbau nicht kurzzeitig fehlt und die Leiste springt.
  bool _zeigeSyncEintrag = true;

  /// Es meldet jede Änderung an den Darstellungseinstellungen – sonst käme man
  /// nach dem Ausschalten auf eine Leiste zurück, die den Eintrag noch zeigt.
  late final VoidCallback _appearanceListener;

  Future<void> _ladeEintrag() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool wert = AppAppearance.showSyncShareTab(prefs);
    if (!mounted || wert == _zeigeSyncEintrag) return;
    setState(() => _zeigeSyncEintrag = wert);
  }

  void dispose() {
    _syncSubscription?.cancel();
    AppAppearance.aenderung.removeListener(_appearanceListener);
    eastereggController.dispose();
    super.dispose();
  }

  String version = 'loading...';

  Future<void> _loadVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      version = packageInfo.version;
    });
    // Die Suche nach einer neuen Version ist ein zweiter Netzaufruf **beim
    // Start** – und sie zeigt nie etwas, was man sofort bräuchte. Sie wartet
    // deshalb, bis der erste Frame steht (siehe `_nachDemErstenBild`).
    _nachDemErstenBild(() async => checkForUpdates(context));
  }

  void checkForUpdates(BuildContext context) async {
    if (_hasCheckedForUpdates || version == 'loading...')
      return; // Check only once per app open
    if (!kIsWeb && !Platform.isAndroid)
      return; // Only show update dialog on Android
    _hasCheckedForUpdates = true;
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/Sergey842248/Substitute/releases/latest'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final latestVersion = jsonResponse['tag_name']
            .replaceAll('v', ''); // Assuming tags are like 'v1.2.3'

        if (compareVersions(latestVersion, version) > 0) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              title: Row(
                children: [
                  Icon(Icons.system_security_update_outlined),
                  SizedBox(width: 10),
                  Text(AppLocalizations.of(context)!.newVersionAvailable),
                ],
              ),
              content: Text(AppLocalizations.of(context)!
                  .newVersionMessage(latestVersion)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)!.later,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),
                Button(
                  text: AppLocalizations.of(context)!.download,
                  onPressed: () async {
                    String url = jsonResponse['assets'][0][
                        'browser_download_url']; // Assuming the first asset is the APK
                    try {
                      await launchUrl(Uri.parse(url));
                    } catch (e) {
                      print('failed to launch URL: $e');
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        }
      } else {
        print('Failed to fetch latest release: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking for updates: $e');
      return;
    }
  }

  void openVPLan(String _prefClass) {}

  void eastereggIconChange() {
    if (eastereggIcon.key == ValueKey(1)) {
      eastereggIcon = Image.asset(
        'assets/img/logo.png',
        key: ValueKey(2),
        color: Theme.of(context).focusColor,
        // **Deutlich kleiner als sein Feld.** Vorher fuellte das Bild die Box
        // von 45x45 Punkten voll aus (und einmal sogar mehr, mit einer Breite
        // von 100), dann lief es in die Kopfzeile hinein. `kLogoGroesse`
        // laesst ringsum Luft; `BoxFit.contain` verhindert, dass es dabei
        // verzerrt wird.
        width: kLogoGroesse,
        height: kLogoGroesse,
        fit: BoxFit.contain,
      );
    } else {
      eastereggIcon = LottieBuilder.asset(
        'assets/animations/bird.json',
        key: ValueKey(1),
      );
      Future.delayed(
        const Duration(milliseconds: 6140),
        eastereggIconChange,
      );
    }
    setState(() {});
  }

  late final AnimationController eastereggController;
  Widget eastereggIcon = SizedBox();

  /// Die Farbe der Leiste unten – jetzt **nicht** mehr bei jedem Aufbau.
  ///
  /// `SystemChrome.setSystemUIOverlayStyle` geht über die Plattform an das
  /// System. Aus `build` heraus hieß das: bei **jedem** Neuaufbau dieses
  /// Bildschirms eine Anfrage an Android. Und der Bildschirm baut sich am
  /// Start mehrfach neu – beim Wechsel des Themes, beim Wechsel der Sprache,
  /// bei jedem Sync-Ergebnis, beim Tippen auf einen Eintrag.
  ///
  /// `didChangeDependencies` ist der richtige Ort: Es läuft beim ersten Aufbau
  /// **und** dann, wenn sich eine abhängige Geerbte ändert – das Theme ist
  /// genau eine davon, die Farbe der Leiste folgt ihr also weiterhin.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Die Texte des Sync-Bildschirms nach oben schicken.
    //
    // Hier und nicht im Bildschirm selbst: Unter der nativen Schale steht der
    // Sync als Bildschirm aus `UIKit`, und die Liste, die ihm die Texte
    // liefert, würde gar nicht gebaut. Diese Stelle wird dagegen **immer**
    // erreicht – sie hängt an der Sprache und an den Farben, und die ändern
    // sich öfter als der Bildschirm.
    //
    // Deshalb wird hier auch nicht gefragt, ob gerade der Sync-Reiter offen ist:
    // Es kostet drei Zeichen und spart das Nachfragen, wenn nicht.
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    PlanNativeBridge.publishSync(l10n);

    // Und derselbe Weg noch einmal, nur als **Antwort** auf eine Frage: Wenn die
    // native Seite ihren Bildschirm neu zeichnen will, fragt sie hier – und
    // nicht über den allgemeinen Zuhörer, der weiß nicht, wie der Sync-Bildschirm
    // zu versorgen ist.
    //
    // Das wird hier bei **jeder** Änderung von Sprache oder Farbe neu gesetzt.
    // Das ist billig – es ist ein Verweis – und es hebt den Fehler auf, dass nach
    // einem Sprachwechsel noch die alten Texte dastünden, weil niemand mehr
    // wusste, wer sie schicken soll.
    NativeScreens.onNeedsData(
        NativeScreen.sync, () => PlanNativeBridge.publishSync(l10n));

    _loadVersion();
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (eastereggIcon.runtimeType == SizedBox)
      eastereggIcon = Image.asset(
        'assets/img/logo.png',
        // Wie im anderen Zweig: dieselbe Groesse wie beim Tippen auf das
        // Logo, sonst waechselt es beim Antippen sichtbar die Groesse.
        width: kLogoGroesse,
        height: kLogoGroesse,
        fit: BoxFit.contain,
        key: ValueKey(2),
        color: Theme.of(context).focusColor,
      );
    // Die Farbe der **nicht** gewaehlten Symbole.
    //
    // Im Hellen ist das nicht die Textfarbe: Fast schwarze Symbole fuer vier
    // nicht ausgewaehlte Eintraege wirken schwer und lenken vom gewaehlten ab.
    // `onSurfaceVariant` ist dafuer gedacht – ein gedaempftes Grau, das als
    // "nur Andeutung" liest. **Im Dunkeln bleibt alles wie es war**, weil dort
    // die weisse Textfarbe gerade richtig ist und der Dunkelmodus der ist, den
    // die App seit jeher zeigt.
    final Color inaktiv = Theme.of(context).brightness == Brightness.light
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).focusColor;

    List<Map<String, dynamic>> pages = [
      {
        'key': 'vplanStudents',
        'text': AppLocalizations.of(context)!.vplanStudents,
        'index': 0,
        'icon': 'assets/img/home.svg',
        'widget': VPlan(),
      },
      {
        'key': 'search',
        'text': AppLocalizations.of(context)!.search,
        'index': 1,
        'icon': 'assets/img/search.svg',
        'widget': SearchMenu(),
      },
      // Sync und Share bekommen einen eigenen Platz in der Leiste. Vorher
      // lagen sie tief in den Einstellungen – zwischen Sprache, Sicherung und
      // Entwickleroptionen, also dort, wo niemand sie sucht. Über die Leiste
      // sind sie ein eigener Bildschirm, und darauf stehen die drei Wege mit
      // Überschrift: eigene Geräte, mit anderen teilen, deren Angebote
      // finden.
      //
      // **Vor** dem Dashboard, nicht danach: Das Dashboard ist der
      // Bildschirm mit Einstellungen und Werkzeugen, und ein Bildschirm, den
      // man beim Tippen mitnimmt, gehört nicht an den rechten Rand. Die
      // Leiste liest sich damit von links nach rechts wie ein Weg: Pläne
      // ansehen, suchen, mit anderen teilen, Werkzeuge.
      //
      // Wer den Eintrag nicht braucht, schaltet ihn unter Einstellungen →
      // Aussehen ab. Ausgeschaltet verschwindet nur der **Eintrag** – die
      // drei Funktionen bleiben erreichbar, sonst wären sie weg.
      if (_zeigeSyncEintrag)
        {
          'key': 'syncShare',
          'text': AppLocalizations.of(context)!.syncShareHub,
          'index': 2,
          'icon': 'assets/img/sync.svg',
          'widget': const SyncShareHub(),
        },
      {
        'key': 'dashboard',
        'text': AppLocalizations.of(context)!.dashboard,
        'index': 3,
        'icon': 'assets/img/dashboard.svg',
        'widget': Dashboard(),
      },
    ];

    Widget activeWidget = Text('loading...');
    for (int i = 0; i < pages.length; i++) {
      if (pages[i]['key'] == activeText) {
        activeWidget = pages[i]['widget'];
      }
    }
    return Scaffold(
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Stack(
              children: [
                // APPBAR
                Container(
                  alignment: Alignment.topCenter,
                  color: Theme.of(context).colorScheme.surface,
                  height: MediaQuery.of(context).size.height * 0.2,
                  width: MediaQuery.of(context).size.width,
                  padding: const EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                  ),
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Container(
                          alignment: Alignment.center,
                          height: 45,
                          child: Text(
                            'Substitute',
                            style: TextStyle(
                              fontSize: 23,
                              color: Theme.of(context).focusColor,
                              fontFamily: 'Crackman',
                            ),
                          ),
                        ),
                        if (widget.showBackButton)
                          Positioned(
                            left: 10,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(100),
                                    ),
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: 19,
                                    // Nicht `splashColor`: Die ist im hellen
                                    // Modus Schwarz mit 6 % Deckkraft und damit
                                    // auf dem grauen Kreis praktisch unsichtbar.
                                    // `focusColor` ist die Textfarbe des Themes
                                    // (fast Schwarz im Hellen, Weiß im Dunkeln).
                                    color: Theme.of(context).focusColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        InkWell(
                          onTap: () async {
                            // Implement developer mode logic here if needed in the future
                          },
                          child: Container(
                            alignment: Alignment.centerRight,
                            height: 45,
                            margin: EdgeInsets.only(
                              right: MediaQuery.of(context).size.width * 0.07,
                            ),
                            // padding: const EdgeInsets.all(10),
                            child: IconButton(
                              icon: Icon(Icons.more_horiz_rounded),
                              color: Colors.grey.shade400,
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => ModalBottomSheet(
                                    title:
                                        AppLocalizations.of(context)!.appInfo,
                                    bigTitle: true,
                                    extraButton: {
                                      'onTap': () {
                                        Share.share(
                                          'Check out Substitute on Github: https://www.github.com/Sergey842248/Substitute',
                                        );
                                      },
                                      'child': const Icon(
                                        Icons.share_rounded,
                                        size: 18,
                                      ),
                                    },
                                    content: Column(
                                      // Der Dialog zentriert Titel und
                                      // Knöpfe bereits; der Inhalt war
                                      // linksbündig und sah dadurch
                                      // uneinheitlich aus.
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Die Angaben zu Haupt- und
                                        // ehemaligem Entwickler wurden entfernt.
                                        ...[
                                          {
                                            'name':
                                                AppLocalizations.of(context)!
                                                    .openIssue,
                                            'link':
                                                'https://www.github.com/Sergey842248/Substitute/issues/new?template=bug_report.yml',
                                          },
                                          {
                                            'name':
                                                AppLocalizations.of(context)!
                                                    .github,
                                            'link':
                                                'https://www.github.com/Sergey842248/Substitute',
                                          }
                                        ].map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: InkWell(
                                              onTap: () => launchUrl(
                                                  Uri.parse(e['link']!)),
                                              child: Text(
                                                '${e['name']}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      Theme.of(context)
                                                          .focusColor,
                                                  fontSize: 17,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            AppLocalizations.of(context)!
                                                .version(version),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (!widget.showBackButton)
                          Container(
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.only(
                              left: MediaQuery.of(context).size.width * 0.1,
                            ),
                            height: 45,
                            width: 45,
                            child: InkWell(
                              onTap: eastereggIconChange,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                ),
                                child: eastereggIcon,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // CONTENT
                Container(
                  margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.14,
                  ),
                  padding: EdgeInsets.only(
                    left: 10,
                    right: 10,
                    // Die native iOS-Leiste liegt direkt über diesem Bereich.
                    // Hier darf deshalb kein dauerhafter unterer Rand stehen:
                    // sonst sähe man stets eine leere Schicht statt des
                    // Inhalts durch die transparente Leiste. Scrollbare Seiten
                    // hängen ihren Abstand nur an ihr jeweiliges Ende an
                    // ([NativeShellScrollEndInset]).
                    bottom: NativeShell.isSection
                        ? 0
                        : MediaQuery.of(context).size.height * 0.1 +
                            MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(45),
                      topRight: Radius.circular(45),
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: activeWidget,
                  ),
                ),
                // FOOTER
                //
                // Unter der nativen Schale **nicht**: Dort steht die Leiste von
                // `UITabBarController`, mit grossen Titeln, SF-Symbolen und dem
                // Material, das iOS selbst dafür vorsieht. Eine zweite Leiste
                // darüber wäre genau das, was die Umstellung loswerden soll –
                // und sie würde dem System die Berührungen der echten Leiste
                // wegnehmen.
                if (!NativeShell.isSection)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.1 +
                          MediaQuery.paddingOf(context).bottom,
                      alignment: Alignment.bottomCenter,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ...pages.map(
                            (e) => Container(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      activeText = e['key'];
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(7),
                                      child: SvgPicture.asset(
                                        e['icon'],
                                        colorFilter: ColorFilter.mode(
                                          activeText == e['key']
                                              ? Theme.of(context).primaryColor
                                              : inaktiv,
                                          BlendMode.srcIn,
                                        ),
                                        width: 28,
                                      ),
                                    ),
                                  ),
                                  SvgPicture.asset(
                                    'assets/img/active.svg',
                                    width: 13,
                                    colorFilter: ColorFilter.mode(
                                      e['key'] == activeText
                                          ? Theme.of(context).primaryColor
                                          : Colors.transparent,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
