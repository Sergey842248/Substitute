import Foundation

/// Sichern und Wiederherstellen der gesamten Konfiguration – **ohne** Bildschirm.
///
/// ## Warum das hier in Swift steht und nicht in Flutter
///
/// Der Bildschirm lag bisher in Flutter, weil er drei Pakete brauchte:
/// `file_picker`, `share_plus` und `ConfigBackup`. Die ersten beiden sind
/// dünne Hüllen um genau die zwei Dinge, die iOS selbst mitbringt –
/// [UIDocumentPickerViewController] und [UIActivityViewController]. Das dritte
/// ist eine Liste von Schlüsseln, die hier ohnehin schon steht: Es sind genau
/// die Werte, um die es in [AppStore] geht.
///
/// Damit blieb als Argument „bleibt in Flutter" nur noch das Framework, und das
/// trägt nicht: Eine ganze Dart-Isolate, die am Anfang hochfährt und danach den
/// Platz belegt, wäre ein zweiter Speicher im selben Bildschirm.
///
/// ## Dieselbe Datei auf beiden Plattformen
///
/// Das Format hier ist **das von `ConfigBackup.dart`**, Zeichen für Zeichen:
/// derselbe Bezeichner in `app`, dieselbe `schema`-Nr. und dieselbe Liste der
/// Schlüssel, die nicht mitgesichert werden. Das ist keine Absicht, sondern die
/// Bedingung dafür, dass eine Datei, die auf dem Handy erzeugt wurde, auf dem
/// iPhone etwas wiederherstellt – und umgekehrt.
///
/// Die Regel steht in der einen Datei, die sie betrifft, in der anderen auch:
/// Wer einen Schlüssel hier ergänzt, muss ihn in `ConfigBackup.dart` ergänzen.
enum ConfigBackupStore {
    /// Die Formatversion der Datei.
    ///
    /// Muss [schemaVersion] in `ConfigBackup.dart` entsprechen. Wird sie hier
    /// erhöht, ohne dass es dort geschieht, lehnt die andere Plattform die
    /// Dateien ab, die diese schreibt – und umgekehrt.
    static let schemaVersion = 1

    /// Die Kennung, an der erkannt wird, dass die Datei von **dieser** App ist.
    static let appIdentifier = "substitute"

    /// Der Anfang jedes Dateinamens.
    ///
    /// Unverändert übernommen: Der Name ist das, was man in einer Liste
    /// wiedererkennt, und zwei Namen für dieselbe Sache wären schlechter als
    /// einer.
    static let exportFileNamePrefix = "Substitute-Export___"

    /// Schlüssel, die **weder** exportiert **noch** importiert werden.
    ///
    /// `overriddenNow` ist eine Entwickler-Override der Uhr – sie gehört zu
    /// diesem Gerät und nicht zu dem, was man auf ein anderes mitnimmt.
    static let sensitiveKeys = ["overriddenNow"]

    /// Schlüssel, die Zugangsdaten enthalten.
    ///
    /// Sie werden mitgesichert, damit ein Import auf einem neuen Gerät die App
    /// sofort nutzbar macht. Die Datei enthält damit das Passwort im Klartext –
    /// deshalb fragt der Bildschirm vor dem Teilen nach.
    static let credentialKeys = ["vplanPassword", "vplanUsername", "vplanSchoolnumber"]

    // ------------------------------------------------------------- Die Regeln

    /// Gehört dieser Schlüssel zu den Zugangsdaten?
    ///
    /// Die Liste allein genügt nicht: Die Zugangsdaten werden **pro Schulbereich**
    /// gespeichert, und die heissen dort `schools.<id>.vplanUsername`. Ohne den
    /// zweiten Teil der Frage würde ein Export einer zweiten Schule genau die
    /// Werte nicht als Zugangsdaten erkennen, um die es hier geht – und der
    /// Bildschirm würde die Warnung nicht zeigen.
    static func istZugangsdatenSchluessel(_ name: String) -> Bool {
        if credentialKeys.contains(name) { return true }
        return credentialKeys.contains { name.hasSuffix(".\($0)") }
    }

    /// Enthält diese Datei Zugangsdaten?
    static func enthaeltZugangsdaten(_ settings: [String: Any]) -> Bool {
        settings.keys.contains { istZugangsdatenSchluessel($0) }
    }

