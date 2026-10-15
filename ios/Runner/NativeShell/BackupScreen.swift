import UIKit
import UniformTypeIdentifiers

/// Sichern & Wiederherstellen – die Konfiguration als Datei hin und her.
///
/// ## Was auf diesem Bildschirm passiert
///
/// Zwei Zeilen und ein Fußtext, mehr nicht. Beide Zeilen tun dasselbe wie vorher
/// in Flutter, aber jetzt ohne Umweg: Die Datei wird von
/// [UIDocumentPickerViewController] gewählt und von [UIActivityViewController]
/// geteilt – beides gehört zu iOS.
///
/// Die eigentliche Rechenarbeit steht in [ConfigBackupStore], nicht hier. Das ist
/// Absicht: Das Format der Datei muss auf beiden Plattformen gleich sein, und ein
/// Bildschirm, in dem es an **zwei** Stellen stünde, könnte es an einer ändern,
/// ohne dass die andere es merkt.
///
/// ## Der Dialog vor dem Teilen
///
/// Vor dem Export wird gefragt, ob die Zugangsdaten mit in die Datei sollen. Das
/// ist keine Vorsicht aus Höflichkeit: Die Datei enthält das Passwort im
/// **Klartext**, und sie geht genau dorthin, wohin der Nutzer sie schickt.
///
/// ## Warum hier nichts über den Schulbereich steht
///
/// Gesichert wird die ganze App – alle Schulbereiche, nicht nur der aktive. Wer
/// drei Schulen angelegt hat und das Gerät weiteribt, nimmt sonst die Daten der
/// beiden anderen Schulen nicht mit, ohne es zu merken.
final class BackupScreen: ListScreen {
    init() {
        super.init(title: L.backup)
    }

    override func makeSections() -> [Section] {
        [
            Section(
                footer: L.backupNote,
                rows: [
                    .choice(
                        title: L.backupExport,
                        subtitle: L.backupExportSubtitle,
                        symbol: "square.and.arrow.up"
                    ) { [weak self] in self?.export() },

                    .choice(
                        title: L.backupImport,
                        subtitle: L.backupImportSubtitle,
                        symbol: "square.and.arrow.down"
                    ) { [weak self] in self?.waehleDatei() },
                ]),
        ]
    }

    // --------------------------------------------------------------- Export

    private func export() {
        // Die **vollständige** Datei wird zuerst gebaut – und aus ihr liest sich
        // ab, ob es überhaupt Zugangsdaten im Spiel sind. Aus einer Datei **ohne**
        // Zugangsdaten liest sich das nie ab: Die Frage würde also immer mit
        // „nein" beantwortet, und niemand bekäme die Wahl, die er sonst bekäme.
        let vollstaendig = ConfigBackupStore.baueExport(mitZugangsdaten: true)
        let settings = vollstaendig["settings"] as? [String: Any] ?? [:]

        // Ohne hinterlegte Zugangsdaten gibt es nichts zu fragen – dann geht
        // genau die Datei raus, die gerade gebaut wurde.
        guard ConfigBackupStore.enthaeltZugangsdaten(settings) else {
            teile(vollstaendig)
            return
        }

        let alarm = UIAlertController(
            title: L.backupCredentialsTitle,
            message: L.backupCredentialsWarning,
            preferredStyle: .alert)
        alarm.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        // Wer ohne Zugangsdaten teilt, bekommt die Datei **neu** gebaut: Aus der
        // vollständigen lassen sie sich nicht einfach streichen – es sind drei
        // Schlüssel, und sie könnten in einem fremden Schulbereich liegen.
        alarm.addAction(
            UIAlertAction(title: L.backupShareWithoutCredentials, style: .default)
            { [weak self] _ in
                self?.teile(ConfigBackupStore.baueExport(mitZugangsdaten: false))
            })
        // Der Knopf, der das Passwort preisgibt, steht rechts und ist der
        // Vorgabe-Text: Wer beim Wegtippen nicht hinsieht, drückt ihn am ehesten.
        alarm.addAction(
            UIAlertAction(title: L.backupCredentialsContinue, style: .default)
            { [weak self] _ in
                self?.teile(vollstaendig)
            })
        present(alarm, animated: true)
    }

