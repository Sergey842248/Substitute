import Foundation

/// Ein Kürzel aus dem Vertretungsplan und der Name, den man dafür einträgt.
///
/// Zwei Felder und sonst nichts. Der Plan kennt nur das Kürzel; der Name ist eine
/// Ergänzung, die auf **diesem** Gerät steht – deshalb wird er auch hier
/// gespeichert und nicht im Plan.
struct Lehrerkuerzel {
    var kuerzel: String
    var echterName: String
}

/// Die Lehrerkürzel – lesen, speichern und die Kürzel holen.
///
/// ## Warum das überhaupt in Swift steht
///
/// Der Bildschirm lag bisher in Flutter, weil er den Vertretungsplan brauchte: Die
/// Liste der Lehrenden steht im Plan, den der VPlan liefert – samt Einloggen,
/// Abruf und Fehlerbehandlung. Ein zweites Mal in einer zweiten Sprache wäre doppelte
/// Arbeit – aber **hier** ist sie zum ersten Mal nötig.
///
/// Der Plan selbst wird dabei **nicht** noch einmal gebaut. Gelesen werden nur die
/// `KKz`-Elemente – statt der Plankonvertierung, des Caches und der Plandatei, die
/// Flutter daneben aufbaut.
///
/// ## Drei Wege zu derselben Liste
///
/// In dieser Reihenfolge, und jeder für sich genügt:
///
/// 1. **Aus dem Speicher** – das, was zuletzt geschrieben wurde. Geht sofort.
/// 2. **Aus den lokal gespeicherten Plänen** – ohne Netz, ohne Warten. Das ist der
///    Grund, warum der Bildschirm beim Öffnen meist sofort etwas zeigt.
/// 3. **Aus dem Netz** – nur, wenn die beiden ersten nichts kennen, oder wenn man
///    selbst auf Aktualisieren tippt.
///
/// Der erste Weg allein wäre falsch: Nach einem Wechsel auf einen anderen
/// Schulbereich stünde dort die Liste der **vorherigen** Schule, und niemand hätte
/// einen Grund, sie zu erneuern.
enum TeacherShortsStore {
    /// Die Zugangsdaten des Demo-Accounts.
    ///
    /// Dieselben drei Werte wie in `VPlanAPI`, und aus demselben Grund auch dort
    /// stehengeblieben: Sie sind der einzige Weg, den Demo von einer echten Schule
    /// zu unterscheiden.
    static let demoSchulnummer = "123456"
    static let demoBenutzer = "user"
    static let demoPasswort = "password"

    /// Die Kürzel des Demokontos.
    ///
    /// Dieselben zwölf wie in `DemoData._teacherNames`, und **nicht** aus dem Plan
    /// gelesen – im Demo gibt es keinen. Sie stehen hier ausgeschrieben, weil
    /// eine halbe Liste schlimmer ist als gar keine.
    static let demoKuerzel = [
        "MUE", "SCH", "KRU", "WEB", "FIS", "BEC",
        "HOF", "LAN", "KOE", "BAU", "SCU", "RIC",
    ]

    // ------------------------------------------------------------ Gespeichert

    /// Die Kürzel, wie sie dastehen.
    ///
    /// Ein beschädigter Text ergibt eine **leere** Liste und keine Ausnahme: Der
    /// Wert steht in einer Ablage, die ein Import mit einem anderen Format
    /// hinterlassen haben kann, und eine leere Liste ist ein Fehler, den man sieht.
    /// Ein Absturz wäre es nicht.
    static func gespeichert() -> [Lehrerkuerzel] {
        guard let text = AppStore.string("teacherShorts"),
            let daten = text.data(using: .utf8),
            let eingelesen = try? JSONSerialization.jsonObject(with: daten)
                as? [[String: Any]]
        else { return [] }

        return eingelesen.compactMap { eintrag in
            // Ohne Kürzel ist die Zeile sinnlos: Sie könnte nirgends eingeordnet
            // werden, und ein leerer Name stünde beim Speichern für sich da.
            guard let kuerzel = eintrag["short"] as? String, !kuerzel.isEmpty else {
                return nil
            }
            return Lehrerkuerzel(
                kuerzel: kuerzel, echterName: eintrag["realName"] as? String ?? "")
        }
    }

