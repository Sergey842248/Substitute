import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'NativeShell.dart';

/// Welche der drei nativen Bildschirme eine Meldung betrifft.
///
/// Der Name geht über den Kanal und ist deshalb ein **einfacher englischer
/// Name** – nicht der Anzeigename und nicht der aus der Route. Siehe
/// [NativeShellRole.dartRole]: Ein Argument, das sich mit der eingestellten
/// Sprache ändert, wäre eine Fehlerquelle, die man erst beim Umstellen der
/// Sprache suchen müsste.
enum NativeScreen {
  /// Die Plan-Übersicht. Braucht Werte aus Dart: Klassen, Personen, Anzeigenamen.
  plan('plan'),

  /// „Sync & Teilen". Braucht Werte aus Dart: die übersetzten Texte der drei
  /// Wege.
  ///
  /// **Home steht hier nicht**, und das ist kein Versehen: Home weiss alles
  /// selbst – wohin eine Zeile führt, und welche Version die App hat. Es gibt
  /// keinen Wert, den Dart ihm schicken könnte.
  ///
  /// Ein dritter Fall wäre ein Kanal, in den nichts geht. Wer ihn eines Tages
  /// benutzt, wartet auf Werte, die niemand schickt, und sucht den Fehler hier
  /// drüben statt in der nativen Seite.
  sync('sync');

  const NativeScreen(this.wireName);

  /// Der Name, unter dem der Bildschirm über den Kanal läuft.
  final String wireName;
}

/// Das Gespräch zwischen Dart und den drei nativen Bildschirmen.
///
/// ## Wozu das hier ist
///
/// Auf iOS sind **Home**, **Plan** und **Sync & Teilen** in `UIKit` gebaut –
/// in `ios/Runner/NativeShell/`. Die Logik hinter diesen Bildschirmen liegt
/// trotzdem hier: das Lesen des VPlan-XML, das Rechnen der nächsten Stunde, der
/// Abgleich mit anderen Geräten, die Kryptografie. Diese Logik in Swift zu
/// verdoppeln wäre ein zweiter Ort, an dem dieselbe Sache passiert – und damit
/// die genaue Falle, die [AppStore] auf der nativen Seite vermeidet.
///
/// Deshalb wird **getrennt**: Dart rechnet, Swift zeichnet.
///
/// * **Nach oben** ([publish]) gehen die Werte, die gerade gelten – als
///   schlanke Karten aus Text. Keine Widget-Bäume, keine Callbacks: Swift
///   kennt keine Dart-Klassen und soll es auch nicht.
/// * **Nach unten** ([onAction]) kommen keine Werte, sondern **Aktionen**:
///   „öffne die Klasse 8a", „lösche die Person Müller". Swift sagt damit, was
///   der Daumen getroffen hat; *was* dabei passiert, entscheidet hier.
///
/// ## Warum die Richtung so herum ist und nicht umgekehrt
///
/// Der naheliegende andere Weg wäre, Swift zu fragen, was es gerade braucht.
/// Dann aber müsste die native Seite den Moment kennen, in dem Dart fertig
/// ist – und der ist es nicht: Die Pläne kommen aus dem Netz, die Personen aus
/// dem Speicher, die Vorschau aus einem zweiten Durchgang. Ein Warten auf
/// „fertig" wäre eine zweite Wahrheit über den Ladezustand, und die zwei
/// könnten auseinanderlaufen.
///
/// Stattdessen schickt Dart von sich aus, **sobald sich etwas geändert hat**.
/// Fehlt noch eine Karte, ist der Bildschirm noch nicht fertig – das ist
/// keine Race-Bedingung, sondern der Zustand selbst.
///
/// ## Warum das unter Android und im Web nichts tut
///
/// [publish] prüft [NativeShell.isSection]. Auf Android und im Web gibt es
/// keine native Schale, und die drei Bildschirme bleiben dort **genau so**, wie
/// sie waren – es wird nichts gesendet und nichts angefordert. Das ist der
/// Grund, warum hier überall `if (isSection)` steht und nicht im Aufrufer.
class NativeScreens {
  const NativeScreens._();