    /// Gehört dieser Schlüssel gar nicht zur Konfiguration?
    ///
    /// ## Warum der Name **hinten** verglichen wird
    ///
    /// Die Schlüssel liegen in der Datei mit dem `flutter.`-Vorsatz, den
    /// `shared_preferences` setzt. Ein Vergleich auf **Gleichheit** fände
    /// `flutter.overriddenNow` also nicht – und die Entwickler-Override würde
    /// mitgesichert, während die Regel daneben behauptet, sie sei ausgenommen.
    ///
    /// Deshalb wird hinten verglichen: Sowohl der nackte Name als auch der mit
    /// Vorsatz und Schulbereich finden denselben Schlüssel. Dieselbe Regel steht
    /// in `ConfigBackup._isExcluded`.
    static func istAusgeschlossen(_ name: String) -> Bool {
        if sensitiveKeys.contains(where: { hatEndung(name, $0) }) { return true }
        // Der Kurzzeit-Cache der Pläne samt seiner Zeitstempel. Auch die
        // schulbezogenen Formen – sonst würde der Cache einer zweiten Schule mit
        // exportiert.
        if name.contains("vplan_cache_") { return true }
        if name.hasSuffix("_time") && name.contains("vplan_cache") { return true }
        return false
    }

    /// Trägt dieser Schlüssel die lokal gespeicherten Pläne?
    ///
    /// `flutter.offlineVPData` passt **nicht** auf `== "offlineVPData"`, aber sehr
    /// wohl auf `.offlineVPData` – deshalb wird hinten verglichen.
    static func istPlanSchluessel(_ name: String) -> Bool {
        name.hasSuffix(".offlineVPData") || name == "offlineVPData"
    }

    /// Endet `name` auf `ende` – gegebenenfalls mit einem Punkt davor.
    private static func hatEndung(_ name: String, _ ende: String) -> Bool {
        name == ende || name.hasSuffix(".\(ende)")
    }

    // --------------------------------------------------------------- Export

    /// Liest die Ablage und baut daraus den Inhalt einer Exportdatei.
    ///
    /// - Parameter mitZugangsdaten: `false` lässt die Zugangsdaten weg – für
    ///   Dateien, die weitergegeben werden, ohne das Passwort preiszugeben. Ein
    ///   solcher Export lässt sich später trotzdem importieren.
    static func baueExport(mitZugangsdaten: Bool) -> [String: Any] {
        var settings: [String: Any] = [:]
        for (name, wert) in AppStore.alleWerte() {
            if istAusgeschlossen(name) { continue }
            if !mitZugangsdaten && istZugangsdatenSchluessel(name) { continue }
            // Werte, die JSON nicht kennt – etwa `Data` – fliegen raus, statt
            // die ganze Sicherung zu sprengen.
            guard let normiert = normalisiere(wert) else { continue }
            settings[name] = normiert
        }
        return [
            "app": appIdentifier,
            "schema": schemaVersion,
            "cachedPlans": zaehleGespeichertePlaene(settings),
            "settings": settings,
        ]
    }

    /// Wie viele Pläne stecken in diesen Werten?
    ///
    /// Steht als Metadatum in der Datei, damit man **vor** dem Import sieht,
    /// was darin ist.
    static func zaehleGespeichertePlaene(_ settings: [String: Any]) -> Int {
        var anzahl = 0
        for (name, wert) in settings where istPlanSchluessel(name) {
            if let liste = wert as? [Any] { anzahl += liste.count }
        }
        return anzahl
    }

    /// Macht aus einem Wert etwas, das JSON kennt.
    ///
    /// Verschachtelte Listen werden zu Text – dasselbe macht `ConfigBackup._sanitize`
    /// in Dart. Die App speichert alles als Text, Wahrheitswert, Zahl oder
    /// Textliste; alles andere gehört nicht in eine Konfigurationsdatei.
    private static func normalisiere(_ wert: Any) -> Any? {
        switch wert {
        case let text as String: return text
        case let zahl as NSNumber: return zahl
        case let liste as [Any]:
            return liste.map { element -> String in
                if let text = element as? String { return text }
                return "\(element)"
            }
        default: return nil
        }
    }

