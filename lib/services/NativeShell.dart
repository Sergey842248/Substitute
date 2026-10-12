import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// true, wenn nicht die ganze App, sondern nur ein Abschnitt gezeigt wird.
  static bool get isSection => _role != NativeShellRole.full;

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
  /// auf Hell/Dunkel umstellt. Dart hat den Wert zu diesem Zeitpunkt noch im
  /// alten Stand – `SharedPreferences` merkt sich, was es selbst geschrieben
  /// hat, und ein Wert, den die native Seite geschrieben hat, sieht es erst
  /// beim nächsten Lesen.
  ///
  /// Deshalb wird hier nicht der neue Wert geschickt, sondern nur die
  /// **Aufforderung**, ihn zu holen. So kann es nicht zwei Quellen für dieselbe
  /// Wahrheit geben.
  static void onAppearanceChanged(VoidCallback neuLaden) {
    if (isSection) return;
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'appearanceChanged') {
        neuLaden();
      }
      return null;
    });
  }
}
