import UIKit

/// Welche Angaben eine Stunde im Vertretungsplan zeigt.
///
/// Drei Schalter, und sie betreffen alle dasselbe: **was** neben einer Stunde
/// sichtbar ist und was daneben noch erscheint.
///
/// ## Warum hier eine einmalige Umstellung passiert
///
/// Ältere Versionen hatten für „Personen ausblenden" **aus** als Vorgabe. Einmal
/// wird der alte Wert entfernt, damit die neue Vorgabe gilt – sonst hätte ein
/// Gerät, auf dem nie etwas eingestellt wurde, auf ewig den alten Stand.
///
/// Sie läuft beim **Öffnen** dieser Seite und nicht beim Start der App: Es ist
/// eine einmalige Sache, und sie gehört zu dem Bildschirm, der sie auslöst.
///
/// Siehe [AppStore.hidePersonsMigrationspruefung].
final class LessonInfoScreen: ListScreen {
    init() {
        // Die Umstellung läuft **vor** `super.init` – und damit vor dem ersten
        // Aufbau der Liste. An einer späteren Stelle, etwa in `viewDidLoad`,
        // hätte `makeSections` den alten Wert schon gelesen, und die Zeile
        // stünde einen Frame lang falsch, bevor sie sich berichtigte.
        AppStore.hidePersonsMigrationspruefung()
        super.init(title: L.lessonInfoSettings)
    }

    override func makeSections() -> [Section] {
        [
            Section(
                footer: L.lessonInfoSettingsSubtitle,
                rows: [
                    .toggle(
                        title: L.hideLessonTimes,
                        subtitle: L.hideLessonTimesSubtitle,
                        symbol: "clock.badge.xmark",
                        value: AppStore.hidesLessonTimes
                    ) {[weak self] neu in
                        AppStore.setHidesLessonTimes(neu)
                        self?.speichern()
                    },
                    .toggle(
                        title: L.hideTeacher,
                        subtitle: L.hideTeacherSubtitle,
                        symbol: "person.crop.circle.badge.xmark",
                        value: AppStore.hidesTeacher
                    ) {[weak self] neu in
                        AppStore.setHidesTeacher(neu)
                        self?.speichern()
                    },
                    .toggle(
                        title: L.hidePersons,
                        subtitle: L.hidePersonsSubtitle,
                        symbol: "person.2.slash",
                        value: AppStore.hidesPersons
                    ) {[weak self] neu in
                        AppStore.setHidesPersons(neu)
                        self?.speichern()
                    },
                ])
        ]
    }

    /// Nach jedem Schreiben dem Plan Bescheid sagen.
    ///
    /// Ohne das bliebe der Plan auf dem alten Stand stehen: Er ist eine
    /// Flutter-Ansicht, die ihren Stand beim Bauen liest – und liest ihn nicht
    /// neu, nur weil sich irgendwo etwas geändert hat.
    private func speichern() {
        neuLaden()
        AppStore.didWrite()
    }
}