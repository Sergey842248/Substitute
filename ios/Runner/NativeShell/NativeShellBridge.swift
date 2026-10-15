import Flutter
import UIKit

/// Das Gespräch zwischen der nativen Schale und den Flutter-Ansichten.
///
/// ## Was hier hin und her geht
///
/// **Nach unten** (Dart → native Seite) geht fast nichts, und das ist Absicht:
///
/// * `settingsChanged` – „ich habe etwas geschrieben". Mehr nicht, weil die
///   Seite die Werte **selbst liest** und nicht bekommt. Ein Wert, den man
///   hinüberschickt, wäre eine zweite Quelle für dieselbe Sache: Es könnten
///   zwei verschiedene Werte für dieselbe Einstellung im Umlauf sein, und man
///   hätte dann keine Stelle mehr, an der man nachsehen könnte, welche
///   gewinnt.
/// * `chromeVisible` – ob die Leiste stehen soll.
///
/// **Nach oben** (native Seite → Dart) geht eine Aufforderung:
///
/// * `appearanceChanged` – „lies deine Farben neu". Auch hier wird kein Wert
///   geschickt, aus demselben Grund.
///
/// ## Warum je Ansicht ein eigener Kanal
///
/// Jede Flutter-Ansicht hat ihre eigene Maschine und damit ihren eigenen
/// Kanal – drei Abschnitte also drei Kanäle. Die native Seite hält alle drei
/// und schickt an alle, wenn sich etwas ändert.
///
/// Das kostet drei Zeilen und spart die Alternative: eine gemeinsame Stelle,
/// an der alle drei hängen, und die Frage, was passiert, wenn die zweite
/// Ansicht noch gar nicht fertig geladen ist und die Nachricht niemanden
/// erreicht.
enum NativeShellBridge {
    /// Der Name des Kanals. Muss mit `NativeShell.channelName` übereinstimmen.
    static let channelName = "substitute/native_shell"

    /// Alle Kanäle, die bisher registriert wurden.
    ///
    /// Bei jeder Ansicht wird hier einer eingetragen, und bei jeder Änderung
    /// werden **alle** benachrichtigt. Eine Ansicht, die noch gar nicht
    /// geladen ist, hat noch keinen Kanal – und braucht auch keine Nachricht,
    /// denn sie liest ihren Stand beim Start ohnehin aus dem Speicher.
    private static var channels: [FlutterMethodChannel] = []

    /// Das Fenster, in dem die Leiste steht.
    ///
    /// Schwach, weil der Kanal länger lebt als der Bildschirm: Der Kanal wird
    /// beim Anlegen der Maschine eingetragen und nie abgemeldet, und hielte er
    /// den Bildschirm fest, würde der nie freigegeben.
    private static weak var tabBarController: RootTabBarController?

    /// Ruft [RootTabBarController] auf, sobald die Leiste steht.
    static func setHost(_ controller: RootTabBarController) {
        tabBarController = controller
        NotificationCenter.default.addObserver(
            forName: AppStore.settingsDidChange, object: nil, queue: .main
        ) { _ in
            // Flutter hat etwas geschrieben. Die Leiste muss das erfahren –
            // sie ist längst gebaut, und sie liest von selbst nichts neu.
            controller.settingsGeaendertInFlutter()
        }

        // Ein **anderer Schulbereich** ist mehr als eine Einstellungsänderung:
        // Er ändert, was die Leiste zeigt (hat der Bereich Zugangsdaten?) und was
        // **jede** Flutter-Ansicht zeigt (deren ganze Welt ist der Bereich).
        // Deshalb hat er einen eigenen Weg – siehe [activeSchoolChanged].
        NotificationCenter.default.addObserver(
            forName: AppStore.activeSchoolDidChange, object: nil, queue: .main
        ) { _ in
            controller.schuleGeaendert()
            activeSchoolChanged()
        }
    }

