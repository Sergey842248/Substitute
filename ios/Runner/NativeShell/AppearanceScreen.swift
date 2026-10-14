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
                    .segment(
                        title: L.appearanceTheme,
                        symbol: "paintpalette",
                        options: [
                            SegmentOption(
                                title: L.dark,
                                symbol: "moon.fill",
                                isSelected: AppStore.theme == .dark
                            ) {
                                AppStore.setTheme(.dark)
                                self.speichern()
                            },
                            SegmentOption(
                                title: L.light,
                                symbol: "sun.max.fill",
                                isSelected: AppStore.theme == .light
                            ) {
                                AppStore.setTheme(.light)
                                self.speichern()
                            },
                        ])
                ]),
            Section(
                rows: [
                    .toggle(
                        title: L.showSyncTab,
                        subtitle: L.showSyncTabSubtitle,
                        symbol: "arrow.triangle.2.circlepath",
                        value: AppStore.showsSyncShareTab
                    ) { neu in
                        AppStore.setShowsSyncShareTab(neu)
                        self.speichern()
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
                    ) { neu in
                        AppStore.setShowsWeekView(neu)
                        self.speichern()
                    },
                ]),
        ]
    }

    /// Nach jedem Schreiben: Bild neu aufbauen und beiden Seiten Bescheid sagen.
    ///
    /// Siehe [AppStore.didWrite]: Flutter liest aus einem Cache, und der kennt
    /// nur, was Dart selbst geschrieben hat.
    private func speichern() {
        neuLaden()
        AppStore.didWrite()
    }
}