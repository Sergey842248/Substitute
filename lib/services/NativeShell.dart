import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Welche **Rolle** diese Instanz der App auf iOS gerade hat.
///
/// Auf Android, im Web und in den Tests gibt es nur eine Instanz, und die ist
/// [full] – die ganze App mit eigener Navigationsleiste. Auf iOS baut die
/// native Schale ([RootTabBarController]) die Leiste selbst, und jede
/// Flutter-Ansicht bekommt nur **einen** Abschnitt zu zeigen ([sectionPlan],
/// [sectionSearch], [sectionSync]). Deshalb steht die Rolle hier und nicht in
/// [main.dart] verteilt.
enum NativeShellRole {
  /// Keine native Schale: die App zeigt sich selbst, mit Leiste und allem.
  full,

  /// Der Vertretungsplan.
  sectionPlan,

  /// Die Suche.
  sectionSearch,

  /// Sync & Teilen.
  sectionSync,

  /// Ein Flutter-Werkzeug, das von der nativen „Mehr“-Ansicht geöffnet wird.
  ///
  /// Es ist kein Reiter und baut deshalb keine eigene Tab-Leiste. Es liegt
  /// aber in einer nativen Hülle und muss bis an deren unteren Rand reichen.
  tool,
}

/// Die Verbindung zur nativen Schale auf iOS.
///
/// ## Wozu das hier ist
///
/// Die App hat auf iOS zwei Ebenen: eine **native** Schale aus `UIKit`, die
/// den Tab-Balken, die Kopfzeilen und die Einstellungen bildet, und darunter
/// die Flutter-Ansichten, die den Inhalt liefern. Beide brauchen dieselben
/// Einstellungen – hell oder dunkel, welche Sprache, welcher Schulbereich – und
/// beide schreiben in dieselben Speicherwerte.
///
/// Damit das ohne Kopieren geht, spricht die native Seite **nicht** über eigene
/// Schattenwerte, sondern über genau dieselben `SharedPreferences`, die auch
/// Flutter benutzt (siehe `AppStore.swift`). Diese Klasse ist die Brücke in der
/// anderen Richtung: sie sagt der nativen Seite, dass sich etwas geändert hat,
/// und nimmt die Rückmeldungen der nativen Seite entgegen.
///
/// ## Warum die Rolle über _Argumente_ kommt und nicht über den Kanal
///
/// Die Rolle muss stehen, **bevor** der erste Frame gezeichnet wird: Der
/// Start entscheidet danach, ob die Navigationsleiste der App gebaut wird und
/// ob der Hintergrund-Sync hier läuft. Ein Kanal wäre einen Frame zu spät – und
/// ein Frame zu spät heißt hier ein sichtbarer Aufbau und zurück.
class NativeShell {
  const NativeShell._();

  /// Der Kanal zur nativen Seite. Auf anderen Plattformen gibt es ihn nicht –
  /// jeder Aufruf wird dann stillschweigend ins Leere laufen (siehe [_send]).
  static const MethodChannel channel = MethodChannel('substitute/native_shell');

  /// Die Rolle dieser Ansicht.
  ///
  /// Wird einmal beim Start aus den Argumenten gelesen und danach nie wieder:
  /// Sie entsteht daraus, **welche** Flutter-Ansicht die native Schale
  /// angelegt hat, und das ändert sich nicht.
  static NativeShellRole _role = NativeShellRole.full;

  /// Ob die App auf iOS in der nativen Schale läuft.
  ///
  /// Auf Android und im Web `false`, und damit bleibt dort alles genau so,
  /// wie es war.
  static NativeShellRole get role => _role;

  /// true, wenn diese Ansicht einer der drei unteren Reiter ist.
  ///
  /// Ein [NativeShellRole.tool] ist zwar ebenfalls in der nativen Hülle, aber
  /// kein Reiter: Es bleibt ein vollständiger Flutter-Bildschirm und darf
  /// deshalb weder die Reiter-Route noch deren Navigation übernehmen.
  static bool get isSection =>
      _role == NativeShellRole.sectionPlan ||
      _role == NativeShellRole.sectionSearch ||
      _role == NativeShellRole.sectionSync;

  /// Ob diese Ansicht bis an den unteren Rand der nativen Hülle reichen darf.
  ///
  /// Reiter liegen hinter der transparenten Tab-Leiste. Werkzeuge werden aus
  /// dem nativen „Mehr“-Bildschirm geöffnet; dort wird die Tab-Leiste zwar
  /// ausgeblendet, Flutter bekäme ohne diese Kennzeichnung aber weiterhin den
  /// alten unteren Safe-Area-Abstand und zeigte eine leere Zwischenschicht.
  static bool get extendsToNativeBottom =>
      isSection || _role == NativeShellRole.tool;

