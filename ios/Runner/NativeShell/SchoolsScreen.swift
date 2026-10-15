import UIKit

/// Die Schulbereiche – mehrere Schulen in einer Installation.
///
/// ## Warum das in iOS eine Liste mit **Wischen** ist
///
/// Löschen ist der einzige Vorgang hier, der etwas **unwiederbringlich**
/// wegnimmt – und der darf deshalb nicht derselbe sein wie „umbenennen".
/// iOS zeigt solche Vorgänge beim Wischen nach links als Aktion am Zeilenrand.
///
/// Umbenennen steht dort **nicht**, und das ist Absicht: Wischen ist die
/// schnelle Geste, und die ist für das Kurze da. „Neuer Name" ist ein Dialog
/// mit einem Textfeld – dafür ist Wischen der falsche Ort, weil man beim
/// Wischen noch keine Gelegenheit hatte zu tippen, was man eintragen will.
///
/// ## Die erste Schule lässt sich nicht löschen
///
/// Sie ist der Anker: Ihre Werte tragen keinen `schools.`-Vorspann, weil es sie
/// gab, bevor es mehrere Bereiche gab. Fiele sie weg, verlören diese Werte ihren
/// Platz – die App erschiene frisch installiert. Deshalb gibt es für sie
/// überhaupt keine Lösch-Aktion.
final class SchoolsScreen: ListScreen {
    init() {
        super.init(title: L.schools)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self,
            action: #selector(addSchool))
    }

    override func makeSections() -> [Section] {
        let liste = profiles()
        if liste.isEmpty {
            // Der leere Zustand ist **eigens** beschriftet. Eine leere Liste
            // ohne Worte sähe aus wie ein Fehler – dabei ist es nur noch nichts
            // angelegt.
            return [Section(rows: [.text(
                title: L.noSchoolsYet, symbol: "building.2")])]
        }

        return [
            Section(
                footer: L.schoolsSubtitle,
                rows: liste.map { profil in
                    .choice(
                        title: profil.name,
                        symbol: profil.id == AppStore.activeSchoolId
                            ? "checkmark.circle.fill"
                            : "circle",
                        accessory: profil.id == AppStore.activeSchoolId
                            ? .checkmark
                            : .none
                    ) { self.waehle(profil) }
                })
        ]
    }

    private func profiles() -> [SchoolProfile] { AppStore.schoolProfiles() }

    // --------------------------------------------------------------- Handgriffe

    /// Öffnet eine Schule.
    ///
    /// ## Zwei Schritte, und sie sind nicht gleich
    ///
    /// * **Auswählen** – nur wenn es eine andere Schule ist. Sonst würde die
    ///   Zeile jedes Mal hüpfen, ohne dass sich der Bereich geändert hat, und
    ///   die Markierung stünde an zwei Stellen.
    /// * **Öffnen** – **immer**, auch bei der schon aktiven Schule. Sonst gäbe
    ///   es keinen Weg zurück in eine Schule: Man kommt aus dem Plan (oder von
    ///   der Anmeldung) hierher, und das Tippen auf die eigene Schule müsste
    ///   einen Weg zurück öffnen, nicht nichts tun.
    private func waehle(_ profil: SchoolProfile) {
        if profil.id != AppStore.activeSchoolId {
            AppStore.setActiveSchool(profil.id)
            neuLaden()
            NotificationCenter.default.post(
                name: AppStore.activeSchoolDidChange, object: nil)
        }
        AppStore.openSchool()
    }

    @objc private func addSchool() {
        frageNachName(titel: L.addSchool) { [weak self] name in
            guard let self else { return }
            let profil = AppStore.addSchool(named: name)
            AppStore.setActiveSchool(profil.id)
            self.neuLaden()
            NotificationCenter.default.post(
                name: AppStore.activeSchoolDidChange, object: nil)
            // Direkt öffnen – wie beim Tippen auf eine Zeile. Auf Android ist es
            // genauso: Nach dem Anlegen einer Schule öffnet sich sofort die
            // Anmeldung, nicht erst die Schulen-Übersicht.
            AppStore.openSchool()
        }
    }

    private func frageNachName(
        titel: String, start: String? = nil,
        fertig: @escaping (String) -> Void
    ) {
        let alarm = UIAlertController(
            title: titel, message: nil, preferredStyle: .alert)
        alarm.addTextField { feld in
            feld.placeholder = L.schoolNamePlaceholder
            feld.text = start
            feld.clearButtonMode = .whileEditing
            feld.autocapitalizationType = .words
        }
        alarm.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        alarm.addAction(
            UIAlertAction(title: L.save, style: .default) { _ in
                fertig(alarm.textFields?.first?.text ?? "")
            })
        present(alarm, animated: true)
    }

    /// Das Löschen **nur** anbieten, wenn es etwas zu löschen gibt.
    ///
    /// Bei der ersten Schule gäbe es sonst eine Aktion, die nur einen Hinweis
    /// zeigt – und eine Aktion, die nicht tut, was sie ankündigt, ist
    /// schlechter als gar keine.
    ///
    /// Siehe [ListScreen.swipeActions(at:)] – warum hier ein Haken steht und
    /// keine `UITableViewDelegate`-Methode überschrieben wird.
    override func swipeActions(at indexPath: IndexPath)
        -> UISwipeActionsConfiguration?
    {
        let liste = profiles()
        guard indexPath.row < liste.count else { return nil }
        let profil = liste[indexPath.row]
        guard profil.id != "default" else { return nil }

        let loeschen = UIContextualAction(
            style: .destructive, title: L.delete
        ) { [weak self] _, _, fertig in
            self?.frageObLoeschen(profil)
            fertig(true)
        }
        loeschen.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [loeschen])
    }

    private func frageObLoeschen(_ profil: SchoolProfile) {
        let alarm = UIAlertController(
            title: L.deleteSchoolTitle, message: L.deleteSchoolMessage,
            preferredStyle: .alert)
        alarm.addAction(UIAlertAction(title: L.cancel, style: .cancel))
        alarm.addAction(
            UIAlertAction(title: L.delete, style: .destructive) { [weak self] _ in
                AppStore.deleteSchool(profil.id)
                self?.neuLaden()
                NotificationCenter.default.post(
                    name: AppStore.activeSchoolDidChange, object: nil)
            })
        present(alarm, animated: true)
    }
}