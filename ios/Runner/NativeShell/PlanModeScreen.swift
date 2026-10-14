import UIKit

/// Der Standard-Planmodus – getrennt für vier Dinge.
///
/// Personen, Klassen, die Vorschau der Klassen und die Vorschau der Personen
/// haben je einen eigenen Wert. Vorher gab es nur einen gemeinsamen für die
/// beiden Vorschauen; der wird als Rückfall weiter gelesen, damit bestehende
/// Einstellungen erhalten bleiben ([AppStore.planMode(_:)]).
///
/// ## Warum vier Zeilen und nicht drei Kacheln
///
/// In Dart steht hier je Gruppe eine Zeile mit Erklärung; in Flutter waren es
/// drei Optionsfelder. Als drei nebeneinanderliegende Kacheln (`Row.segment`)
/// wäre die Erklärung verschwunden – und die ist hier der wichtigere Teil:
/// „Automatisch" allein bedeutet nichts, „Automatisch – zeige heute, ausser der
/// Schultag ist vorbei" bedeutet etwas.
///
/// Deshalb bleibt es bei Zeilen mit Text und Haken, so wie iOS es an allen
/// anderen Stellen auch macht.
final class PlanModeScreen: ListScreen {
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

        return gruppen.map {[weak self] gruppe in
            let gewaehlt = AppStore.planMode(gruppe.key)
            return Section(
                header: gruppe.titel,
                rows: [PlanMode.automatisch, .latest, .today].map { modus in
                    .choice(
                        title: L.titel(for: modus),
                        subtitle: L.modeSubtitle(for: modus),
                        symbol: Self.symbol(for: modus),
                        accessory: modus == gewaehlt ? .checkmark : .none
                    ) { self?.waehle(modus, fuer: gruppe.key) }
                })
        }}              })
        }
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