  /// Der Name des Kanals, über den eine **bestimmte** Ansicht ihre
  /// Nachrichten empfängt.
  ///
  /// Auf der nativen Seite ist das einer pro Ansicht – dort wird ein Kanal pro
  /// `FlutterViewController` gesetzt. Von Dart aus ist das nicht unterscheidbar,
  /// und es muss es auch nicht sein: Jede Ansicht führt dieselben Aufgaben aus,
  /// und jede schreibt in dieselben Speicherwerte. Es gibt also nichts, das
  /// nur in einer bestimmten Ansicht passieren dürfte.
  static const String channelName = 'substitute/native_shell';

  /// Der Kanal, über den eine einzelne Ansicht spricht.
  ///
  /// Der Name ist [channelName] – getrennt gehalten, damit die native Seite und
  /// diese Seite nicht aus Versehen verschiedene Namen benutzen.
  static MethodChannel channelForView([String? name]) =>
      MethodChannel(name ?? channelName);

  /// Liest die Rolle aus den Startargumenten.
  ///
  /// Die native Schale ruft jede Flutter-Ansicht mit
  /// `--substitute-role=<abschnitt>` auf. Findet sich kein Argument – Android,
  /// Web, Tests, oder eine alte native Schale – bleibt es bei [full], und die
  /// App verhält sich exakt wie vorher.
  static void readRole(List<String> args) {
    for (final String arg in args) {
      const String prefix = '--substitute-role=';
      if (!arg.startsWith(prefix)) continue;
      _role = _roleFromName(arg.substring(prefix.length));
      return;
    }
  }

  static NativeShellRole _roleFromName(String name) {
    switch (name) {
      case 'plan':
        return NativeShellRole.sectionPlan;
      case 'search':
        return NativeShellRole.sectionSearch;
      case 'sync':
        return NativeShellRole.sectionSync;
      case 'tool':
        return NativeShellRole.tool;
      default:
        return NativeShellRole.full;
    }
  }

  /// Setzt die Rolle direkt – nur für Tests.
  @visibleForTesting
  static void debugSetRole(NativeShellRole value) => _role = value;

  /// Läuft hier der Hintergrundauftrag (Plan auffrischen, Sync abholen)?
  ///
  /// ## Warum das überhaupt eine Frage ist
  ///
  /// Auf iOS laufen unter der nativen Schale **mehrere** Flutter-Ansichten
  /// gleichzeitig – je eine für Plan, Suche und Sync. Sie teilen sich denselben
  /// Speicher, aber nicht den Speicher *zu*: Jede hat ihren eigenen
  /// Zustand im Speicher.
  ///
  /// Liefe der Hintergrundauftrag in allen, würde er dreimal stattfinden:
  /// dreimal dieselben Anfragen an den VPlan, dreimal derselbe Sync gegen
  /// denselben Server, dreimal dieselben Dateien geschrieben. Der Sync
  /// merkt sich zwar, dass er gerade läuft – aber nur **innerhalb** einer
  /// Ansicht. Drei Ansichten heben das nicht gegeneinander auf, sondern drei
  /// unabhängige Läufe tun es.
  ///
  /// Deshalb darf nur **eine** Ansicht den Hintergrundauftrag machen. Welche,
  /// ist beliebig – und der Plan ist es, weil er die Ansicht ist, in der das
  /// Ergebnis ohnehin zuerst sichtbar sein soll.
  ///
  /// Der Klick auf „Aktualisieren" ist davon **nicht** betroffen: Der ruft die
  /// Methode direkt auf und wirkt in der Ansicht, in der man ihn gedrückt hat.
  static bool get runsBackgroundWork =>
      _role == NativeShellRole.full || _role == NativeShellRole.sectionPlan;

  /// Die Startroute, die zu dieser Rolle gehört.
  ///
  /// Wird von [MyApp] als `initialRoute` benutzt, damit `Navigator` in der
  /// Ansicht direkt den passenden Abschnitt öffnet – ohne dass erst alles
  /// gebaut und dann umgeschaltet werden müsste.
  static String get initialRoute {
    switch (_role) {
      case NativeShellRole.sectionPlan:
        return '/abschnitt/plan';
      case NativeShellRole.sectionSearch:
        return '/abschnitt/suche';
      case NativeShellRole.sectionSync:
        return '/abschnitt/sync';
      case NativeShellRole.tool:
        return '/';
      case NativeShellRole.full:
        return '/';
    }
  }

  // -------------------------------------------------------------- nach oben