    /// Schreibt die Datei und öffnet das Teilen-Menü des Systems.
    ///
    /// ## Warum der Warntext **nicht** mit in die Datei und nicht daneben kommt
    ///
    /// In Flutter ging der Warntext über `share_plus` als Begleittext mit auf die
    /// Postkarte. Swift kennt dafür keinen Weg, der nicht über nicht
    /// dokumentierte Schnittstellen läuft – und der Dialog oben sagt dasselbe,
    /// bevor es passiert. Wer die Datei weiteribt, hat die Warnung also gelesen.
    private func teile(_ export: [String: Any]) {
        guard let text = ConfigBackupStore.kodiere(
            export,
            exportiertAm: Date(),
            appVersion: ConfigBackupStore.appVersion),
            let daten = text.data(using: .utf8)
        else {
            melde(L.backupFailed)
            return
        }

        // In das temporäre Verzeichnis: Dort darf die App ohne Rückfrage schreiben,
        // und iOS räumt es von selbst weg. In `Documents` müsste man selbst
        // aufräumen, und eine Datei, die dort liegen bleibt, taucht später in
        // „Dateien" der anderen Apps auf.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(ConfigBackupStore.dateiName())
        do {
            try daten.write(to: url, options: .atomic)
        } catch {
            melde(L.backupFailed)
            return
        }

        let menge = UIActivityViewController(
            activityItems: [url], applicationActivities: nil)
        // Auf dem iPad braucht das Menü einen Anker, sonst stürzt es ab.
        menge.popoverPresentationController?.sourceView = view
        menge.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(menge, animated: true)
    }

    // --------------------------------------------------------------- Import

    private func waehleDatei() {
        // `.json` und `.text`, und sonst nichts: Eine Datei, die diese App nicht
        // geschrieben hat, wird ohnehin abgelehnt – sie erst durch den Nutzer
        // durch den Dateiwähler zu schicken wäre eine Enttäuschung mit Umweg.
        let waehler = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.json, UTType.plainText],
            asCopy: true)
        waehler.delegate = self
        waehler.allowsMultipleSelection = false
        present(waehler, animated: true)
    }

    private func verarbeite(_ url: URL) {
        // `asCopy: true` hat die Datei bereits in den Bereich der App gelegt –
        // dafür braucht es keine besondere Sicherheitsfreigabe, und ohne sie wäre
        // `startAccessingSecurityScopedResource` von einem Aufrufer abhängig, den
        // es hier gar nicht gibt.
        guard let daten = try? Data(contentsOf: url),
            let text = String(data: daten, encoding: .utf8)
        else {
            melde(L.backupImportFailed)
            return
        }

        let settings: [String: Any]
        do {
            settings = try ConfigBackupStore.lieseExport(text)
        } catch {
            melde(lesetextFuer(error))
            return
        }

        frageNachErsetzen(settings)
    }

    /// Der Satz zu einem abgelehnten Datei-Inhalt.
    ///
    /// Drei Fehler, drei Sätze – siehe [ConfigBackupStore.LeseFehler].
    private func lesetextFuer(_ fehler: Error) -> String {
        guard let fehler = fehler as? ConfigBackupStore.LeseFehler else {
            return L.backupImportFailed
        }
        switch fehler {
        case .fremdeApp: return L.backupErrorForeign
        case .neuereVersion: return L.backupErrorFutureSchema
        case .ungueltigesJson, .ungueltigeEinstellungen: return L.backupImportFailed
        }
    }

    private func frageNachErsetzen(_ settings: [String: Any]) {
        // Der Hinweis über die Zugangsdaten steht **nur** dann dabei, wenn die
        // Datei keine bringt. Bei einer Datei **mit** Zugangsdaten wäre er
        // falsch: Dort werden sie durch „Ersetzen" sehr wohl mit ersetzt, und der
        // Satz behauptete das Gegenteil.
        let text =
            ConfigBackupStore.enthaeltZugangsdaten(settings)
            ? L.backupImportQuestion
            : L.backupImportQuestion + "\n\n" + L.backupImportKeepsCredentials

        let alarm = UIAlertController(
            title: L.backupImportTitle, message: text, preferredStyle: .alert)
        alarm.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        alarm.addAction(
            UIAlertAction(title: L.backupImportMerge, style: .default) { [weak self] _ in
                self?.uebernehmen(settings, ersetzen: false)
            })
        alarm.addAction(
            UIAlertAction(title: L.backupImportReplace, style: .default) { [weak self] _ in
                self?.uebernehmen(settings, ersetzen: true)
            })
        present(alarm, animated: true)
    }

    private func uebernehmen(_ settings: [String: Any], ersetzen: Bool) {
        let ergebnis = ConfigBackupStore.wendeImportAn(settings, ersetzen: ersetzen)

        // Siehe [AppStore.didWrite]: Dart liest aus dem **Cache** von
        // `SharedPreferences`, und der kennt nur, was Dart selbst geschrieben hat.
        // Ohne diesen einen Aufruf stünden im Plan die alten Werte, ohne dass
        // irgendwo ein Fehler erschiene.
        AppStore.didWrite()

        melde(L.backupImportDone(ergebnis.uebernommen, ergebnis.entfernt))
    }
}

// MARK: - Die Datei

extension BackupScreen: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else { return }
        // Der Dateiwähler ist zu diesem Zeitpunkt **noch** offen: Er schließt sich
        // selbst, nachdem er zurückgerufen hat. Ein Dialog, der in diesem Moment
        // über ihm aufpoppt, fiele deshalb auf die Nase. Ein Schritt im
        // Hauptthread später ist der erste, bei dem er garantiert zu ist.
        DispatchQueue.main.async { [weak self] in self?.verarbeite(url) }
    }
}
