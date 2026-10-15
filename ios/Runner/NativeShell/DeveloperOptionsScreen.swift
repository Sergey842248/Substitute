import UIKit
import CryptoKit

/// Die Entwickleroptionen.
///
/// ## Warum die Texte hier **deutsch** sind
///
/// In Dart ist dieser Bildschirm englisch geblieben – vermutlich, weil er nie
/// übersetzt wurde und nie musste. Auf der nativen Seite gäbe es dafür keinen
/// Grund, und eine Seite, die auf Deutsch übersetzt ist und beim Umschalten in
/// Englisch mit englischen Zeilen dasteht, sähe kaputt aus.
///
/// Die festen Zeilen sind deshalb über [L] übersetzt.
///
/// ## Warum die gefährlichen Zeilen **rot** sind
///
/// Sie nehmen etwas **weg**, und zwar ohne Umweg: kein Rückgängig, kein Dialog
/// mit einer Sicherung. Das ist eine Warnung – und die gehört in die Farbe, nicht
/// in einen kleinen Text, den man übersieht.
///
/// ## Warum nichts davon „geht zurück“
///
/// Keine dieser Aktionen lässt sich auf diesem Bildschirm zurücknehmen. Es sind
/// Werkzeuge für einen Fall, in dem man weiss, was man tut.
///
/// ## Warum die Zeit **ein** Blatt ist
///
/// Datum und Uhrzeit stehen in Flutter in zwei Fenstern hintereinander. Für
/// „zeige mir einen Dienstag um 14 Uhr" ist das eine Kette aus drei Schritten,
/// bei der man nach dem zweiten schon vergessen hat, was im ersten stand.
///
/// Deshalb steht beides in einem Blatt ([DateTimePickerSheet]). Die Stundenzeiten
/// im Werkzeugkasten brauchen nur die Uhrzeit, die Entwickleroptionen beides –
/// beides entscheidet [DateTimePickerSheet.Art].
final class DeveloperOptionsScreen: ListScreen {
    init() {
        super.init(title: L.developerOptions)
    }

    override func makeSections() -> [Section] {
        var abschnitte: [Section] = [datumAbschnitt(), anzeigeAbschnitt()]
        abschnitte.append(contentsOf: datenAbschnitte())
        return abschnitte
    }

    // ------------------------------------------------------- Datum & Uhrzeit

    private func datumAbschnitt() -> Section {
        var zeilen: [Row] = []

        if let datum = AppStore.overriddenNow {
            // Der Wert steht **in** der Zeile, nicht daneben: Es ist derselbe
            // Eintrag, ihn zu ändern.
            zeilen.append(
                .choice(
                    title: L.customDate,
                    subtitle: Self.format(datum),
                    symbol: "calendar.badge.clock"
                ) { [weak self] in self?.datumWaehlen() })

            zeilen.append(
                .destructive(
                    title: L.clearOverride,
                    subtitle: L.clearOverrideSubtitle,
                    symbol: "arrow.uturn.backward"
                ) { [weak self] in self?.ueberschreibungEntfernen() })
        } else {
            zeilen.append(
                .choice(
                    title: L.customDate,
                    subtitle: L.noOverride,
                    symbol: "calendar.badge.clock"
                ) { [weak self] in self?.datumWaehlen() })
        }

        // Ohne Überschrift: Sie stünde dort als „Datum & Uhrzeit" über einer
        // Zeile, die genau so heisst – und der grosse Titel des Bildschirms sagt
        // es bereits.
        return Section(rows: zeilen)
    }

    private func datumWaehlen() {
        let blatt = DateTimePickerSheet(
            titel: L.customDate,
            start: AppStore.overriddenNow ?? AppStore.aktuelleZeit,
            art: .datumUndUhrzeit)
        blatt.onSave = { [weak self] datum in
            AppStore.setOverriddenNow(datum)
            self?.neuLaden(animiert: true)
            AppStore.didWrite()
        }
        present(UINavigationController(rootViewController: blatt), animated: true)
    }

    private func ueberschreibungEntfernen() {
        AppStore.setOverriddenNow(nil)
        neuLaden(animiert: true)
        AppStore.didWrite()
    }