  /// Der Kanal zu den nativen Bildschirmen.
  ///
  /// Ein **eigener** Kanal und nicht der von [NativeShell]: Dort geht es um
  /// Einstellungen und um die Leiste, hier um Bildschirme und ihre Zeilen. Die
  /// beiden reden über verschiedene Dinge, und sie in einen Kanal zu legen
  /// hieße, dass jede Nachricht erst geprüft werden müsste, wofür sie da ist.
  static const MethodChannel channel = MethodChannel('substitute/native_screens');

  /// Der Name des Kanals. Muss mit `ScreenBridge.channelName` übereinstimmen.
  static const String channelName = 'substitute/native_screens';

  static bool get isSupported => NativeShell.isSection;

  // ------------------------------------------------------------- nach oben

  /// Schickt den aktuellen Stand eines Bildschirms nach oben.
  ///
  /// ## Warum `unawaited` und kein `await`
  ///
  /// Genau wie bei [NativeShell.notifySettingsChanged]: Es gibt hier nichts zu
  /// erfahren. Ein Bildschirm, der seine Daten bekommen hat, ist fertig – er
  /// muss auf keine Antwort warten, und wer hier wartete, hängte den Aufbau
  /// eines Bildschirms an einen Kanal, der auf Android und im Web gar nicht
  /// existiert. Der Fehler wird behandelt, aber dort, wo er auftaucht.
  static void publish(NativeScreen screen, Map<String, dynamic> payload) {
    if (!isSupported) return;
    unawaited(
      channel
          .invokeMethod<void>('publish', <String, dynamic>{
        'screen': screen.wireName,
        'payload': payload,
      })
          .catchError((Object fehler) {
        // Kein Absturz, kein Bildschirm ohne Inhalt: Die native Seite behält
        // ihre zuletzt gegangenen Werte, und beim nächsten `publish` kommt
        // der richtige nach.
        debugPrint('Native Bildschirme: $screen nicht zugestellt – $fehler');
      }),
    );
  }

  /// Fragt die native Seite, ob sie gerade Neuigkeiten von diesem Bildschirm
  /// braucht.
  ///
  /// Die native Seite fragt zwar von sich aus, wenn ein Bildschirm erscheint –
  /// aber nur, wenn sie diesen Weg geht. Diese Methode ist der Weg für den
  /// Fall, dass Dart **später** etwas hat, was die native Seite noch nicht
  /// kennen konnte: etwa eine Klasse, die gerade in einem anderen Bildschirm
  /// hinzugefügt wurde.
  static void requestRefresh(NativeScreen screen) {
    if (!isSupported) return;
    unawaited(
      channel
          .invokeMethod<void>('needsData', <String, dynamic>{
        'screen': screen.wireName,
      })
          .catchError((Object _) {}),
    );
  }

  // ------------------------------------------------------------ nach unten

  /// Was die native Seite getippt hat.
  ///
  /// `action` ist ein **englischer Name ohne Punkte**, nicht ein Text und keine
  /// Nummer: Er ist der gemeinsame Schlüssel beider Seiten. `args` trägt die
  /// Angaben dazu – etwa die Kennung der Klasse, um die es geht.
  ///
  /// Die Rückgabe wird **nicht** ausgewertet: Die native Seite zeigt nichts an
  /// darüber. Sie zeichnet das, was sie zuletzt bekommen hat, und eine Zeile,
  /// die 300 Millisekunden „busy" anzeigt, während Dart lädt, wäre eine
  /// Zusage, die nichts zusagt.
  static void Function(NativeScreen screen, String action, Map<String, dynamic> args)?
      _handler;

  /// Meldet Tipps der nativen Bildschirme weiter.
  ///
  /// Es wird nur **ein** Zuhörer gestattet, und das aus einem Grund, der leicht
  /// übersehen wird: Wer sich zweimal anmeldet, bekommt jede Aktion zweimal –
  /// und „lösche die Person Müller" zweimal auszuführen ist kein Fehlerbild,
  /// sondern ein leerer Bildschirm ohne Erklärung.
  ///
  /// Deshalb ersetzt ein späterer Aufruf den früheren, statt sich daneben zu
  /// stellen.
  static void onAction(
    void Function(NativeScreen screen, String action, Map<String, dynamic> args)
        handler,
  ) {
    _handler = handler;
  }

