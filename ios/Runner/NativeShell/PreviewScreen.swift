import UIKit

/// Die „Nächste Stunde“-Vorschau unter den Klassen und unter den Personen.
///
/// ## Warum die Vorgaben **verschieden** sind
///
/// Bei Klassen ist die Vorschau standardmäßig **an** – sie gehört dort zum
/// Bild, das man vom Plan erwartet. Bei Personen ist sie **aus**, und der Grund
/// steht in `VPlanAPI.defaultPreviewPersonsHidden`: Eine Person zeigt sonst sehr
/// schnell nur noch die nächste Stunde des einen Kurses, den man gerade
/// ausgewählt hat, und die Liste der Personen verliert ihren eigentlichen
/// Zweck.
///
/// Deshalb sind das hier zwei getrennte Schalter und nicht einer, und deshalb
/// steht in [AppStore] für jeden eine eigene Vorgabe.
final class PreviewScreen: ListScreen {
    init() {
        super.init(title: L.previewSettings)
    }

    override func makeSections() -> [Section] {
        [
            Section(
                footer: L.previewSettingsSubtitle,
                rows: [
                    .toggle(
                        title: L.hidePreviewClasses,
                        subtitle: L.hidePreviewClassesSubtitle,
                        symbol: "square.grid.2x2",
                        value: AppStore.hidesPreviewClasses
                    ) {[weak self] neu in
                        AppStore.setHidesPreviewClasses(neu)
                        self?.speichern()
                    },
                    .toggle(
                        title: L.hidePreviewPersons,
                        subtitle: L.hidePreviewPersonsSubtitle,
                        symbol: "person.crop.rectangle",
                        value: AppStore.hidesPreviewPersons
                    ) {[weak self] neu in
                        AppStore.setHidesPreviewPersons(neu)
                        self?.speichern()
                    },
                ])
        ]
    }

    /// Nach jedem Schreiben den Ansichten Bescheid sagen.
    ///
    /// ## Warum das hier nicht genügt, nur die Liste neu zu bauen
    ///
    /// Die Vorschau entsteht beim Plan – und der Plan ist Flutter. Er liest
    /// seinen Stand aus dem **Cache** von `SharedPreferences`, und der kennt
    /// nur, was Dart selbst geschrieben hat. Ohne [AppStore.didWrite] bliebe der
    /// Wert dort stehen, den man gerade eben umgestellt hat, ohne dass irgendwo
    /// ein Fehler erschiene.
    private func speichern() {
        neuLaden()
        AppStore.didWrite()
    }
}