    /// Wie ein Datum mit Uhrzeit geschrieben wird.
    ///
    /// Über [DateFormatter] mit **beiden** Kurzformen: Ein reines Datumsformat
    /// wäre hier unbrauchbar, denn die ganze Wirkung liegt gerade darin, dass man
    /// eine **Uhrzeit** vortäuschen kann.
    ///
    /// Und bewusst `.current` als Sprache: Das ist etwas, das man **liest** und
    /// nicht weiterreicht – im Gegensatz zu den Stundenzeiten, die als Text in
    /// den Speicher gehen und dort in jeder Sprache gleich aussehen müssen.
    private static func format(_ datum: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: datum)
    }

    // -------------------------------------------------------------- Anzeige

    private func anzeigeAbschnitt() -> Section {
        Section(
            rows: [
                .toggle(
                    title: L.showSyncDetails,
                    subtitle: L.showSyncDetailsSubtitle,
                    symbol: "arrow.triangle.2.circlepath",
                    value: AppStore.showsSyncDetails
                ) { [weak self] neu in
                    AppStore.setShowsSyncDetails(neu)
                    self?.speichern(L.showSyncDetails)
                }
            ])
    }

    // ----------------------------------------------------------------- Daten

    private func datenAbschnitte() -> [Section] {
        [
            Section(
                header: L.developerData,
                footer: L.developerDataSubtitle,
                rows: [
                    .destructive(
                        title: L.deleteOfflinePlans, symbol: "trash"
                    ) { [weak self] in self?.loescheOfflinePlaene() },

                    .destructive(
                        title: L.clearAllSettings, symbol: "eraser"
                    ) { [weak self] in self?.frageObAllesLoeschen() },

                    .destructive(
                        title: L.removeTeacherShorts, symbol: "person.text.rectangle"
                    ) { [weak self] in
                        AppStore.removeTeacherShorts()
                        self?.speichern(L.teacherShortsRemoved)
                    },

                    .destructive(
                        title: L.clearNewsFeeds, symbol: "newspaper"
                    ) { [weak self] in
                        AppStore.clearNewsFeeds()
                        self?.speichern(L.newsFeedsCleared)
                    },

                    .destructive(
                        title: L.deleteLessonTimes, symbol: "clock.badge.xmark"
                    ) { [weak self] in
                        AppStore.setLessons([])
                        self?.speichern(L.lessonTimesDeleted)
                    },

                    .destructive(
                        title: "Delete Shares",
                        subtitle: "Remove any user’s shares or a sync chain",
                        symbol: "person.crop.circle.badge.minus"
                    ) { [weak self] in self?.deleteSharesMenu() },
                ]),

            Section(
                header: L.developerFlags,
                rows: [
                    .choice(
                        title: L.materialYou,
                        subtitle: L.materialYouSubtitle(AppStore.materialYouEnabled),
                        symbol: "paintpalette",
                        accessory: AppStore.materialYouEnabled
                            ? .checkmark : .none
                    ) { [weak self] in
                        AppStore.setMaterialYouEnabled(!AppStore.materialYouEnabled)
                        self?.speichern(L.materialYou)
                    },

                    .choice(
                        title: L.markFirstTime, symbol: "sparkles"
                    ) { [weak self] in
                        AppStore.markFirstTimeSeen()
                        self?.speichern(L.firstTimeSet)
                    },
                ]),
        ]
    }

    // ------------------------------------------------------------- Handgriffe

    private func loescheOfflinePlaene() {
        AppStore.removeOfflinePlans()
        speichern(L.offlinePlansDeleted)
    }

    // --------------------------------------------------------- Delete Shares

    /// Die iOS-Einstellungen sind nativ. Deshalb lebt dieses Werkzeug auch
    /// hier, statt nur in der Flutter-Version der Entwickleroptionen zu
    /// existieren. Ein Nutzername ist auf dem Server Klartext-Metadatum; eine
    /// Sync-Kette wird dagegen aus ihrem Code abgeleitet, genau wie in
    /// `SyncEngine.chainIdFor`.
    private func deleteSharesMenu() {
        let menu = UIAlertController(
            title: "Delete Shares",
            message: "This can remove data belonging to other users.",
            preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "Delete user shares", style: .destructive) {
            [weak self] _ in self?.askToDeleteUserShares()
        })
        menu.addAction(UIAlertAction(title: "Delete sync chain", style: .destructive) {
            [weak self] _ in self?.askToDeleteSyncChain()
        })
        menu.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        if let popover = menu.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY,
                                        width: 1, height: 1)
        }
        present(menu, animated: true)
    }

    private func askToDeleteUserShares() {
        askForPhrase(
            title: "Delete user shares",
            message: "Enter the user name (ten words). All of that user’s shares will be removed.") {
                [weak self] username in self?.deleteUserShares(username)
            }
    }

    private func askToDeleteSyncChain() {
        askForPhrase(
            title: "Delete sync chain",
            message: "Enter the sync code (ten words). Every device snapshot in the chain will be removed.") {
                [weak self] code in self?.deleteSyncChain(code)
            }
    }

    private func askForPhrase(
        title: String, message: String, completion: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.placeholder = "ten words"
        }
        alert.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            let phrase = alert.textFields?.first?.text ?? ""
            guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            completion(phrase)
        })
        present(alert, animated: true)
    }

    private var syncServerURL: URL? {
        let raw = AppStore.plainString("sync.serverUrl")
        return URL(string: raw?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? raw! : "https://socgdoyooyiupnmzuaox.supabase.co")
    }

    private func deleteUserShares(_ username: String) {
        guard let base = syncServerURL,
              var components = URLComponents(
                url: base.appendingPathComponent(
                    isSupabase(base) ? "functions/v1/shares" : "v1/shares/owner/\(username)"),
                resolvingAgainstBaseURL: false)
        else { return }
        if isSupabase(base) {
            components.queryItems = [URLQueryItem(
                name: "owner_username",
                value: username.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        deleteFromServer(components.url, success: "User shares deleted.")
    }

    private func deleteSyncChain(_ code: String) {
        guard let base = syncServerURL,
              var components = URLComponents(
                url: base.appendingPathComponent(
                    isSupabase(base) ? "functions/v1/chain-snapshots" : "v1/chain"),
                resolvingAgainstBaseURL: false)
        else { return }
        let normalized = code.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).sorted().joined(separator: " ")
        let source = "substitute/sync-chain/v1\n\(normalized)"
        let chainId = Data(SHA256.hash(data: Data(source.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        if isSupabase(base) {
            components.queryItems = [URLQueryItem(name: "chain_id", value: chainId)]
        } else {
            components.path += "/\(chainId)"
        }
        deleteFromServer(components.url, success: "Sync chain deleted.")
    }

    private func deleteFromServer(_ url: URL?, success: String) {
        guard let url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if isSupabase(url) {
            request.setValue("sb_publishable_MQtaHWk6WqUlCYr9rHuabA_u26D9N8M", forHTTPHeaderField: "apikey")
        }
        Task { [weak self] in
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                await MainActor.run { self?.melde(success) }
            } catch {
                await MainActor.run { self?.melde("Could not delete data from the server.") }
            }
        }
    }

    private func isSupabase(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "supabase.co" || host.hasSuffix(".supabase.co")
    }

    /// Fragt nach, bevor **alles** gelöscht wird.
    ///
    /// Dies ist die einzige Stelle hier, die eine Rückfrage bekommt – und genau
    /// darum: Sie nimmt nicht nur eine Liste weg, sondern **alle** gespeicherten
    /// Werte der App. Wer das einmal ohne nachzudenken bestätigt, hat
    /// Schulbereiche, Zugangsdaten und Stundenzeiten verloren und bekommt sie
    /// nicht zurück.
    private func frageObAllesLoeschen() {
        let alarm = UIAlertController(
            title: L.clearAllSettingsTitle,
            message: L.clearAllSettingsMessage,
            preferredStyle: .alert)
        alarm.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        alarm.addAction(
            UIAlertAction(title: L.clear, style: .destructive) { [weak self] _ in
                AppStore.removeAll()
                self?.neuLaden(animiert: true)
                AppStore.didWrite()
                // Auch der aktive Schulbereich ist dabei weggegangen. Die Leiste
                // muss das erfahren, sonst zeigte sie weiter einen Bereich, für
                // den es keine Werte mehr gibt.
                NotificationCenter.default.post(
                    name: AppStore.activeSchoolDidChange, object: nil)
                self?.melde(L.allSettingsCleared)
            })
        present(alarm, animated: true)
    }

    /// Nach jedem Schreiben: Liste neu aufbauen und beiden Seiten Bescheid sagen.
    private func speichern(_ hinweis: String) {
        neuLaden(animiert: true)
        AppStore.didWrite()
        melde(hinweis)
    }
}
