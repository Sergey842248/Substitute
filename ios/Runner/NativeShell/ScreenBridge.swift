import Flutter
import UIKit

/// Das Gespräch zwischen den drei nativen Bildschirmen und den Flutter-Ansichten.
///
/// ## Wer hier was macht
///
/// **Home**, **Plan** und **Sync & Teilen** sind in `UIKit` gebaut. Die Logik
/// hinter ihnen nicht: Das Lesen des VPlan-XML, das Rechnen der nächsten
/// Stunde, der Abgleich mit anderen Geräten, die Kryptografie. Die liegt in
/// Dart, und sie liegt dort auch weiter – eine zweite Fassung in Swift wäre ein
/// zweiter Ort, an dem dieselbe Sache passiert.
///
/// Deshalb ist die Richtung hier festgelegt:
///
/// * **Dart → Swift**: der gerade geltende Stand, als schlanke Karten aus
///   Text. Swift kennt keine Dart-Klassen und soll es nicht.
/// * **Swift → Dart**: **Aktionen**, keine Werte. „Öffne die Klasse 8a", nicht
///   „Hier ist die Klasse 8a". Wer den Wert schickt, führt eine zweite Quelle
///   ein – siehe `NativeShellBridge` für dieselbe Begründung bei Einstellungen.
///
/// ## Warum `publish` von Dart kommt und nicht „was brauchst du?" von hier
///
/// Swift könnte fragen, was es gerade braucht. Dann müsste es aber den Moment
/// kennen, in dem Dart fertig ist – und den gibt es nicht: Die Klassen kommen
/// aus dem Speicher, die Vorschau aus einem zweiten Durchgang, beides nach dem
/// Netz. Ein Warten auf „fertig" wäre eine **zweite** Wahrheit über den
/// Ladezustand.
///
/// Stattdessen schickt Dart, sobald sich etwas ändert (`publish`, dort drüben), und
/// wir merken uns den letzten Stand ([stand]). Fehlt etwas, ist der Bildschirm noch
/// nicht fertig – das ist kein Fehler, sondern sein Zustand.
///
/// ## Der Rückweg: [action]
///
/// Es ist eine **Aktion**, kein Wert. Sie nennt den englischen Namen eines
/// Vorgangs und die Angaben dazu. Dart entscheidet, was daraus wird, und
/// schickt danach von selbst den neuen Stand. Es gibt hier keinen Weg, auf dem
/// Swift eine Antwort erwartete – die native Seite zeichnet das, was sie zuletzt
/// bekommen hat, und eine Zeile, die eine Sekunde lang „busy" anzeigt, während
/// Dart lädt, wäre eine Zusage, die nichts zusagt.
enum ScreenBridge {

    /// Der Name des Kanals. Muss mit `NativeScreens.channelName` übereinstimmen.
    ///
    /// Ein **eigener** Kanal und nicht der von `NativeShellBridge`: Dort geht es
    /// um Einstellungen und um die Leiste, hier um Bildschirme und ihre Zeilen.
    /// Beide in einen Kanal zu legen hieße, dass jede Nachricht erst geprüft
    /// werden müsste, wofür sie überhaupt da ist.
    static let channelName = "substitute/native_screens"

    /// Die Bildschirme, die Dart beliefert.
    ///
    /// Es sind **zwei**, nicht drei: **Home** steht nicht hier.
    ///
    /// Das ist kein Versehen. Home besteht aus zwei Dingen – Zeilen, die schon
    /// wissen, wohin sie führen, und einem Blatt mit Version und Links. Beides
    /// weiss die native Seite **selbst**; es gibt keinen Wert, den Dart ihr
    /// schicken könnte.
    ///
    /// Ein dritter Fall hier wäre ein Kanal, in den nichts geht – und wer ihn
    /// eines Tages benutzt, wartet auf Werte, die niemand schickt, und sucht
    /// den Fehler in Dart statt in der Leiste.
    enum Screen: String {
        case plan
        case sync
    }

    // -------------------------------------------------------------- Richtung

    /// Die Kanäle, über die hier gesprochen wird – je **Ansicht** einer.
    ///
    /// Dass es mehrere sind, ist dasselbe wie bei `NativeShellBridge`: Unter
    /// der nativen Schale laufen mehrere Flutter-Maschinen, jede mit ihrem
    /// eigenen Vermittler. Wer hier spricht, ist deshalb **nur eine** davon.
    ///
    /// Der Unterschied zu dort ist, wer wem die Daten gibt. Dort sprach die
    /// Leiste mit allen Ansichten. Hier fragt ein nativer Bildschirm die
    /// Ansicht, die ihn **beliefert** – und das ist genau die, deren Rolle
    /// dazugehört. Deshalb wird hier nicht an alle gesendet, sondern der
    /// Bildschirm trägt seine Ansicht selbst.
    private static var channels: [Screen: FlutterMethodChannel] = [:]

