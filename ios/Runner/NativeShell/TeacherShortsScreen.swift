import UIKit

/// Lehrerkürzel – aus „MUE" wird „Herr Müller".
///
/// ## Was hier passiert
///
/// Über dem Feld steht das Kürzel aus dem Plan, darunter der Name, den man
/// einträgt. Das ist alles. Der Plan wird nicht noch einmal gezeigt und nicht
/// erklärt – die Fragen, die es in Flutter gab („wirklich zurücksetzen?"), waren
/// Antworten auf Fragen, die iOS gar nicht erst stellt.
///
/// ## Warum die Liste sofort dasteht und nicht erst geladen wird
///
/// In Flutter stand hier eine Sekunde lang eine Ladeanzeige, während die ganze
/// Dart-Umgebung hochfuhr. Hier kommt die Liste aus [TeacherShortsStore] in
/// unter einer Frame-Zeit – und wenn sie leer ist, weil auf diesem Gerät noch nie
/// ein Plan geöffnet wurde, wird **einmal** geholt, mit einer Zeile darüber, die
/// sagt, dass es dauert.
///
/// ## Warum beim Tippen **nicht** gemeldet wird
///
/// Der Wert geht bei jedem Tastendruck in den Speicher, die Meldung an die andere
/// Seite aber erst, wenn der Bildschirm verlassen wird. Der Grund ist nicht
/// Sparsamkeit: [AppStore.didWrite] baut unter anderem jede native Liste neu auf –
/// und eine Liste, die sich mitten im Tippen neu aufbaut, wirft den Cursor aus dem
/// Feld, in das man gerade schreibt.
///
/// Was im Speicher steht, geht dabei **nicht** verloren: Er wird beim nächsten
/// Öffnen der App neu gelesen, und bis dahin stimmt der Wert.
final class TeacherShortsScreen: FormScreen {
    /// Der Stand des Bildschirms – **nicht** [FormScreen.liste].
    ///
    /// Zwei Listen auf einem Bildschirm brauchen zwei Namen: `liste` ist die
    /// sichtbare, `eintraege` die der Lehrenden. Ein zweiter Schatten mit
    /// demselben Namen wäre der Anfang davon, dass an der falschen Stelle etwas
    /// neu gebaut wird.
    private var eintraege: [Lehrerkuerzel] = []

    /// Läuft gerade ein Abruf?
    private var laedt = false

    /// Der letzte Fehler – er bleibt stehen, bis der nächste Versuch beginnt.
    private var fehler: String?

    private var ziehgeste: UIRefreshControl?