    /// Serialisiert einen Export als JSON-Text.
    static func kodiere(
        _ export: [String: Any],
        exportiertAm: Date,
        appVersion: String
    ) -> String? {
        var vollstaendig = export
        // `DateTime.toIso8601String()` in Dart – und dieselbe Schreibweise wie in
        // [AppStore.isoText]. Siehe dort, warum ohne Zeitzone.
        vollstaendig["exportedAt"] = AppStore.isoText(exportiertAm)
        vollstaendig["appVersion"] = appVersion

        guard JSONSerialization.isValidJSONObject(vollstaendig),
            let daten = try? JSONSerialization.data(
                withJSONObject: vollstaendig,
                options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: daten, encoding: .utf8)
        else { return nil }
        return text
    }

    /// Der Name der Exportdatei: Präfix, Datum und Uhrzeit.
    ///
    /// Genau wie in `ConfigBackupFlow.exportFileName`: `…___2026-09-27___14-35-02.json`.
    /// Ausgeschrieben wird die Uhr des Geräts – bzw. die überschriebene, wenn
    /// die Entwickleroptionen sie gesetzt haben, denn das ist die Zeit, vor der
    /// der Bildschirm seine **Anzeige** gebaut hat.
    static func dateiName(fuer zeit: Date = AppStore.aktuelleZeit) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let datum = formatter.string(from: zeit)
        formatter.dateFormat = "HH-mm-ss"
        let uhrzeit = formatter.string(from: zeit)
        return "\(exportFileNamePrefix)\(datum)___\(uhrzeit).json"
    }

    /// Die Versionsangabe, die in die Datei kommt.
    ///
    /// Dieselbe Zahl, die `PackageInfo.fromPlatform()` in Dart liefert: der Wert
    /// aus `Info.plist` unter `CFBundleShortVersionString`.
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    // --------------------------------------------------------------- Import

    /// Warum eine Datei nicht gelesen werden konnte.
    ///
    /// Drei Fälle, drei **verschiedene** Antworten an den Nutzer: Eine fremde
    /// Datei und eine aus einer neueren Version sind zwei verschiedene Probleme,
    /// und beide verdienen einen eigenen Satz. Verschmilzt man sie zu „Die Datei
    /// konnte nicht gelesen werden", weiss niemand mehr, was zu tun ist.
    enum LeseFehler: Error {
        case ungueltigesJson
        case fremdeApp
        case neuereVersion
        case ungueltigeEinstellungen
    }

    /// Liest die Schlüssel-Wert-Paare aus einem JSON-Text.
    static func lieseExport(_ text: String) throws -> [String: Any] {
        guard let daten = text.data(using: .utf8),
            let eingelesen = try? JSONSerialization.jsonObject(with: daten)
                as? [String: Any]
        else { throw LeseFehler.ungueltigesJson }

        guard eingelesen["app"] as? String == appIdentifier else {
            throw LeseFehler.fremdeApp
        }
        let schema = (eingelesen["schema"] as? NSNumber)?.intValue ?? 0
        // Eine Datei aus einer **neueren** App wird abgelehnt, nicht halb gelesen:
        // Sie kann Felder enthalten, die diese Version nicht kennt, und ein
        // halb gelesener Zustand ist schlimmer als ein klarer Fehler.
        guard schema <= schemaVersion else { throw LeseFehler.neuereVersion }

        guard let settings = eingelesen["settings"] as? [String: Any] else {
            throw LeseFehler.ungueltigeEinstellungen
        }

        var aufbereitet: [String: Any] = [:]
        for (name, wert) in settings {
            // Verschachtelte Zuordnungen werden nicht übernommen: Die App liest
            // alles als Text, Zahl, Wahrheitswert oder Textliste, und eine
            // verschachtelte Zuordnung kann keiner davon sein. `null` ebenso
            // wenig – „nicht gesetzt" lässt man lieber weg, statt es zu einer
            // leeren Datei zu machen.
            if wert is [String: Any] || wert is NSNull { continue }
            aufbereitet[name] = wert
        }
        return aufbereitet
    }

    /// Was ein Import mit den Werten gemacht hat.
    struct Ergebnis {
        var uebernommen = 0
        var entfernt = 0
        var uebersprungen = 0
    }

    /// Schreibt eine zuvor gelesene Konfiguration zurück.
    ///
    /// - Parameter ersetzen: `true` entfernt vorher alle Konfigurationsschlüssel,
    ///   die **nicht** in der Datei stehen; sonst werden nur die Schlüssel der
    ///   Datei überschrieben.
    ///
    /// ## Zugangsdaten werden nur entfernt, wenn die Datei welche mitbringt
    ///
    /// Das ist die eine Ausnahme von „alles wird ersetzt", und sie ist keine
    /// Rechenfrage, sondern eine Frage danach, was der Nutzer gerade gedrückt
    /// hat.
    ///
    /// Eine Konfiguration ohne Zugangsdaten entsteht **absichtlich**: Der Export
    /// fragt vorher, ob sie mit in die Datei sollen, und wer sie nicht
    /// weitergeben will, wählt „ohne". Solche Dateien landen in Chatverläufen und
    /// auf fremden Geräten.
    ///
    /// Behandelt man sie wie jede andere, passiert Folgendes: „Ersetzen" entfernt
    /// jeden Schlüssel, der nicht in der Datei steht – und die Zugangsdaten des
    /// Geräts stehen nicht darin. Sie sind weg. Die App zeigt danach die
    /// Anmeldeseite, und wer das Passwort nicht weiss, ist draussen. Aus einem
    /// Import, der nur die Konfiguration wiederherstellen sollte, ist ein
    /// Datenverlust geworden.
    ///
    /// Die Regel ist deshalb: **Keine Zugangsdaten in der Datei, keine Änderung an
    /// den lokalen.** Es betrifft nur das Entfernen; was die Datei selbst
    /// enthält, wird wie bisher übernommen.
    static func wendeImportAn(
        _ settings: [String: Any], ersetzen: Bool
    ) -> Ergebnis {
        var ergebnis = Ergebnis()
        let zugangsdatenAnfassen = enthaeltZugangsdaten(settings)

        if ersetzen {
            for name in AppStore.alleSchluessel() {
                if istAusgeschlossen(name) { continue }
                if settings[name] != nil { continue }
                if !zugangsdatenAnfassen && istZugangsdatenSchluessel(name) {
                    continue
                }
                AppStore.entferneRoh(name)
                ergebnis.entfernt += 1
            }
        }

        // Feste Reihenfolge, damit die Meldung am Ende reproduzierbar ist:
        // `dictionaryRepresentation()` liefert die Schlüssel in keiner
        // bestimmten Reihenfolge.
        var lokalePlaene: [String: [String]] = [:]
        if !ersetzen {
            // Die lokal gespeicherten Pläne werden **vor** der Schleife und
            // **einmal** gelesen: Sie zu kopieren kostet, und eine Datei mit
            // Plänen aus drei Schulbereichen hätte sonst dreimal denselben Wert.
            // Beim Ersetzen wird ohnehin gleich gelöscht, was da ist – da gibt es
            // nichts zu vereinigen.
            // Die lokal gespeicherten Pläne werden **vor** der Schleife und
            // **einmal** gelesen: Sie zu kopieren kostet, und eine Datei mit
            // Plänen aus drei Schulbereichen hätte sonst dreimal denselben Wert.
            // Beim Ersetzen wird ohnehin gleich gelöscht, was da ist – da gibt es
            // nichts zu vereinigen.
            let vorhanden = AppStore.alleWerte()
            for name in settings.keys where istPlanSchluessel(name) {
                lokalePlaene[name] = (vorhanden[name] as? [Any])?
                    .compactMap { $0 as? String } ?? []
            }
        }

        for name in settings.keys.sorted() {
            guard let wert = settings[name] else {
                ergebnis.uebersprungen += 1
                continue
            }
            if istAusgeschlossen(name) {
                ergebnis.uebersprungen += 1
                continue
            }

            var zuSchreiben: Any = wert
            if istPlanSchluessel(name) {
                guard let valide = nurGueltigePlaene(wert) else {
                    ergebnis.uebersprungen += 1
                    continue
                }
                // Beim Ergänzen werden die lokalen Pläne **nicht** ersetzt, sondern
                // mit denen der Datei vereinigt – sonst gingen gerade auf dem
                // neuen Gerät nachgeladene Tage verloren.
                if !ersetzen {
                    zuSchreiben = vereinigePlaene(
                        bestehend: lokalePlaene[name] ?? [], importiert: valide)
                }
            }

            AppStore.setzeRoh(plaeneOderSkalar(zuSchreiben), fuer: name)
            ergebnis.uebernommen += 1
        }
        return ergebnis
    }

    /// Bringt einen Wert in die Form, in der die Ablage ihn erwartet.
    ///
    /// `UserDefaults` kennt `Bool`, `Int`, `Double`, `String` und `Array`. Aus
    /// einem JSON-Text kommt aber `NSNumber`, und das ist für die **Zwei-Erster-
    /// Fälle** wichtig: Ein Wahrheitswert, der als Zahl ankommt, liest sich auf
    /// der Dart-Seite als Zahl – und ein Schalter, der auf `false` steht, wäre
    /// auf der anderen Seite plötzlich eine `0`.
    private static func plaeneOderSkalar(_ wert: Any) -> Any {
        if let liste = wert as? [Any] {
            return liste.map { element -> String in
                if let text = element as? String { return text }
                return "\(element)"
            }
        }
        guard let zahl = wert as? NSNumber else { return wert }
        // `CFBooleanGetTypeID` erkennt genau die zwei Wahrheitswerte; alles
        // andere ist eine Zahl.
        if CFGetTypeID(zahl) == CFBooleanGetTypeID() { return zahl.boolValue }
        if CFNumberIsFloatType(zahl) { return zahl.doubleValue }
        return zahl.intValue
    }

    // ------------------------------------------------------ Die Pläne darin

    /// Wirft Pläne heraus, die nicht mehr lesbar sind.
    ///
    /// Die Pläne werden beim Laden als JSON gelesen; ein einzelner unlesbarer
    /// Eintrag – etwa weil die Datei von Hand bearbeitet wurde – würde sonst beim
    /// Anzeigen der Vergangenheit einen Fehler auslösen. Defekte Einträge werden
    /// deshalb stillschweigend verworfen.
    private static func nurGueltigePlaene(_ wert: Any) -> [String]? {
        guard let liste = wert as? [Any] else { return nil }
        var gueltig: [String] = []
        for eintrag in liste {
            guard let text = eintrag as? String, istLesbarerPlan(text) else {
                continue
            }
            gueltig.append(text)
        }
        return gueltig
    }

    /// Steht in diesem Text ein lesbarer Plan?
    private static func istLesbarerPlan(_ text: String) -> Bool {
        guard let daten = text.data(using: .utf8),
            let eingelesen = try? JSONSerialization.jsonObject(with: daten)
        else { return false }
        return eingelesen is [String: Any]
    }

    /// Vereinigt die lokal gespeicherten Pläne mit denen aus der Datei.
    ///
    /// Gleiche Tage werden nicht doppelt übernommen: Der Eintrag der Datei gewinnt
    /// – er ist die gewünschte Wiederherstellung –, und die Reihenfolge bleibt
    /// chronologisch nach dem Datum des Plans.
    private static func vereinigePlaene(
        bestehend: [String], importiert: [String]
    ) -> [String] {
        if bestehend.isEmpty { return importiert }

        var nachDatum: [String: String] = [:]
        var ohneDatum: [String] = []
        for plan in bestehend + importiert {
            guard let datum = planDatum(plan), !datum.isEmpty else {
                // Ein Plan ohne lesbares Datum: nicht zusammenfassen, aber
                // behalten.
                ohneDatum.append(plan)
                continue
            }
            nachDatum[datum] = plan
        }

        let sortiert = nachDatum
            .values
            .sorted { (planDatum($0) ?? "") < (planDatum($1) ?? "") }
        return sortiert + ohneDatum
    }

    /// Das Datum eines Plan-Eintrags, an dem sich die Pläne unterscheiden.
    ///
    /// Wie in `ConfigBackup._planDate`: erst das Feld nebenan, und wenn es fehlt
    /// der Ort, an dem die API das Plantag ablegt.
    private static func planDatum(_ plan: String) -> String? {
        guard let daten = plan.data(using: .utf8),
            let eingelesen = try? JSONSerialization.jsonObject(with: daten)
                as? [String: Any]
        else { return nil }

        if let datum = eingelesen["date"], !(datum is NSNull) {
            return "\(datum)"
        }
        guard let kopf = (eingelesen["data"] as? [String: Any])?["Kopf"]
            as? [String: Any],
            let datum = kopf["DatumPlan"], !(datum is NSNull)
        else { return nil }
        return "\(datum)"
    }
}