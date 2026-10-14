import UIKit

/// Der Standard-Planmodus – getrennt für vier Dinge.
///
/// Personen, Klassen, die Vorschau der Klassen und die Vorschau der Personen
/// haben je einen eigenen Wert. Vorher gab es nur einen gemeinsamen für die
/// beiden Vorschauen; der wird als Rückfall weiter gelesen, damit bestehende
/// Einstellungen erhalten bleiben ([AppStore.planMode(_:)]).
///
/// ## Warum Zeilen und nicht drei Kacheln
///
/// In Flutter stand hier je Gruppe ein Kopf mit drei Optionsfeldern. Als drei
/// nebeneinanderliegende Kacheln (`Row.segment`) wäre die Erklärung verschwunden
/// – und die ist hier der wichtigere Teil: „Automatisch" allein bedeutet nichts,
/// „Automatisch – zeige heute, ausser der Schultag ist vorbei" bedeutet etwas.
///
/// Deshalb bleibt es bei Zeilen mit Text und Haken, so wie iOS es an allen
/// anderen Stellen auch macht.
///
/// ## Warum hier `for` steht und nicht `map`
///
/// Weil in der Zeile selbst noch ein Verschluss steht. Verschachtelt man beides,
/// muss der Compiler raten, welcher der beiden Verschlüsse der letzte ist – und
/// im Fehlerfall sieht der Fehler aus wie ein Zeichenfehler irgendwo ganz
/// unten. Eine Schleife ist hier nicht hübscher, sondern eindeutiger.
final class PlanModeScreen: ListScreen {
    /// Die Reihenfolge, in der die drei Möglichkeiten stehen.
    ///
    /// In allen vier Gruppen **gleich**: Wer „Automatisch" auch immer wählt,
    /// erwartet es an derselben Stelle wiederzufinden.
    private static let reihenfolge: [PlanMode] = [.automatisch, .latest, .today]

    init() {
        super.init(title: L.defaultPlanModeEntry)
    }

    override func makeSections() -> [Section] {
        let gruppen: [(titel: String, key: AppStore.PlanModeKey)] = [
            (L.planModePerson, .person),
            (L.planModeClass, .klasse),
            (L.defaultPlanModePreviewClass, .vorschauKlasse),
            (L.defaultPlanModePreviewPerson, .vorschauPerson),
        ]

        return gruppen.map { gruppe in
            Section(header: gruppe.titel, rows: self.zeilen(fuer: gruppe.key))
        }
    }

    /// Die drei Zeilen einer Gruppe – eine je Möglichkeit.
    private func zeilen(fuer key: AppStore.PlanModeKey) -> [Row] {
        let gewaehlt = AppStore.planMode(key)
        var zeilen: [Row] = []

        for modus in Self.reihenfolge {
            zeilen.append(
                .choice(
                    title: L.titel(for: modus),
                    subtitle: L.modeSubtitle(for: modus),
                    symbol: Self.symbol(for: modus),
                    accessory: modus == gewaehlt ? .checkmark : .none
                ) { [weak self] in
                    self?.waehle(modus, fuer: key)
                })
        }
        return zeilen
    }

    private static func symbol(for modus: PlanMode) -> String {
        switch modus {
        case .automatisch: return "wand.and.stars"
        case .latest: return "clock.badge"
        case .today: return "calendar"
        }
    }

    private func waehle(_ modus: PlanMode, fuer key: AppStore.PlanModeKey) {
        // Tippt man auf das, was schon gewählt ist, passiert nichts: Sonst
        // würde die Zeile jedes Mal hüpfen, obwohl sich nichts geändert hat.
        guard AppStore.planMode(key) != modus else { return }
        AppStore.setPlanMode(modus, for: key)
        neuLaden()
        AppStore.didWrite()
    }
}