    /// Schreibt die Liste zurück.
    ///
    /// Derselbe Text, den `TeacherShorts.dart` schreibt – `short` und `realName`
    /// als Liste von Objekten. Ein anderes Format wäre zwar für diese Seite
    /// unsichtbar, aber der Sync-Teil der App und der Export wüssten nicht mehr,
    /// was sie dort vorfinden.
    static func speichern(_ liste: [Lehrerkuerzel]) {
        let eingelesen = liste.map { eintrag -> [String: String] in
            ["short": eintrag.kuerzel, "realName": eintrag.echterName]
        }
        guard let daten = try? JSONSerialization.data(withJSONObject: eingelesen),
            let text = String(data: daten, encoding: .utf8)
        else { return }
        AppStore.setString(text, for: "teacherShorts")
    }

    /// Ergänzt neue Kürzel und lässt die eingetragenen Namen stehen.
    ///
    /// Was **schon** im Speicher steht, bleibt unangetastet – auch dann, wenn der
    /// Plan es nicht mehr hergibt. Ein Kürzel, das aus dem Plan verschwindet,
    /// heisst meist, dass der Eintrag stillschweigend umbenannt wurde; der Name,
    /// den man dafür eingetragen hat, wäre sonst spurlos weg.
    static func ergaenzen(_ neu: [String]) -> [Lehrerkuerzel] {
        var vorhanden = gespeichert()
        let bekannt = Set(vorhanden.map { $0.kuerzel })
        var ergaenzt = false
        for kuerzel in neu.sorted() where !bekannt.contains(kuerzel) {
            vorhanden.append(Lehrerkuerzel(kuerzel: kuerzel, echterName: ""))
            ergaenzt = true
        }
        vorhanden.sort { $0.kuerzel < $1.kuerzel }
        if ergaenzt { speichern(vorhanden) }
        return vorhanden
    }

    // -------------------------------------------------------- Aus den Plänen

    /// Die Lehrenden, die in den **lokal gespeicherten Plänen** stehen.
    ///
    /// Ohne Netz und ohne Warten – der Grund, warum der Bildschirm beim Öffnen
    /// meist sofort etwas zu zeigen hat.
    ///
    /// ## Warum nur der **erste** brauchbare Plan geöffnet wird
    ///
    /// Ein Plan ist ein grosses Stück Text: Klassen, Kurse, Räume, Stunden. Ein
    /// Gerät, das seit Wochen nicht aufgeräumt wurde, hat davon Dutzende – und alle
    /// nacheinander zu öffnen, nur um dieselben Lehrenden zu finden, wäre Arbeit
    /// ohne Ergebnis. Sobald ein Plan Namen liefert, ist die Frage beantwortet.
    static func ausGespeichertenPlaenen() -> [String] {
        // Der Wert gehört zum **aktiven** Bereich – siehe [AppStore.key]. Deshalb
        // wird nicht `plainKey` genommen: Nach einem Wechsel auf eine zweite
        // Schule stünde sonst noch der Plan der ersten.
        guard let texte = AppStore.alleWerte()[AppStore.key("offlineVPData")]
            as? [Any]
        else { return [] }

        for eintrag in texte {
            guard let text = eintrag as? String,
                let daten = text.data(using: .utf8),
                let plan = try? JSONSerialization.jsonObject(with: daten)
                    as? [String: Any],
                let kurse = plan["courses"] as? [Any]
            else { continue }

            let namen = lehrendeAusKursen(kurse)
            if !namen.isEmpty { return namen }
        }
        return []
    }

    private static func lehrendeAusKursen(_ kurse: [Any]) -> [String] {
        var gefunden: [String] = []
        for kurs in kurse {
            guard let eintrag = kurs as? [String: Any],
                let lehrender = eintrag["teacher"] as? String,
                !lehrender.isEmpty
            else { continue }
            gefunden.append(lehrender)
        }
        // Ohne Doppelungen: Ein Lehrender hat in einem Plan viele Kurse.
        return Array(Set(gefunden)).sorted()
    }

    // ------------------------------------------------------------ Aus dem Netz

    /// Warum das Holen nicht geklappt hat.
    ///
    /// Die Fälle werden getrennt, weil man auf sie **unterschiedlich** reagiert:
    /// Bei fehlenden Zugangsdaten hilft nur die Anmeldeseite, bei einem
    /// Verbindungsfehler ein späterer Versuch – und beides sieht man am Bildschirm
    /// nur, wenn die Meldung sagt, was los war.
    enum NetzFehler: Error {
        case keineZugangsdaten
        case nichtAngemeldet
        case schulnummerFalsch
        case serverFehler(Int)
        case verbindung
    }

