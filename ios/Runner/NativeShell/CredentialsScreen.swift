import UIKit

/// Die Zugangsdaten für stundenplan24.
///
/// ## Warum die Felder ihren Stand **hier** halten
///
/// In Dart steht derselbe Bildschirm, aber die Felder leben im Bildschirm-
/// zustand und werden erst beim Speichern geschrieben. Das ist dort richtig,
/// weil die Seite auch beim allerersten Start als **Pflicht-Anmeldung** steht.
///
/// Hier wird nach jedem Tastendruck in den eigenen Stand geschrieben – aber
/// **nicht** in den Speicher. Der Unterschied ist wichtig: Was oben steht, ist
/// der Stand des Formulars; gespeichert wird erst beim Knopf. So kann man
/// zurückgehen, ohne etwas zu verlieren, und es wird trotzdem nichts geschrieben,
/// was man nicht bestätigt hat.
///
/// ## Der QR-Weg ist derselbe wie beim Teilen
///
/// Was [QRCodeScreen] anzeigt, wird hier gelesen – und umgekehrt. Wer die
/// Zugangsdaten auf einem Gerät eingibt, bekommt also einen Code, mit dem ein
/// zweites Gerät sie ohne Abtippen bekommt.
///
/// ## Warum die eigene URL ein **Schalter** ist und nicht immer ein Feld
///
/// Sie ist bei stundenplan24 nicht nötig und im Allfall falsch. Ein leeres Feld
/// über dem Plan, in das man etwas eintippt, wenn man nicht weiss, was es ist,
/// wäre ein Feld, das man erst verstehen muss, bevor man es ignorieren kann.
final class CredentialsScreen: FormScreen {
    /// Der Stand des Formulars.
    ///
    /// Er ist vom Speicher getrennt: [sichern] schreibt ihn dorthin, und sonst
    /// niemand. Ein halb getipptes Passwort darf nicht in den Speicher – es wäre
    /// dort auch nach dem Beenden der App noch zu finden.
    private var daten: AppStore.Credentials

    /// Steht die eigene URL zur Wahl?
    private var eigeneUrl: Bool

    init() {
        // Beides wird **vor** `super.init` gelesen: Der Schalter muss schon beim
        // ersten Aufbau stimmen, sonst stünde die Zeile „Eigene URL" einen
        // Frame lang da, obwohl sie weg gehört – oder umgekehrt.
        let gelesen = AppStore.Credentials.lesen()
        self.daten = gelesen
        self.eigeneUrl = !gelesen.customUrl.isEmpty
        super.init(title: L.settingsCredentials)
    }

    override func makeSections() -> [FormSection] {
        [
            FormSection(
                footer: eigeneUrl ? L.useLogin : L.useSelfHost,
                rows: felder()),

            FormSection(
                rows: [
                    .schalter(
                        titel: L.useOwnUrl,
                        untertitel: L.useOwnUrlSubtitle,
                        symbol: "link",
                        wert: eigeneUrl
                    ) {[weak self] neu in
                        self?.eigeneUrl = neu
                        self?.neuLaden(animiert: true)
                    }
                ]),

            FormSection(
                header: L.settingsCredentials,
                rows: [
                    .wahl(
                        titel: L.shareCreds,
                        untertitel: L.shareCredsSubtitle,
                        symbol: "square.and.arrow.up"
                    ) {[weak self] in self?.teilen() },
                    .wahl(
                        titel: L.scanCreds,
                        untertitel: L.scanCredsSubtitle,
                        symbol: "qrcode.viewfinder"
                    ) {[weak self] in self?.scannen() },
                    .wahl(
                        titel: L.language,
                        untertitel: L.languageSubtitle,
                        symbol: "globe"
                    ) {[weak self] in self?.navigationController?.pushViewController(
                            LanguageScreen(), animated: true)
                    },
                ]),

            FormSection(
                footer: L.credentialsFooter,
                rows: [
                    .knopf(titel: L.save, untertitel: nil) {[weak self] in self?.sichern() }
                ]),
        ]
    }

    /// Die Felder, die **immer** da sind – und die eigene URL, wenn sie zur Wahl
    /// steht.
    ///
    /// Die eigene URL kommt mit in dieselbe Gruppe und nicht in eine eigene:
    /// Sie gehört zu den Zugangsdaten, und eine eigene Gruppe würde sie wie etwas
    /// anderes aussehen lassen, während sie dasselbe ist.
    private func felder() -> [FormRow] {
        var zeilen: [FormRow] = [
            .feld(
                titel: L.schoolNumber,
                platzhalter: "12345",
                symbol: "number",
                text: daten.schoolNumber,
                sicher: false,
                // `numbersAndPunctuation`: Auf einer Schulnummer stehen oft
                // Bindestriche oder Schrägstriche. Die reine Zifferntastatur
                // hätte sie nicht – und man könnte sie nicht eintippen.
                tastatur: .numbersAndPunctuation
            ) {[weak self] neu in self?.daten.schoolNumber = neu },

            .feld(
                titel: L.username,
                platzhalter: "vplan24",
                symbol: "person",
                text: daten.username,
                sicher: false,
                tastatur: .default
            ) {[weak self] neu in self?.daten.username = neu },

            .feld(
                titel: L.password,
                platzhalter: "••••••",
                symbol: "key",
                text: daten.password,
                // Sicher, und aus einem Grund: Diesen Wert muss niemand über der
                // Schulter mitlesen, und auf einem Bildschirm mit einem Vortrag
                // wäre er sonst für alle da.
                sicher: true,
                tastatur: .default
            ) {[weak self] neu in self?.daten.password = neu },
        ]

        if eigeneUrl {
            zeilen.append(
                .feld(
                    titel: L.selfHost,
                    platzhalter: "https://",
                    symbol: "network",
                    text: daten.customUrl,
                    sicher: false,
                    tastatur: .URL
                ) {[weak self] neu in self?.daten.customUrl = neu })
        }

        return zeilen
    }