    /// Der zuletzt empfangene Stand je Bildschirm.
    ///
    /// Das ist der Grund, warum hier nichts „wartet": Der Handler in [register(on:)]
    /// speichert **erst** und zeichnet dann. Ein Bildschirm, der zum ersten Mal
    /// erscheint, malt also sofort das, was es gerade gibt – und nicht einen
    /// leeren Bildschirm, der auf die nächste Änderung wartet.
    private static var stands: [Screen: [String: Any]] = [:]

    /// Wer ein Bildschirm neu zeichnen soll, wenn neue Werte ankommen.
    ///
    /// Schwach, und deshalb über Token abgemeldet: Ein Bildschirm, der den
    /// Bildschirm hält, der ihn hält, wird nie freigegeben.
    private static var zeichner: [Screen: UUID: () -> Void] = [:]

    /// Registriert den Kanal einer Ansicht.
    ///
    /// Siehe [NativeShellBridge.register(on:)] – warum hier die **Maschine**
    /// übergeben wird und nicht ihr Vermittler, gilt genauso.
    static func register(on engine: FlutterEngine) {
        let channel = FlutterMethodChannel(
            name: channelName, binaryMessenger: engine.binaryMessenger)

        channel.setMethodCallHandler { call, _ in
            switch call.method {
            case "publish":
                if let args = call.arguments as? [String: Any],
                   let name = args["screen"] as? String,
                   let screen = Screen(rawValue: name),
                   let payload = args["payload"] as? [String: Any]
                {
                    stands[screen] = payload
                    neuZeichnen(screen)
                }
            default:
                // Unbekannt heisst: von einer älteren Dart-Seite, die es nicht
                // mehr gibt. Siehe die Beschreibung bei `NativeShellBridge`.
                break
            }
        }
    }

    /// Der Kanal einer Ansicht, gespeichert unter ihrem Bildschirm.
    ///
    /// Der Bildschirm muss sich **selbst** anmelden – deshalb wird hier nicht
    /// geraten, welche Maschine zu wem gehört.
    static func kanal(_ screen: Screen) -> FlutterMethodChannel? {
        channels[screen]
    }

    /// Merkt sich den Kanal einer Ansicht für einen Bildschirm.
    static func setzeKanal(_ screen: Screen, auf engine: FlutterEngine) {
        if channels[screen] == nil {
            register(on: engine)
        }
        channels[screen] = FlutterMethodChannel(
            name: channelName, binaryMessenger: engine.binaryMessenger)
    }

    /// Der Stand, der zuletzt für diesen Bildschirm kam.
    ///
    /// `nil` heißt: Es ist noch keiner gekommen. Der Bildschirm zeigt dann
    /// seinen leeren Zustand – nicht einen, der so aussieht als wäre die
    /// Liste wirklich leer.
    static func stand(_ screen: Screen) -> [String: Any]? { stands[screen] }

    /// Vergisst den Stand eines Bildschirms.
    ///
    /// Nötig beim Wechsel des Schulbereichs: Die alten Werte gehören zum
    /// vorherigen Bereich, und sie weiter anzuzeigen hieße, das Falsche zu
    /// zeigen.
    static func vergiss(_ screen: Screen) {
        stands[screen] = nil
    }

    /// Sagt Dart, was der Daumen getroffen hat.
    ///
    /// ## Warum **ohne** Antwort
    ///
    /// Es könnte hier ein Ergebnis zurückkommen – „erledigt", „ging nicht". Es
    /// kommt aber keines, und das ist Absicht:
    ///
    /// Was beim Tippen passiert, entscheidet Dart: „lösche die Person" ist ein
    /// Schreibvorgang, der eine Fehlermeldung braucht, und die kann nur dort
    /// entstehen, wo die Liste steht, aus der gelöscht wird. Ein Ergebnis, das
    /// hier zurückkäme, wäre eine **zweite** Stelle, die denselben Fehler
    /// melden müsste – und die native Seite könnte ihn nur anzeigen, nicht
    /// beheben.
    ///
    /// Stattdessen schickt Dart, wenn es fertig ist, von selbst den neuen Stand
    /// (dort drüben). Die native Seite zeichnet ihn. Damit gibt es genau **eine**
    /// Richtung, in der sich etwas ändert, und sie ist die, in der die Daten
    /// liegen.
    ///
    /// ## Warum kein Warten
    ///
    /// Weil es nichts zu erfahren gibt – siehe oben. Und weil wer hier wartete,
    /// das Tippen an einen Kanal hängen würde, der unter Android und im Test
    /// gar nicht antwortet.
    static func action(
        _ screen: Screen, _ aktion: String, args: [String: Any] = [:]
    ) {
        guard let kanal = kanal(screen) else { return }
        kanal.invokeMethod(
            "action",
            arguments: [
                "screen": screen.rawValue,
                "action": aktion,
                "args": args,
            ]
        )
    }