  /// Meldet der nativen Seite, dass sich eine Einstellung geändert hat.
  ///
  /// Aufgerufen von [AppAppearance] und [AppLanguage], sobald dort etwas
  /// geschrieben wurde. Die native Seite liest daraufhin dieselben Speicherwerte
  /// neu – und muss das nicht raten, denn es stehen dieselben Schlüssel mit
  /// denselben Werten drin.
  ///
  /// Wird verschluckt, wenn es keine native Seite gibt: Auf Android und im Web
  /// ist niemand da, der zuhören würde.
  ///
  /// ## Warum hier **nicht** gewartet wird
  ///
  /// Das ist die eine Stelle, an der ein `await` ein echter Fehler wäre – und
  /// der Fehler ist nicht theoretisch:
  ///
  /// Der Aufrufer ist eine Einstellungsseite. Wer Hell auf Dunkel stellt,
  /// wartet auf [SharedPreferences] – und das ist der einzige Schritt, der
  /// tatsächlich etwas bewirkt. Die Meldung danach ist ein **Hinweis** an die
  /// Leiste; wartet man auf sie, hängt das Umstellen an einer Leiste, die
  /// gar nicht zuhören muss.
  ///
  /// In den Widget-Tests ist es noch deutlicher: Dort gibt es keine native
  /// Seite, die antwortet, und ein Wartender auf eine Antwort, die nie kommt,
  /// hält den Test an – die Oberfläche wäre korrekt und der Test würde
  /// hängen bleiben.
  ///
  /// Deshalb wird abgeschickt und **nicht** auf das Ergebnis gewartet. Der
  /// Fehler wird trotzdem behandelt, nur eben dort, wo er auftaucht.
  static void notifySettingsChanged() {
    if (isSection) return;
    unawaited(_send('settingsChanged'));
  }

  /// Meldet der nativen Seite, dass die Leiste ein- oder ausgeblendet werden
  /// soll.
  ///
  /// Die Einführung und die Anmeldeseite stehen **über** allem und sollen die
  /// Leiste nicht halb sichtbar unter sich durchscheinen lassen. Deshalb wird
  /// die Leiste dort ausgeblendet – und genau hier gesagt, wohin.
  static void setChromeVisible(bool visible) {
    if (isSection) return;
    unawaited(_send('chromeVisible', visible));
  }

  /// Sendet eine Meldung und lässt Fehler verschwinden.
  ///
  /// Fehler **werden** verschluckt, und das ist Absicht: Auf Android und im Web
  /// gibt es den Kanal nicht, und `MissingPluginException` dort hochlaufen zu
  /// lassen hieße, einen Absturz nur für ein Feature zu riskieren, das es gar
  /// nicht gibt. Auf iOS ist umgekehrt ein Fehler ein echter Fehler – aber einer,
  /// der eine Einstellung betrifft, und nicht den Start. Die Oberfläche zeigt
  /// den Wert ohnehin aus dem Speicher an, und beim nächsten Öffnen stimmt er
  /// wieder.
  static Future<void> _send(String method, [Object? argument]) async {
    try {
      await channel.invokeMethod<void>(method, argument);
    } on MissingPluginException {
      // Keine native Seite – Android, Web oder ein Test.
    } catch (fehler) {
      debugPrint('Native Schale: $method ist nicht durchgekommen – $fehler');
    }
  }

  // ------------------------------------------------------------- von oben