    init() {
        super.init(title: L.teacherShorts)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ziehen zum Aktualisieren – dieselbe Geste wie in der Plan-Liste. Ohne
        // sie gäbe es keinen Weg, eine Liste zu erzwingen, die jemand anderes im
        // Vertretungsplan geändert hat.
        let ziehen = UIRefreshControl()
        ziehen.addTarget(self, action: #selector(aktualisieren), for: .valueChanged)
        liste.refreshControl = ziehen
        ziehgeste = ziehen

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh, target: self,
            action: #selector(aktualisieren))

        ausSpeicherLaden()
        ausPlaenenLaden()
        neuLaden()

        // Nur, wenn gar nichts da ist: Sonst wäre der Abruf bei jedem Öffnen ein
        // zweiter Weg, den niemand gebraucht hat – und eine Sekunde Warten, die es
        // vorher nicht gab.
        if eintraege.isEmpty { aktualisieren() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Jetzt – und nicht beim Tippen – wird der anderen Seite gesagt, dass sich
        // etwas geändert hat. Siehe die Beschreibung der Klasse.
        schreibeUndMelde()
    }

    // --------------------------------------------------------------- Aufbau

    override func makeSections() -> [FormSection] {
        if eintraege.isEmpty {
            return [
                FormSection(
                    footer: leererZustand(),
                    rows: [
                        .text(
                            titel: laedt
                                ? L.teacherShortsLoading
                                : L.teacherShortsNone,
                            untertitel: nil,
                            symbol: laedt
                                ? "arrow.triangle.2.circlepath" : "person.2"
                        )
                    ])
            ]
        }

        var abschnitte: [FormSection] = [
            FormSection(
                footer: L.teacherShortsFooter,
                rows: eintraege.enumerated().map { nummer, eintrag in
                    // Das Kürzel ist die **Überschrift** des Feldes und nicht sein
                    // Inhalt: Man trägt einen Namen ein, und das Kürzel steht
                    // darüber. Eine Zeile „MUE  [Feld]" wäre eine breite Zeile mit
                    // einer Trennung, die es in iOS nicht gibt.
                    //
                    // `symbol: ""` heisst: **kein** Symbol. Vor fünfzig Zeilen wäre
                    // ein Personensymbol in jeder davon eine Lärmkulisse, und das
                    // Feld rückte um seinen Platz nach rechts – siehe
                    // [FeldCell.setzeAussehen].
                    .feld(
                        titel: eintrag.kuerzel,
                        platzhalter: L.realName,
                        symbol: "",
                        text: eintrag.echterName,
                        sicher: false,
                        // `.name`: Gross/Klein und Umschauten sind bei Namen die
                        // Regel, und die Tastatur soll sie von sich aus anbieten.
                        tastatur: .name
                    ) {[weak self] neu in self?.geaendert(nummer, neu) }
                })
        ]

        // Nur **eigens** dafür: Eine Zeile, die sich während des Tippens ändert,
        // wäre ein Sprung in einer Liste, in der man gerade tippt.
        if laedt || fehler != nil {
            abschnitte.append(
                FormSection(rows: [
                    .text(
                        titel: laedt
                            ? L.teacherShortsLoading
                            : (fehler ?? ""),
                        untertitel: nil,
                        symbol: laedt
                            ? "arrow.triangle.2.circlepath"
                            : "exclamationmark.triangle"
                    )
                ]))
        }

        return abschnitte
    }

    /// Der Satz unter einer leeren Liste.
    private func leererZustand() -> String {
        if let fehler { return fehler }
        return L.teacherShortsNoneFooter
    }

    // -------------------------------------------------------------- Die Daten

    private func ausSpeicherLaden() {
        eintraege = TeacherShortsStore.gespeichert()
    }

    /// Ergänzt aus den lokal gespeicherten Plänen – ohne Netz und ohne Warten.
    private func ausPlaenenLaden() {
        let gefunden = TeacherShortsStore.ausGespeichertenPlaenen()
        guard !gefunden.isEmpty else { return }
        // Der Speicher gewinnt: Hier geht es nur darum, **fehlende** Kürzel zu
        // ergänzen. Einen eingetragenen Namen zu überschreiben wäre genau das
        // Gegenteil von dem, was dieser Bildschirm tut – siehe
        // [TeacherShortsStore.ergaenzen].
        eintraege = TeacherShortsStore.ergaenzen(gefunden)
    }

    /// Ein Name wurde getippt.
    private func geaendert(_ nummer: Int, _ neu: String) {
        guard eintraege.indices.contains(nummer) else { return }
        eintraege[nummer].echterName = neu
        schreibeUndMelde(melden: false)
    }

    /// Schreibt die Liste – und sagt der anderen Seite Bescheid, wenn es soll.
    private func schreibeUndMelde(melden: Bool = true) {
        // Unverändert? Dann gibt es nichts zu schreiben und nichts zu melden.
        // Jedes `didWrite` baut alle nativen Listen neu auf, und ein Bildschirm,
        // der sich selbst neu aufbaut, während man auf ihm tippt, wäre der
        // Gegenstand des nächsten Fehlers.
        if TeacherShortsStore.gespeichert() == eintraege { return }
        TeacherShortsStore.speichern(eintraege)
        if melden { AppStore.didWrite() }
    }

    // -------------------------------------------------------------- Das Netz

    @objc private func aktualisieren() {
        // `Ziehen zum Aktualisieren` darf sich selbst nicht doppelt auslösen, und
        // der Knopf rechts auch nicht – deshalb die eine Prüfung für beides.
        guard !laedt else { return }
        laedt = true
        fehler = nil
        neuLaden()
        ziehgeste?.beginRefreshing()

        Task { [weak self] in
            guard let self else { return }
            do {
                let gefunden = try await TeacherShortsStore.holeAusNetz()
                self.eintraege = TeacherShortsStore.ergaenzen(gefunden)
                // Hier wird **jedes** Mal gemeldet, auch wenn nichts hinzukam: Im
                // Plan könnte ein Kürzel umbenannt worden sein, und das sieht nur
                // jemand, der die Flutter-Seite danach fragt.
                AppStore.didWrite()
            } catch {
                self.fehler = Self.textFuer(error)
            }
            self.laedt = false
            self.ziehgeste?.endRefreshing()
            self.neuLaden()
        }
    }

    /// Der Satz zu einem fehlgeschlagenen Abruf.
    ///
    /// Jeder Fehler bekommt seinen **eigenen** Satz: „Keine Zugangsdaten" und
    /// „Kein Netz" führen zu völlig verschiedenen nächsten Schritten, und ein
    /// gemeinsamer Satz – wie in Flutter – lässt offen, was nun zu tun ist.
    private static func textFuer(_ fehler: Error) -> String {
        guard let fehler = fehler as? TeacherShortsStore.NetzFehler else {
            return L.teacherShortsFailed
        }
        switch fehler {
        case .keineZugangsdaten: return L.teacherShortsNoCredentials
        case .nichtAngemeldet: return L.teacherShortsNotLoggedIn
        case .schulnummerFalsch: return L.teacherShortsWrongSchool
        case .verbindung: return L.teacherShortsOffline
        case .serverFehler(let code): return L.teacherShortsServer(code)
        }
    }
}

// MARK: - Der Vergleich

extension Lehrerkuerzel: Equatable {
    /// Zwei Zeilen sind gleich, wenn Kürzel **und** Name gleich sind.
    ///
    /// Bewusst von Hand und nicht abgeleitet: `==` auf einer Liste von Werten
    /// vergleicht sonst jedes Glied einzeln, und es wäre trotzdem richtig. Der
    /// eigene Aufbau steht hier, damit es auch dann stimmt, wenn später ein Feld
    /// dazukommt – und nicht erst dann, wenn jemand es hinzufügt.
    static func == (a: Lehrerkuerzel, b: Lehrerkuerzel) -> Bool {
        a.kuerzel == b.kuerzel && a.echterName == b.echterName
    }
}
