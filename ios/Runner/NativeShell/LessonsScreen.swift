import UIKit

/// Die festen Zeiten der einzelnen Unterrichtsstunden.
///
/// ## Warum hier **nichts** gespeichert werden muss
///
/// In Dart gibt es einen Knopf „Speichern", und beim Zurückgehen die Frage, ob
/// man wirklich nicht speichern will. Das ist die React-Art: Man hält einen
/// Zwischenstand im Bildschirm, und erst beim Gehen steht fest, was davon
/// zählt.
///
/// Hier wird nach **jeder** Änderung gespeichert. Es gibt keinen Zwischenstand,
/// der verloren gehen könnte – und deshalb auch keine Frage beim Zurückgehen.
/// Was man sieht, ist gespeichert.
///
/// ## Warum die Reihenfolge wichtig ist
///
/// Die Zeiten sind durchnummeriert, und der Plan rechnet mit den Nummern, nicht
/// mit den Uhrzeiten. Wird eine Stunde verschoben, ändert sich die Nummer der
/// folgenden – deshalb lässt sich die Liste hier überhaupt erst verschieben.
///
/// Siehe [reihenfolgeMoeglich] in [ListScreen].
final class LessonsScreen: ListScreen {
    /// Die Liste selbst – gehalten, weil `makeSections` sie liest und der
    /// Bildschirm sie zwischen zwei Zeilenbefehlen verändern muss.
    private var stunden: [LessonTime]

    init() {
        // Gelesen **vor** `super.init`, damit der erste Aufbau der Liste schon
        // die gespeicherten Zeilen zeigt. An einer späteren Stelle stünde die
        // Seite einen Frame lang leer – und leer bedeutet hier ausdrücklich
        // „noch nichts angelegt".
        self.stunden = AppStore.lessons
        super.init(title: L.lessonTimes)
    }