    // -------------------------------------------------------------- Speichern

    private func sichern() {
        // Ohne den Schalter wird die eigene URL **geleert**, nicht bloß nicht
        // gespeichert: Sonst bliebe eine alte Adresse stehen, obwohl sie im
        // Bildschirm längst nicht mehr da ist – und der Login ginge weiterhin
        // dorthin.
        if !eigeneUrl { daten.customUrl = "" }

        daten.schreiben()
        melde(L.credsSaved)
    }

    // -------------------------------------------------------- QR & Sprache

    private func teilen() {
        // Gebaut aus dem **Formularstand**, nicht aus dem Speicher: Wer gerade
        // eine neue Schulnummer eingetragen hat, will die neue teilen, nicht die
        // gespeicherte von vorgestern.
        let inhalt = Self.alsText(
            schoolNumber: daten.schoolNumber,
            username: daten.username,
            password: daten.password,
            customUrl: eigeneUrl ? daten.customUrl : "")
        navigationController?.pushViewController(
            QRCodeScreen(titel: L.shareCreds, inhalt: inhalt), animated: true)
    }

    private func scannen() {
        let scanner = QRScannerController(titel: L.scanCreds)
        scanner.onScan = { [weak self] inhalt in
            self?.uebernehmen(inhalt)
        }
        present(
            UINavigationController(rootViewController: scanner), animated: true)
    }

    /// Übernimmt einen gelesenen Code.
    ///
    /// Ein Code, der nicht lesbar ist, wird **nicht** stillschweigend
    /// verworfen: Er wird abgelehnt, mit einem Grund. Sonst stünde man nach dem
    /// Scannen vor einer unveränderten Seite und wüsste nicht, ob der Scanner
    /// kaputt ist oder der Code etwas anderes enthält.
    private func uebernehmen(_ inhalt: String) {
        guard let uebernommen = Self.ausText(inhalt) else {
            melde(L.qrNotReadable)
            return
        }
        daten = uebernommen
        // Die eigene URL folgt dem Code: Ist in ihm keine eingetragen, wird der
        // Schalter abgeschaltet. Sonst stünde die Zeile „Eigene URL" da, obwohl
        // kein Wert dafür da ist.
        eigeneUrl = !uebernommen.customUrl.isEmpty
        neuLaden()
    }

    // ------------------------------------------------------------ Das Format

    /// Bringt die vier Werte in die Form, die [QRCodeScreen] zeigt.
    ///
    /// ## Warum hier von Hand gebaut und nicht mit `JSONSerialization`
    ///
    /// Weil die **Reihenfolge der Felder** Teil des Formats ist – die Dart-Seite
    /// liest sie über [Self.ausText] an denselben Namen. `JSONSerialization`
    /// ohne `.sortedKeys` schreibt die Felder in der Reihenfolge, in der die
    /// Struktur sie gerade hat, und die ist in Swift nicht garantiert die
    /// geschriebene.
    static func alsText(
        schoolNumber: String, username: String,
        password: String, customUrl: String
    ) -> String {
        let felder: [(String, String)] = [
            ("schoolnumber", schoolNumber),
            ("username", username),
            ("password", password),
            ("customUrl", customUrl),
        ]
        let inhalt = felder.map { name, wert in
            "\"\(name)\":\"\(maskiert(wert))\""
        }.joined(separator: ",")
        return "{\(inhalt)}"
    }

    /// Liest die vier Werte aus einem gelesenen Code.
    ///
    /// `nil`, wenn es kein Objekt mit diesen Feldern ist – nicht, wenn nur eins
    /// fehlt: Ein halber Code ist kein Code, und ihn **halb** zu übernehmen hieße,
    /// Zugangsdaten zu mischen, von denen keine Seite weiss, woher sie stammen.
    static func ausText(_ text: String) -> AppStore.Credentials? {
        guard let daten = text.data(using: .utf8),
            let eingelesen = try? JSONSerialization.jsonObject(with: daten)
                as? [String: Any]
        else { return nil }

        func feld(_ name: String) -> String? {
            // Nur **Text** wird übernommen. Eine Zahl wäre ein Benutzername mit
            // einer anderen Herkunft, und sie stillschweigend als Text zu
            // übernehmen hieße, einen Wert zu erzeugen, den es so nicht gab.
            guard let wert = eingelesen[name] as? String else { return nil }
            return wert
        }
        guard let schulnummer = feld("schoolnumber"),
            let benutzer = feld("username"),
            let passwort = feld("password"),
            let eigeneUrl = feld("customUrl")
        else { return nil }

        return AppStore.Credentials(
            schoolNumber: schulnummer,
            username: benutzer,
            password: passwort,
            customUrl: eigeneUrl)
    }

    /// Maskiert die Zeichen, die in einem JSON-Text eine Bedeutung haben.
    ///
    /// **Nur** die zwei, um die es hier geht – Anführungszeichen und
    /// Rückwärtsschrägstrich. Das ist keine Gründlichkeit, sondern ihr Gegenteil:
    /// Ein Benutzername mit einem Umlaut soll **lesbar** bleiben, und ein Code,
    /// in dem jedes ä zu `ä` geworden ist, ist weder lesbar noch zuverlässig.
    private static func maskiert(_ wert: String) -> String {
        var ergebnis = ""
        for zeichen in wert {
            switch zeichen {
            case "\"": ergebnis += "\\\""
            case "\\": ergebnis += "\\\\"
            default: ergebnis.append(zeichen)
            }
        }
        return ergebnis
    }
}