    /// Holt die Kürzel frisch vom VPlan.
    ///
    /// ## Was hier **nicht** passiert – und warum das in Ordnung ist
    ///
    /// `VPlanAPI.getVPlanJSON` macht viel mehr: Es prüft den Kurzzeit-Cache, sucht
    /// offline nach Plänen, wandelt den XML-Text in ein eigenes Format um, legt
    /// das Ergebnis in den Planspeicher und rechnet die Wochenzuordnung neu.
    ///
    /// All das wird hier **nicht** gebraucht, und es wäre auch schädlich: Der
    /// Plan, den dieser Bildschirm holt, ist derselbe, den nebenan gerade der
    /// Plan-Reiter holt. Zwei gleichzeitige Abrufe mit zwei gleichzeitigen
    /// Schreibvorgängen in denselben Planspeicher wären genau die doppelte Arbeit,
    /// die unter der nativen Schale ausdrücklich vermieden wird – und die Pläne
    /// wären danach in einer Reihenfolge, die niemand mehr erklären kann.
    ///
    /// Geholt wird nur die eine Sache, die hier gebraucht wird: die Kürzel.
    static func holeAusNetz() async throws -> [String] {
        let daten = AppStore.Credentials.lesen()

        // Der Demo-Account hat keinen Server: Seine Lehrenden stehen fest. Ohne
        // diesen Zweig bliebe dieser Bildschirm auf dem Demokonto immer leer –
        // obwohl es genau die Kürzel gibt, um die es geht.
        if daten.schoolNumber == demoSchulnummer,
            daten.username == demoBenutzer,
            daten.password == demoPasswort
        {
            return demoKuerzel
        }

        // Ohne Schulnummer **und** ohne eigene URL gibt es nichts, wonach gefragt
        // werden könnte – und `Int.parse` in Dart würde hier sogar abstürzen.
        guard !daten.customUrl.isEmpty || !daten.schoolNumber.isEmpty else {
            throw NetzFehler.keineZugangsdaten
        }

        var anfrage = URLRequest(url: Self.planURL(daten))
        // Nur bei stundenplan24: Eine selbst gehostete Instanz trägt die
        // Anmeldung nicht – so ist es auch in `VPlanAPI`.
        if daten.customUrl.isEmpty {
            anfrage.setValue(
                Self.zugangsdaten(daten), forHTTPHeaderField: "Authorization")
        }

        let (empfangen, antwort) = try await URLSession.shared.data(for: anfrage)
        guard let http = antwort as? HTTPURLResponse else {
            throw NetzFehler.verbindung
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw NetzFehler.nichtAngemeldet
        }
        // Der Server antwortet bei falscher Schulnummer mit **200** und einem
        // erklärenden Text – deshalb wird nicht nur der Code angesehen. Siehe
        // `VPlanAPI._getVPlanJSONAusfuehren`, das aus demselben Grund so vorgeht.
        if let text = String(data: empfangen, encoding: .utf8),
            text.contains("Die eingegebene Schulnummer wurde nicht gefunden")
        {
            throw NetzFehler.schulnummerFalsch
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NetzFehler.serverFehler(http.statusCode)
        }
        return KursParser.lehrende(in: empfangen)
    }

    /// Die Adresse des Plans – dieselbe, die `VPlanAPI.getDayURL` baut.
    private static func planURL(_ daten: AppStore.Credentials) -> URL {
        if !daten.customUrl.isEmpty {
            // `customUrl` kommt aus einem Eingabefeld; ein Text, der kein gültiger
            // Speicherort ist, ist beim Speichern der Anmeldung aufgefallen. Die
            // zweite Datei oben in diesem Bildschirm fängt den Rest ab.
            return urlAusText(daten.customUrl + "mobdaten/Klassen.xml")
        }
        // Das Kodieren ist hier **nicht** Kosmetik: Die Schulnummer kommt aus einem
        // Eingabefeld, und `URL(string:)` gibt `nil` zurück, sobald ein Zeichen
        // vorkommt, das in einer Adresse nichts zu suchen hat. Bei Schulnummern
        // sind das Bindestriche und Schrägstriche – ausdrücklich erlaubt, siehe
        // [CredentialsScreen].
        return urlAusText(
            "https://www.stundenplan24.de/\(daten.schoolNumber)"
                + "/mobil/mobdaten/Klassen.xml")
    }

