import UIKit

/// Der Vertretungsplan in der Übersicht – die Klassen und die Personen.
///
/// ## Was hier steht und woher es kommt
///
/// Der **Inhalt** kommt aus Flutter: `VPlan` liest die Klassen aus dem Speicher,
/// die Personen aus dem Speicher, die Vorschau aus dem VPlan-XML. Das ist die
/// ganze Arbeit, und sie liegt in Dart.
///
/// Was hier steht, ist die **Darstellung**: eine Liste in Gruppen, mit grossem
/// Titel, mit Wischen zum Löschen und mit einem Pfeil, der sagt „hier geht es
/// weiter". Dieselben Bausteine wie in den Einstellungen – siehe `ListScreen`.
///
/// ## Warum das ein Bildschirm in der Reihe ist und nicht der Inhalt des Reiters
///
/// Der Reiter „Plan" **ist** dieser Bildschirm. Wer eine Klasse antippt, kommt in
/// den Plan dieser Klasse – und der ist weiterhin Flutter, weil dort das
/// Wochenraster steht, für das es keinen vernünftigen Ersatz in einer Tabelle
/// gibt.
///
/// Diese Trennung ist der Grund, warum es hier keine halben Bildschirme gibt:
/// Entweder eine Zeile ist eine Zeile und der Rest ist eine ganze Seite, oder
/// man hätte beides ineinander.
///
/// ## Warum die Vorschau hier nicht steht
///
/// In `VPlan` hängt unter jeder Zeile eine Karte mit der nächsten Stunde. Die
/// ist zweispaltig gebaut und hat ihre eigene Farbe und ihre eigene Rundung –
/// sie gehört zu einem Bildschirm, der nicht mehr in einer Liste steht.
///
/// Sie bleibt deshalb in Flutter und wird **nicht** hierher übertragen. Eine
/// Tabelle, die eine fremde Karte nachbauen müsste, wäre schöner voll als das
/// Original: Man erkennt sie sofort, und man traut ihr nicht mehr.
final class PlanOverviewScreen: ListScreen {