  /// Meldet, dass sich die Farben geändert haben.
  ///
  /// Die native Seite ruft das an, wenn jemand in den **nativen** Einstellungen
  /// auf Hell/Dunkel umstellt.
  ///
  /// ## Der Empfänger ist gerade die Ansicht, die den Befehl auslöst
  ///
  /// Früher stand hier eine Zeile, die den Empfänger in den Abschnitten
  /// **abgelehnt** hätte – mit der Begründung, dort gebe es nichts zu melden.
  /// Das war genau verkehrt: Auf iOS ist **jede** Ansicht ein Abschnitt, und die
  /// Abschnitte sind gerade die, deren Bild von der Einstellung abhängt. Die
  /// Zeile hat die Meldung also dort abgefangen, wo sie gebraucht wird – und
  /// der Hell-Modus blieb aus, während die Leiste und die Einstellungsseite
  /// hell wurden. Zwei Helligkeiten nebeneinander, beide „richtig“ gerechnet.
  ///
  /// ## Warum kein Wert mitkommt
  ///
  /// Es wird nur die **Aufforderung** geschickt, ihn zu holen. Ein
  /// mitgeschickter Wert wäre eine zweite Quelle für dieselbe Sache.
  static void onAppearanceChanged(VoidCallback neuLaden) {
    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'appearanceChanged':
          neuLaden();
        case 'tabBarInset':
          // Wie viele Punkte die Leiste am unteren Rand verdeckt. Gemessen von
          // der nativen Seite – sie weiss, wo die Leiste wirklich liegt.
          final Object? argument = call.arguments;
          if (argument is Map && argument['height'] is num) {
            ueberdeckung.value = (argument['height'] as num).toDouble();
          }
      }
      return null;
    });
  }

  /// Wie viele Punkte am unteren Rand von der Navigationsleiste verdeckt
  /// werden.
  ///
  /// ## Warum die Zahl von **dort** kommt
  ///
  /// `UITabBarController` verhält sich je iOS-Version anders: Früher legte es
  /// die Leiste unter den Inhalt und kürzte den Bildschirm darüber – es gab
  /// nichts zu überdecken. Neuere Systeme lassen sie über dem Inhalt schweben,
  /// und der Inhalt reicht bis zum unteren Rand.
  ///
  /// Eine im Dart-Code festgeschriebene Zahl wäre damit falsch: In der einen
  /// iOS-Version zu klein (ein Stück Inhalt bliebe verdeckt), in der anderen zu
  /// gross (ein Loch stünde darunter). Gemessen ist es der Abstand, um den der
  /// Inhalt wirklich zu kurz ist – auf jedem Gerät und in jeder Version.
  ///
  /// Startwert `0`: Solange die native Seite nichts gemeldet hat, soll nichts
  /// dazugerechnet werden. Sonst stünde auf einem Aufbau ohne Leiste ein Loch.
  static final ValueNotifier<double> ueberdeckung = ValueNotifier<double>(0);

  /// Der untere Bereich, den ein Bildschirm zusätzlich braucht.
  ///
  /// Das ist die Überdeckung – aber mindestens der sichere Bereich des Geräts.
  /// Der ist auch dann nötig, wenn die Leiste den Inhalt gar nicht verdeckt:
  /// Der Inhalt soll nicht in die Geste-Zone am unteren Rand hineinreichen.
  static double untererBereich(BuildContext context) {
    final double sicher = MediaQuery.paddingOf(context).bottom;
    return math.max(ueberdeckung.value, sicher);
  }
}

/// Leerraum, der ausschließlich am Ende einer scrollbaren Ansicht steht.
///
/// Die native iOS-Leiste liegt über dem Inhalt. Dieser Abstand gehört daher
/// in die Scrollposition der einzelnen Seite und nicht als fester Rand um den
/// gesamten Bildschirm: Nur ganz unten kann man den letzten Eintrag dadurch
/// über die Leiste schieben; während des restlichen Scrollens bleibt der
/// Inhalt hinter der transparenten Leiste sichtbar.
///
/// ## Für wen er gilt – und für wen nicht
///
/// Geprüft wird [NativeShell.extendsToNativeBottom], **nicht** [isSection].
///
/// Der Unterschied ist genau der Fehler, der die Werkzeuge betraf hat: Ein
/// Werkzeug wie „Lehrerkürzel festlegen" ist **kein** Reiter – es hat kein
/// `--substitute-role=plan` und damit auch kein [isSection]. Nach der alten
/// Prüfung bekam es keinen Abschluss, obwohl es sehr wohl bis an den unteren
/// Rand reicht ([extendsToNativeBottom] gilt dort ausdrücklich zu).
///
/// Und wofür braucht es den Platz überhaupt, wenn die Leiste ausgeblendet ist?
/// Für den **sicheren Bereich des Geräts**: [untererBereich] ist mindestens so
/// gross wie der Abstand für die Geste-Zone am unteren Rand. Ohne den Abschluss
/// reichte der letzte Eintrag bis in genau diese Zone hinein.
///
/// ## Warum nicht einfach immer
///
/// Auf Android und im Web gibt es keine native Leiste, und [ueberdeckung]
/// bleibt dort auf `0`. Der Abschnitt würde dann zwar nur den sicheren Bereich
/// einfügen – aber doppelt, denn `SafeArea` setzt ihn bereits. Deshalb gilt er
/// nur dort, wo Flutter wirklich bis an den unteren Rand reicht.
class NativeShellScrollEndInset extends StatelessWidget {
  const NativeShellScrollEndInset({super.key});

  @override
  Widget build(BuildContext context) {
    if (!NativeShell.extendsToNativeBottom) return const SizedBox.shrink();

    return ValueListenableBuilder<double>(
      valueListenable: NativeShell.ueberdeckung,
      builder: (BuildContext context, double _, Widget? __) => SizedBox(
        height: NativeShell.untererBereich(context),
      ),
    );
  }
}