  /// Nimmt den Zuhörer wieder ab.
  ///
  /// Nötig beim Aufbau eines Bildschirms, der seine Aktionen behandelt: Sonst
  /// würde ein abgebauter Bildschirm noch Aktionen beantworten und damit
  /// Daten verändern, die niemand mehr sieht.
  static void clearActionHandler() => _handler = null;

  /// Von der nativen Seite aufgerufen. Hängt nur einmal am Kanal.
  ///
  /// Einmal, nicht bei jedem Bildschirm: `setMethodCallHandler` **ersetzt** den
  /// bisherigen Handler. Es bei jedem `initState` zu setzen hieße, dass der
  /// letzte Bildschirm gewinnt – und dass die anderen stillschweigend ihre
  /// Aktionen verlieren, was genau dann auffällt, wenn jemand sie braucht.
  static bool _hochgehaengt = false;

  static void ensureHandlerAttached() {
    if (_hochgehaengt) return;
    _hochgehaengt = true;
    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'action':
          _aktionAuswerten(call.arguments);
        case 'log':
          debugPrint('Native Bildschirme: ${call.arguments}');
      }
      return null;
    });
  }

  /// Was ein Bildschirm tun soll, wenn die native Seite **ihn** bittet, seinen
  /// Stand neu zu schicken.
  ///
  /// Je Bildschirm **einer**, wie bei [onAction] – und aus demselben Grund:
  /// Zwei Leute für dieselbe Sache bedeuten, dass am Ende derjenige gewinnt, der
  /// zuletzt gebaut wurde, und die anderen schweigen still.
  static final Map<NativeScreen, void Function()> _beiAnfrage = {};

  /// Meldet, was zu tun ist, wenn ein Bildschirm nach seinem Stand gefragt wird.
  ///
  /// ## Warum das ein eigener Weg ist und nicht über [onAction]
  ///
  /// „Schick deinen Stand noch einmal" ist keine **Aktion** auf der Oberfläche,
  /// sondern eine Frage der anderen Seite. Beide gingen zwar über denselben
  /// Kanal – aber sie sind nicht dasselbe, und sie zu vermischen hieße, dass ein
  /// Bildschirm beim Start schon entscheiden müsste, ob er eine Frage beantwortet
  /// oder eine Aktion ausführt.
  static void onNeedsData(NativeScreen screen, void Function() senden) {
    _beiAnfrage[screen] = senden;
  }

  /// Liest eine Aktion aus dem Kanal und gibt sie weiter.
  ///
  /// Alles Unerwartete wird **stillschweigend verworfen** – nicht abgelehnt
  /// und nicht mit einem Fehler quittiert. Es kann von einer älteren Fassung
  /// der nativen Seite kommen, und die Frage, die dann bleibt, wäre immer
  /// dieselbe: Warum passiert beim Tippen gar nichts? Eine Meldung auf der
  /// Konsole beantwortet sie; ein Absturz nicht.
  static void _aktionAuswerten(Object? argument) {
    if (argument is! Map) return;
    final Object? screenName = argument['screen'];
    final Object? action = argument['action'];
    if (screenName is! String || action is! String) return;


    final args = argument['args'];
    NativeScreen? screen;
    for (final NativeScreen kandidat in NativeScreen.values) {
      if (kandidat.wireName == screenName) {
        screen = kandidat;
        break;
      }
    }
    if (screen == null) return;

    // „Schick deinen Stand noch einmal" geht an denjenigen, der ihn schicken
    // kann, und **nicht** an den allgemeinen Zuhörer: Der eine weiss, wie der
    // Bildschirm zu versorgen ist, und der andere weiss es nicht.
    if (action == 'needsData') {
      _beiAnfrage[screen]?.call();
      return;
    }

    final Map<String, dynamic> werte =
        args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};

    _handler?.call(screen, action, werte);
  }
}