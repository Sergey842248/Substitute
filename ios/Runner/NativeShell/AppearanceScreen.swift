import UIKit

/// Das Aussehen – hell oder dunkel, und was in der Leiste steht.
///
/// ## Derselbe Speicher wie Flutter
///
/// Jeder Wert hier geht in dieselben `UserDefaults`, die Flutter benutzt
/// ([AppStore]). Deshalb sind die Schlüssel ausgeschrieben und nicht erfunden,
/// und deshalb stimmt das Bild hier mit dem auf dem Plan-Bildschirm überein.
///
/// ## Warum sich sofort etwas bewegt
///
/// Die Einstellung wirkt an Bildschirmen, die gerade **nicht** im Vordergrund
/// sind: Das Theme baut die Flutter-Seite, die Leiste steht hier. Ohne eine
/// gemeinsame Quelle wüsste beim Zurückkehren niemand, dass sich etwas
/// geändert hat.
///
/// ## Warum das Erscheinungsbild ein **Menü** ist und keine zwei Kacheln
///
/// Es war einmal eine Auswahl aus zwei Kacheln – „Dunkel" und „Hell" nebeneinander.
/// Zwei kurze Worte passen darin, aber das Aussehen hat mehr Werte bekommen
/// (etwa „wie das Gerät"), und dann passt die dritte Kachel nicht mehr daneben:
/// Sie rutscht in die nächste Zeile und macht aus einer Zeile zwei.
///
/// Das Menü hat das nicht: Es zeigt nur das Gewählte, rechts daneben, mit einem
/// Doppelpfeil. Eine dritte Möglichkeit kostet nichts, und die Zeile bleibt
/// eine Zeile.
final class AppearanceScreen: ListScreen {
    init() {
        super.init(title: L.appearance)
    }

    override func makeSections() -> [Section] {
        [
            Section(
                header: L.appearanceTheme,
                footer: L.appearanceThemeSubtitle,
                rows: [
                    .menu(
                        title: L.appearanceTheme,
                        symbol: "paintpalette",
                        options: themaMoeglichkeiten())
                ]),
            Section(
                rows: [
                    .toggle(
                        title: L.showSyncTab,
                        subtitle: L.showSyncTabSubtitle,
                        symbol: "arrow.triangle.2.circlepath",
                        value: AppStore.showsSyncShareTab
                    ) { [weak self] neu in
                        AppStore.setShowsSyncShareTab(neu)
                        self?.speichern()
                        // Die Leiste ist längst gebaut. Sie erfährt von der
                        // Änderung erst dadurch, dass hier etwas gesagt wird –
                        // sonst behielte sie den alten Eintrag, bis die App neu
                        // gestartet wird.
                        NotificationCenter.default.post(
                            name: AppStore.syncTabDidChange, object: nil)
                    },
                    .toggle(
                        title: L.showWeekView,
                        subtitle: L.showWeekViewSubtitle,
                        symbol: "calendar",
                        value: AppStore.showsWeekView
                    ) { [weak self] neu in
                        AppStore.setShowsWeekView(neu)
                        self?.speichern()
                    },
                ]),
        ]
    }

    /// Die Möglichkeiten für das Erscheinungsbild, mit der gewählten markiert.
    ///
    /// Bei **jedem** Aufbau neu gebaut: Das Menü merkt sich den Stand nicht, und
    /// der Haken muss wandern, sobald jemand einen anderen Wert wählt.
    private func themaMoeglichkeiten() -> [MenuOption] {
        let gewählt = AppStore.theme
        return [
            MenuOption(
                title: L.dark,
                symbol: "moon.fill",
                isSelected: gewählt == .dark
            ) { [weak self] in
                AppStore.setTheme(.dark)
                self?.speichern()
            },
            MenuOption(
                title: L.light,
                symbol: "sun.max.fill",
                isSelected: gewählt == .light
            ) { [weak self] in
                AppStore.setTheme(.light)
                self?.speichern()
            },
        ]
    }

    /// Nach jedem Schreiben: Bild neu aufbauen und beiden Seiten Bescheid sagen.
    ///
    /// Siehe [AppStore.didWrite]: Flutter liest aus einem Cache, und der kennt
    /// nur, was Dart selbst geschrieben hat.
    private func speichern() {
        neuLaden(animiert: true)
        AppStore.didWrite()
    }
}