    /// Macht aus einem Text eine Adresse – und kodiert vorher das, was `URL(string:)`
    /// sonst ablehnen würde.
    ///
    /// Der naheliegende Einzeiler dafür wäre
    /// `URL(string:encodingInvalidCharacters: true)`, den gibt es aber erst ab
    /// iOS 17 – dieses Projekt baut bis iOS 15, deshalb diese Streichung von Hand.
    ///
    /// Zuerst der Versuch ohne Kodierung: Eine bereits saubere Adresse bleibt
    /// unangetastet, und ein schon kodiertes `%` wird nicht zu `%25`. Erst wenn
    /// `URL(string:)` `nil` liefert, wird wirklich ein unzulässiges Zeichen im
    /// Text stecken und kodiert. Erlaubt bleiben die Zeichen, die in einer Adresse
    /// Bedeutung haben (`/`, `:`, `@`, `?`, `&`, `=` usw.); Leerzeichen, Umlaute
    /// und alles Übrige werden prozentkodiert.
    ///
    /// Bleibt auch das ohne Ergebnis, wird die Adresse der Demo-Schule verwendet:
    /// Die Anmeldedaten sind vorher geprüft worden, ein Absturz an dieser Stelle
    /// wäre für niemanden hilfreich.
    private static func urlAusText(_ text: String) -> URL {
        if let direkt = URL(string: text) {
            return direkt
        }
        let erlaubt = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                + "abcdefghijklmnopqrstuvwxyz0123456789"
                + "-._~:/?#[]@!$&'()*+,;=%")
        if let kodiert = text.addingPercentEncoding(withAllowedCharacters: erlaubt),
            let url = URL(string: kodiert)
        {
            return url
        }
        return URL(
            string: "https://www.stundenplan24.de/mobil/mobdaten/Klassen.xml")!
    }

    /// Der Kopf mit Benutzername und Passwort – dieselbe Anmeldung wie in Dart.
    private static func zugangsdaten(_ daten: AppStore.Credentials) -> String {
        let roh = "\(daten.username):\(daten.password)"
        return "Basic " + Data(roh.utf8).base64EncodedString()
    }
}

/// Liest die Kürzel aus dem Plan-XML.
///
/// ## Der eine Ort, an dem das Format des Plans steht
///
/// In `Klassen.xml` sieht eine Kursangabe so aus:
///
/// ```xml
/// <Kl><Kurz>5a</Kurz><Kurse><Ku><KKz user="MUE">Deutsch</KKz></Ku></Kurse></Kl>
/// ```
///
/// Das Kürzel des Lehrenden ist ein **Attribut** von `KKz` – nicht der Text darin,
/// der ist der Kurs. stundenplan24 nennt es `user`; eine selbst gehostete
/// Instanz spricht demselben Schema folgend ebenfalls von `user`.
///
/// ## Warum hier nach dem **Namen** gefragt wird und nicht nach der Stelle
///
/// `VPlanAPI` nimmt das *erste* Attribut (`kkz.attributes.first.value`), weil das
/// XML-Paket dort die Reihenfolge behält. `XMLParser` liefert die Attribute als
/// [Dictionary], und ein Dictionary hat **keine** Reihenfolge – „das erste"
/// wäre dort ein Zufall, der sich mit jeder iOS-Version ändern kann.
///
/// Deshalb wird ausdrücklich nach `user` gefragt. Bei `KKz` ist das dieselbe
/// Stelle, auf die die Dart-Seite zeigt; nur ist sie hier benannt statt
/// gezählt.
enum KursParser {
    /// Die Kürzel aus einem Plan, im Alphabet und ohne Doppelungen.
    static func lehrende(in daten: Data) -> [String] {
        // Das BOM steht in manchen Dateien vor der ersten Marke, und `XMLParser`
        // steigt darauf mit "Malformed document" aus. Dart überspringt es
        // aus demselben Grund.
        var text = String(data: daten, encoding: .utf8)
            ?? String(decoding: daten, as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        let sammler = Sammler()
        let parser = XMLParser(data: Data(text.utf8))
        parser.delegate = sammler
        guard parser.parse() else { return [] }
        return Array(Set(sammler.kuerzel)).sorted()
    }

    /// Nimmt während des Lesens alle `KKz` auf.
    private final class Sammler: NSObject, XMLParserDelegate {
        private(set) var kuerzel: [String] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String]
        ) {
            guard elementName == "KKz",
                let wert = attributeDict["user"],
                !wert.isEmpty
            else { return }
            kuerzel.append(wert)
        }
    }
}