    override var reihenfolgeMoeglich: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Das Hinzufügen steht **vor** dem Bearbeiten: Es ist die häufigere
        // Handlung, und in iOS steht links das Hinzufügen und rechts das
        // Bearbeiten.
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .add, target: self,
                action: #selector(hinzufuegen))
        ]
        zeigeBearbeitungsknopf()
    }

    override func makeSections() -> [Section] {
        guard !stunden.isEmpty else {
            // Der leere Zustand ist **eigens** beschriftet. Eine leere Liste ohne
            // Worte sähe aus wie ein Fehler – dabei ist es nur noch nichts
            // angelegt.
            return [
                Section(
                    footer: L.lessonTimesSubtitle,
                    rows: [
                        .text(
                            title: L.noLessonTimes,
                            symbol: "questionmark.circle")
                    ])
            ]
        }

        return [
            Section(footer: L.lessonTimesSubtitle, rows: zeilen())
        ]
    }

    /// Die Zeilen der Liste – eine je Stunde.
    ///
    /// Als eigene Methode und **nicht** als `map` über der Stunde: In der Zeile
    /// selbst steht noch ein Verschluss, und verschachtelt man beides, muss der
    /// Compiler raten, welcher der beiden der letzte ist.
    private func zeilen() -> [Row] {
        var zeilen: [Row] = []
        for stunde in stunden {
            zeilen.append(
                .choice(
                    title: "\(stunde.count). \(L.lessonCount)",
                    subtitle: "\(stunde.start) – \(stunde.end)",
                    symbol: "clock"
                ) { [weak self] in
                    self?.zeitWaehlen(stunde.count - 1)
                })
        }
        return zeilen
    }

    /// Schreibt die Liste und sagt beiden Seiten Bescheid.
    ///
    /// Siehe [AppStore.didWrite]: Ohne den Hinweis bliebe der Plan – Flutter –
    /// bei der alten Liste stehen, ohne dass irgendwo ein Fehler erschiene.
    private func sichern() {
        AppStore.setLessons(stunden)
        AppStore.didWrite()
    }

    // ------------------------------------------------------------- Verändern

    @objc private func hinzufuegen() {
        // Dieselbe Vorgabe wie in Dart: Die neue Stunde fängt **jetzt** an und
        // dauert eine Schulstunde. Ein Zeiger auf 00:00 wäre eine Zeile, die man
        // jedes Mal von Hand korrigieren müsste.
        let jetzt = AppStore.aktuelleZeit
        let kalender = Calendar.current
        let ende = kalender.date(byAdding: .minute, value: 45, to: jetzt) ?? jetzt

        stunden.append(
            LessonTime(
                count: stunden.count + 1,
                start: LessonTime.zeit(
                    kalender.dateComponents([.hour, .minute], from: jetzt)),
                end: LessonTime.zeit(
                    kalender.dateComponents([.hour, .minute], from: ende))
            ))
        neuLaden()
        sichern()
    }

    /// Öffnet das Blatt für **beide** Zeiten einer Stunde.
    ///
    /// Beide zusammen und nicht nacheinander über zwei Dialoge: „Beginn" und
    /// „Ende" gehören zur selben Stunde, und wer sie getrennt einstellt, stellt
    /// sie zweimal an – mit dem Risiko, dass die zweite Angabe nicht mehr passt.
    private func zeitWaehlen(_ index: Int) {
        guard index >= 0, index < stunden.count else { return }
        let stunde = stunden[index]

        let kalender = Calendar.current
        let heute = kalender.startOfDay(for: Date())

        // Aus „08:15" einen **Zeitpunkt** machen. Dafür braucht man einen Tag:
        // Eine Uhrzeit allein ist kein Datum, und `UIDatePicker` merkt sich für
        // `.time` nur, zu welcher Uhrzeit gerade gewählt steht. Deshalb wird der
        // heutige Tag genommen – er wird ohnehin nicht angezeigt.
        var von = heute
        var bis = heute
        let startTeile = LessonTime.components(aus: stunde.start)
        if let wert = kalender.date(
            bySettingHour: startTeile.hour ?? 0,
            minute: startTeile.minute ?? 0,
            second: 0, of: heute)
        {
            von = wert
        }
        let endTeile = LessonTime.components(aus: stunde.end)
        if let wert = kalender.date(
            bySettingHour: endTeile.hour ?? 0,
            minute: endTeile.minute ?? 0,
            second: 0, of: heute)
        {
            bis = wert
        }

        let blatt = DateTimePickerSheet(
            titel: "\(stunde.count). \(L.lessonCount)",
            start: von,
            art: .uhrzeit)
        blatt.onSave = { [weak self] beginn in
            guard let self else { return }
            // Das Ende folgt dem Beginn: Um wie viele Minuten die Stunde dauert,
            // bleibt beim Verschieben des Beginns gleich – so wie es in der
            // Flutter-Seite ist, wo beide Zeiten nacheinander vom selben
            // Ausgangswert aus gewählt werden.
            let dauer = bis.timeIntervalSince(von)
            let ende = beginn.addingTimeInterval(
                dauer.isFinite && dauer > 0 ? dauer : 2700)

            self.stunden[index].start = LessonTime.zeit(
                kalender.dateComponents([.hour, .minute], from: beginn))
            self.stunden[index].end = LessonTime.zeit(
                kalender.dateComponents([.hour, .minute], from: ende))
            self.neuLaden()
            self.sichern()
        }
        present(UINavigationController(rootViewController: blatt), animated: true)
    }

    // ---------------------------------------------------------- Verschieben

    override func zeileVerschoben(von quelle: IndexPath, nach ziel: IndexPath) {
        guard quelle.section == 0, ziel.section == 0 else { return }
        guard quelle.row >= 0, quelle.row < stunden.count else { return }

        let stunde = stunden.remove(at: quelle.row)
        var sicht = ziel.row
        if sicht > quelle.row { sicht -= 1 }
        stunden.insert(stunde, at: min(max(sicht, 0), stunden.count))

        // Die Nummern werden **nicht** neu vergeben – sie sind beim nächsten Lesen
        // ohnehin nur noch die Position. Hier gleich richtig zu machen wäre
        // doppelt gearbeitet.
        //
        // Gespeichert wird sofort, neu gebaut wird erst danach: `reloadData` im
        // Zug der Zeile anzustossen ist eine Änderung an der Liste, mitten in der
        // Bewegung, die gerade läuft. Das Ergebnis ist entweder ein Sprung oder –
        // schlimmer – eine Tabelle, deren Zeilenzahl nicht mehr zu ihrem Inhalt
        // passt.
        sichern()
        DispatchQueue.main.async { [weak self] in
            self?.neuLaden()
        }
    }

    // --------------------------------------------------------------- Löschen

    override func swipeActions(at indexPath: IndexPath)
        -> UISwipeActionsConfiguration?
    {
        guard indexPath.section == 0, indexPath.row < stunden.count else { return nil }
        let nummer = stunden[indexPath.row].count

        let loeschen = UIContextualAction(
            style: .destructive, title: L.delete
        ) { [weak self] _, _, fertig in
            self?.frageObLoeschen(nummer)
            fertig(true)
        }
        loeschen.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [loeschen])
    }

    /// Fragt vor dem Löschen nach – siehe [ListScreen.swipeActions(at:)].
    private func frageObLoeschen(_ nummer: Int) {
        let alarm = UIAlertController(
            title: L.deleteLessonTitle,
            message: L.deleteLessonMessage(nummer),
            preferredStyle: .alert)
        alarm.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        alarm.addAction(
            UIAlertAction(title: L.deleteAction, style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.stunden.removeAll { $0.count == nummer }
                self.neuLaden()
                self.sichern()
                self.melde(L.lessonDeleted(nummer))
            })
        present(alarm, animated: true)
    }
}