    init() {
        // Nicht `L.vplanStudents` ("Vertretungsplan Schüler"): Das ist der Name
        // des **Reiters**, und im Reiter steht kein Wort. Als grosser Titel wäre
        // es eine Selbstaussage über den Bildschirm – "Schüler" steht hier nirgends.
        super.init(title: L.plan, largeTitle: true)
        navigationItem.rightBarButtonItem = AppInfoBarButton.make(
            target: self, action: #selector(appInfoGetippt))
        navigationItem.leftBarButtonItem = LogoBarButton.make(
            target: self, action: #selector(heimGetippt))
    }

    /// Der Bildschirm, dessen Werte hier gezeichnet werden.
    ///
    /// Gesetzt über die Vorgabe und nicht über einen eigenen Aufbau, damit die
    /// Zeile neben [makeSections] steht – also dort, wo jemand nachschaut, wenn
    /// er wissen will, woher die Zeilen kommen.
    override var datenQuelle: ScreenBridge.Screen? { .plan }

    // -------------------------------------------------------------- Inhalt

    override func makeSections() -> [Section] {
        let daten = ScreenBridge.stand(.plan) ?? [:]

        var abschnitte: [Section] = []

        // Die Personen kommen **vor** den Klassen.
        //
        // Nicht, weil sie wichtiger wären, sondern weil sie die kleinere Gruppe
        // sind: Wer eine Person angelegt hat, will fast immer deren Plan sehen,
        // und sie steht dann ohne Suchen oben.
        //
        // Das ist dieselbe Reihenfolge wie in `VPlan._personsSection` – und sie
        // ist Absicht, keine Zufallsfolge.
        if !daten.versteckePersonen {
            let personen = daten.personen
            if !personen.isEmpty {
                abschnitte.append(
                    Section(header: L.persons, footer: nil, rows: personen.map(zeile)))
            }
        }

        let klassen = daten.klassen
        if !klassen.isEmpty {
            abschnitte.append(
                Section(header: L.classes, footer: nil, rows: klassen.map(zeile)))
        }

        // Ist noch nichts da, steht ein **Grund** da – nicht „leer".
        //
        // Eine leere Liste ohne Erklärung sieht aus wie ein Fehler: Man hat
        // Klassen erwartet, weil die Einrichtung sie verlangt. Der Text sagt
        // deshalb, was zu tun ist, statt nur zu melden, dass nichts da ist.
        if abschnitte.isEmpty {
            abschnitte.append(
                Section(header: nil, footer: nil, rows: [
                    .text(
                        title: L.noClassesYetSubtitle, subtitle: nil, symbol: "calendar.badge.plus")
                ]))
        }

        // Das Hinzufügen steht als **letzte** Zeile einer eigenen Gruppe und
        // nicht als Zeile mit den Klassen: Es ist kein weiterer Eintrag, sondern
        // der Weg, einen anzulegen. In iOS steht es unter der Liste, wo der Daumen
        // ihn erwartet – oben würde man ihn für einen Eintrag halten.
        abschnitte.append(
            Section(header: nil, footer: nil, rows: [
                .choice(title: L.addClass, symbol: "plus.circle") {
                    PlanWerkzeugRoute.present(
                        .klasseHinzufuegen, from: self.navigationController)
                },
                .choice(title: L.addPerson, symbol: "person.badge.plus") {
                    PlanWerkzeugRoute.present(
                        .personHinzufuegen, from: self.navigationController)
                },
            ]))

        return abschnitte
    }

    /// Wischen nach links: Löschen.
    ///
    /// Das Löschen ist **hier** nur ein Zeichen dafür, dass es passieren soll –
    /// ausgeführt wird es in Dart, wo die Liste steht, aus der gelöscht wird.
    /// Die native Seite kennt die Liste nicht und könnte sie nur raten.
    ///
    /// Rot, weil es ankündigt: Wer das Symbol sieht, weiß vor dem Tippen, was
    /// passiert. Und es passiert **trotzdem nicht sofort** – es fragt erst, und
    /// der Dialog nennt den Namen der Sache – siehe [swipeActions(at:)].
    override func swipeActions(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section < sections.count else { return nil }
        let zeile = sections[indexPath.section].rows[indexPath.row]

        // Nur die Zeilen, die wirklich etwas zu löschen haben. Die Gruppe mit dem
        // Hinzufügen hat es nicht – und ein rotes Symbol an „Klasse hinzufügen"
        // wäre eine Drohung ohne Gegenstand.
        //
        // Deshalb wird hier **nicht** gefragt, ob die Zeile eine Person ist oder
        // eine Klasse, sondern ob sie überhaupt eine Sache darstellt. Das ist
        // eine Frage, die die Zeile beantwortet – siehe `Row.sache`.
        guard let sache = zeile.sache else { return nil }

        let loeschen = UIContextualAction(style: .destructive, title: L.delete) {
            [weak self] _, _, fertig in
            // `fertig(false)` und dann `return`: Beides getrennt, weil
            // `return fertig(false)` zwar ginge, aber aussieht, als gäbe es
            // dort etwas zurückzugeben. Es gibt nichts – der Wurf endet
            // einfach, ohne dass etwas gelöscht wurde.
            guard let self else { fertig(false); return }

            // **Fragen**, bevor irgendetwas passiert.
            //
            // Es gab vorher eine Zeit, in der das Wischen sofort gelöscht hat.
            // Das ist die Art von Bequemlichkeit, die man bereut: Eine Wischgeste
            // ist leicht mal daneben, und was danach fehlt, ist eine Klasse aus
            // dem Plan – mit allen Ausblendungen, die man sich über Wochen
            // eingestellt hat.
            //
            // Der Dialog nennt den **Namen** der Sache, nicht ihre Kennung. Wer
            // „Klasse 8a" liest, weiss, was er verliert; wer „Löschen" neben
            // einer Zeile sieht, die er nicht kennt, weiss es nicht.
            let istPerson = sache.art == .person
            let titel = L.deleteConfirmTitle(
                istPerson ? L.person : L.klasse, self.nameOfRow(zeile))

            let frage = UIAlertController(
                title: titel, message: L.deleteConfirmMessage, preferredStyle: .alert)
            frage.addAction(
                UIAlertAction(title: L.cancel, style: .cancel) { _ in fertig(false) })
            frage.addAction(
                UIAlertAction(title: L.delete, style: .destructive) { _ in
                    // Nur die **Kennung** geht zurück, nicht der Anzeigename: Der
                    // Name kann sich geändert haben, und ein Tipp auf „lösche die
                    // Klasse 8a" würde dann eine Klasse treffen, die es nicht
                    // mehr gibt – oder schlimmer: gar keine, ohne dass irgendwo
                    // ein Fehler stünde.
                    ScreenBridge.action(
                        .plan,
                        istPerson ? "deletePerson" : "deleteClass",
                        args: ["id": sache.kennung])
                    fertig(true)
                })

            self.present(frage, animated: true)
            // `fertig` wird **nicht** hier aufgerufen: Es beendet die Wischgeste,
            // und das Sichtbare soll erst verschwinden, wenn die Frage
            // beantwortet ist. Sonst klappt die Zeile zusammen und das Blatt
            // erscheint darüber – man sähe nicht, worauf man sich einlässt.
        }
        return UISwipeActionsConfiguration(actions: [loeschen])
    }

    /// Der Name, der in einer Zeile steht – für den Löschdialog.
    ///
    /// Auch der **Anzeigename**, nicht die Kennung: Der Dialog soll sagen, was
    /// verschwindet, und nicht, wie die Sache intern heisst.
    private func nameOfRow(_ zeile: Row) -> String {
        if case let .thing(titel, _, _, _, _, _) = zeile { return titel }
        return ""
    }

    // ------------------------------------------------------- von den Zeilen

    /// Baut aus einem Eintrag aus Dart eine Zeile.
    ///
    /// ## Warum aus einer Karte und nicht aus einer Liste von Feldern
    ///
    /// Dart schickt `{id, name, classId}` – nicht `{kennung: …, beschriftung: …}`.
    /// Grund: Die Karte ist eine **Sache** („eine Klasse"), und sie soll auf
    /// beiden Seiten heißen wie sie heißt. Ein Wörterbuch aus „Beschriftung",
    /// „Untertitel" und „Symbol" wäre ein zweites Vokabular für dieselbe Zeile –
    /// und die beiden Seiten müssten sich dann auf dessen Bedeutung einigen,
    /// statt nur auf den Namen.
    ///
    /// Was **nicht** aus Dart kommt, ist das Symbol: Es ist ein Zeichen, und
    /// Zeichen sind eine Sache der nativen Seite.
    private func zeile(_ eintrag: [String: Any]) -> Row {
        let id = (eintrag["id"] as? String) ?? ""
        let name = (eintrag["name"] as? String) ?? id
        // Eine Person ist daran zu erkennen, dass die Karte **auch** ihre Klasse
        // nennt. Eine Klasse nennt nur sich selbst.
        //
        // Bewusst kein Umweg über ein zusätzliches Feld: Dart müsste es dann
        // setzen, und es wäre eine Angabe, die nur eine von beiden Sorten
        // trägt – also eine, die man beim Absenden leicht vergisst. Fehlte sie
        // einmal, stünde eine Person als Klasse da und man öffnete den **falschen**
        // Plan. Das Merkmal, das ohnehin mitgeschickt wird, kann das nicht.
        let klasse = eintrag["classId"] as? String
        let istPerson = klasse != nil

        return .thing(
            title: name,
            // Bei einer Person steht die Klasse darunter – sie ist der zweite
            // Teil davon, **wer** das ist. Bei einer Klasse gäbe es nichts
            // zweites, und eine leere zweite Zeile ließe nur eine Lücke.
            subtitle: klasse,
            symbol: istPerson ? "person.crop.square" : "person.3",
            kennung: id,
            art: istPerson ? .person : .klasse,
            action: {
                // `self` ausdrücklich, nicht `navigation`: Der Wurf schließt den
                // Bildschirm ein und wird von der Liste gehalten, die der
                // Bildschirm hält. Ohne `self` gäbe es zwar keinen Kreis, aber
                // Swift verlangt es hier – und `MoreScreen` macht es genauso.
                PlanDetailRoute.present(
                    classId: klasse ?? id,
                    personId: istPerson ? id : nil,
                    from: self.navigationController)
            }
        )
    }

    // ------------------------------------------------------------ Werkzeuge

    /// Der Knopf oben rechts.
    ///
    /// Der Bildschirm ist in einer Bildschirmreihe, und deshalb ist auch die
    /// Kopfzeile eine – mit dem Zurück-Pfeil und allem, was dazu gehört. Der
    /// Knopf rechts sitzt darin, und nicht in einer eigenen Leiste darüber.
    @objc private func appInfoGetippt() {
        AppInfo.presentSheet(from: self)
    }

    @objc private func heimGetippt() {
        let heim = HomeScreen()
        navigationController?.pushViewController(heim, animated: true)
    }
}

// MARK: - Was eine Zeile über sich selbst weiß

extension Row {

    /// Die Sache, die diese Zeile darstellt – oder `nil`.
    ///
    /// ## Warum das an der Zeile steht und nicht am Bildschirm
    ///
    /// Der Bildschirm hat viele Zeilen, und sie sind nicht alle gleich: Personen,
    /// Klassen, „Klasse hinzufügen". Nur die ersten beiden lassen sich löschen.
    ///
    /// Wüsste der Bildschirm das, müsste er über Zeilen **zählen** und sich
    /// merken, welche Nummer welche Art ist – und das wäre eine zweite Liste, die
    /// zur ersten passen, aber nicht mit ihr wachsen muss. Sobald eine Gruppe
    /// eine Zeile mehr bekommt, wären sie auseinander, und die Folge wäre ein
    /// Wischgeste auf einer Zeile, die gar nicht löschbar ist.
    ///
    /// Deshalb steht es an der Zeile: Sie kann nicht von dem abweichen, was sie
    /// darstellt. Dass die Hinzufügen-Zeilen `nil` geben, ist kein Fehler,
    /// sondern die Regel – der Aufrufer lässt das Wischen dann einfach zu.
    var sache: (kennung: String, art: Row.ThingArt)? {
        if case let .thing(_, _, _, kennung, art, _) = self { return (kennung, art) }
        return nil
    }
}