    /// Registriert den Kanal einer Ansicht.
    ///
    /// Es wird bewusst die **Maschine** übergeben und nicht ihr Vermittler:
    /// Dessen Objective-C-Typ (`NSObject<FlutterBinaryMessenger>`) müsste man in
    /// Swift ausschreiben, und eine falsch geschriebene Typangabe wäre ein
    /// Compilerfehler an genau der Stelle, an der es am wenigsten auffällt.
    /// So muss niemand den Typ benennen.
    static func register(on engine: FlutterEngine) {
        let channel = FlutterMethodChannel(
            name: channelName, binaryMessenger: engine.binaryMessenger)
        channels.append(channel)

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "settingsChanged":
                // Nur ein **Signal**: Die Seite holt sich den Wert selbst.
                // Siehe die Beschreibung oben, warum kein Wert mitkommommt.
                NotificationCenter.default.post(
                    name: AppStore.settingsDidChange, object: nil)
                result(nil)

            case "backToSchools":
                // „Zurück aus dieser Schule“ – gesagt von der Anmeldeseite eines
                // Schulbereichs ohne Zugangsdaten. Dort gibt es keine
                // Flutter-Route, die zurückführen könnte: Die Schulen-Übersicht
                // ist ein **nativer** Bildschirm im Abschnitt „Mehr“.
                //
                // Deshalb sagt die Seite der nativen Seite, wohin zurück – und
                // die Leiste macht es, weil sie als einzige beide Stapel kennt.
                DispatchQueue.main.async {
                    tabBarController?.zurueckInDieSchulen()
                }
                result(nil)

            case "chromeVisible":
                let sichtbar = (call.arguments as? Bool) ?? true
                // An **alle** Ansichten: Die Leiste ist eine, und wer sie
                // verlangt, meint die Leiste – nicht die, von der aus kam.
                DispatchQueue.main.async {
                    tabBarController?.setzeChromeSichtbar(sichtbar)
                }
                result(nil)

            default:
                // Eine unbekannte Anfrage ist kein Fehler: Sie kommt aus einer
                // älteren Version der Dart-Seite, die es nicht mehr gibt.
                // Statt sie abzulehnen, wird sie übergangen.
                result(nil)
            }
        }
    }

    /// Sagt **allen** Ansichten, dass ein anderer Schulbereich gilt.
    ///
    /// ## Warum das eine eigene Meldung ist und nicht Teil von [appearanceChanged]
    ///
    /// [appearanceChanged] sagt: „lies deine Farben neu". Der Schulbereich sagt
    /// etwas anderes: „alles, was du zeigst, gehört zu einer anderen Schule" –
    /// der Plan, die Klassen, die Vorschauen, und vor allem die Frage, ob es
    /// Zugangsdaten gibt.
    ///
    /// Dart baut daraufhin seine Ansicht **neu auf** (siehe
    /// `main.dart`, `_schuleGeaendert`) und nicht nur ihre Farben. Ein Neuaufbau
    /// wäre bei einer Helligkeitsänderung genau das Falsche: Er würde den
    /// Plan zerlegen, obwohl sich an ihm nichts geändert hat.
    ///
    /// An **alle** Ansichten, aus demselben Grund wie bei [appearanceChanged].
    static func activeSchoolChanged() {
        for channel in channels {
            channel.invokeMethod("activeSchoolChanged", arguments: nil)
        }
    }

    /// Sagt **allen** Ansichten, dass sie ihre Farben neu lesen sollen.
    ///
    /// Von dort aus, wo die Einstellung geändert wurde – also aus den
    /// nativen Bildschirmen. Jede Ansicht liest daraufhin selbst nach; kein
    /// Wert wandert über die Leitung.
    static func appearanceChanged() {
        for channel in channels {
            channel.invokeMethod("appearanceChanged", arguments: nil)
        }
    }

    /// Wie viele Punkte die Leiste am unteren Rand verdeckt.
    ///
    /// Gesendet wird nur dann, wenn sich der Wert geändert hat: Diese Methode wird
    /// bei **jedem** Bildaufbau gerufen, und ein Aufruf über den Kanal ist nicht
    /// gratis – Dutzende Aufrufe beim Scrollen wären es.
    static func setzeUeberdeckung(_ punkte: Double) {
        guard punkte != zuletztGesendeteUeberdeckung else { return }
        zuletztGesendeteUeberdeckung = punkte
        for channel in channels {
            channel.invokeMethod(
                "tabBarInset", arguments: ["height": punkte])
        }
    }

    /// Der zuletzt gesendete Wert – siehe [setzeUeberdeckung(_:)].
    private static var zuletztGesendeteUeberdeckung: Double = -1

    /// Wie viele Ansichten sind überhaupt da?
    ///
    /// Nur zum Nachsehen in der Konsole. Ohne Auskunft darüber, ob die
    /// Brücke angeschrieben hat, ist die Suche nach dem Grund, warum eine
    /// Änderung nicht ankommt, eine Ratesache.
    static var viewCount: Int { channels.count }
}

/// Hängt [NativeShellBridge.appearanceChanged] an die Änderung der
/// Darstellungseinstellungen.
///
/// Wird einmal beim Start gerufen und **nicht** bei jeder Änderung neu – sonst
/// hätte man nach ein paar Änderungen Dutzende Zuhörer, die alle dasselbe tun.
enum AppearanceBridge {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true

        NotificationCenter.default.addObserver(
            forName: AppStore.settingsDidChange, object: nil, queue: .main
        ) { _ in
            NativeShellBridge.appearanceChanged()
        }
    }
}