    // -------------------------------------------------------------- Zeichen

    /// Meldet einem Bildschirm, dass er sich neu zeichnen soll.
    ///
    /// ## Warum hier nicht der Bildschirm selbst zuhört
    ///
    /// Er könnte – aber er müsste sich bei jeder erscheinenden Ansicht neu
    /// anmelden und beim Verschwinden wieder abmelden. Bliebe das aus, zöge eine
    /// weggeworfene Ansicht den Bildschirm mit sich in den Tod: Ihre Aktion
    /// rief dann Bildschirme, die es nicht mehr gibt.
    ///
    /// Deshalb fragt der Bildschirm hier **ab**, statt hier zu warten: Er meldet
    /// sich beim Erscheinen an und meldet sich beim Weggehen ab ([horchZu] /
    /// [hoerAuf]), und was in der Zwischenzeit ankommt, ist nicht mehr da.
    @discardableResult
    static func horchZu(_ screen: Screen, _ zeichnen: @escaping () -> Void) -> UUID {
        let token = UUID()
        zeichner[screen, default: [:]][token] = zeichnen
        return token
    }

    static func hoerAuf(_ screen: Screen, token: UUID?) {
        guard let token else { return }
        zeichner[screen]?.removeValue(forKey: token)
    }

    private static func neuZeichnen(_ screen: Screen) {
        // Auf dem Hauptthread: Die Werte kommen aus Dart, also aus einer
        // Flutter-Isolate, und UIKit darf von dort nicht angefasst werden.
        // `DispatchQueue.main.async` ist hier nicht nur Höflichkeit – ohne sie
        // wäre es ein Verstoß gegen die Threadregel von UIKit, dessen Symptom
        // nicht ein Absturz, sondern eine Liste ist, die **manchmal** stehen
        // bleibt.
        DispatchQueue.main.async {
            guard let zeichner = self.zeichner[screen] else { return }
            for zeichne in zeichner.values { zeichne() }
        }
    }
}

// MARK: - Wie man eine gelieferte Karte liest

/// Wie man die Karten liest, die aus Dart kommen.
///
/// ## Warum das eine eigene Stelle ist
///
/// Sie stehen als `[String: Any]` aus der Übertragung, und `Any` erzwingt
/// überall einen Test: `daten["klassen"] as? [[String: Any]] ?? []` steht sonst
/// in jedem Bildschirm, und an jeder Stelle kann er anders geschrieben sein.
///
/// ## Warum hier **nichts** erfunden wird
///
/// Ein fehlender Wert liefert die **leere** Liste und nicht irgendeinen Platzhalter.
/// Wer eine leere Liste sieht, schließt daraus „noch nichts angelegt" – und das
/// ist die Wahrheit. Ein erfundener Eintrag mit leerem Namen sähe aus wie ein
/// Eintrag, und der würde beim Antippen einen leeren Plan öffnen.
extension Dictionary where Key == String, Value == Any {

    /// Die Personen aus dieser Karte – jede mit `id`, `name` und `classId`.
    var personen: [[String: Any]] {
        (self["persons"] as? [[String: Any]]) ?? []
    }

    /// Die Klassen aus dieser Karte – jede mit `id` und `name`.
    var klassen: [[String: Any]] {
        (self["classes"] as? [[String: Any]]) ?? []
    }

    /// Sollen die Personen gar nicht erst gezeigt werden?
    ///
    /// `false`, solange Dart nichts gesagt hat – die Voreinstellung in `VPlan`
    /// ist `false`, also die, die die meisten sehen. Wer sie geändert hat, hat
    /// es gesagt bekommen; wer nicht, sieht sie.
    var versteckePersonen: Bool {
        (self["hidePersons"] as? Bool) ?? false
    }

    /// Die Einträge des Sync-Bildschirms – jeder mit `id`, `title`, `subtitle`.
    var eintraege: [[String: Any]] {
        (self["entries"] as? [[String: Any]]) ?? []
    }
}