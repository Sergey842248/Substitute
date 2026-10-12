import UIKit

/// Der Werkzeugkasten – der Abschnitt „Mehr“.
///
/// ## Was hier steht und was nicht
///
/// Hier stehen die Dinge, die man **seltener** braucht: die Einstellungen, der
/// Schulbereich, der Krankheitstracker. Was man täglich braucht – den Plan,
/// die Suche, den Abgleich mit anderen Geräten – steht in der Leiste.
///
/// ## Drei Bildschirme sind jetzt nativ
///
/// Aussehen, Sprache und Schulen sind hier in `UIKit` gebaut, nicht in Flutter.
/// Nicht, weil Flutter das nicht könnte, sondern weil sie es nicht brauchen:
///
/// * Sie brauchen keine Dart-Isolate. Ein Bildschirm, der nur drei Werte liest
///   und schreibt, wäre in Flutter eine ganze laufende Umgebung, die es am
///   Anfang hochfährt und danach den Platz belegt.
/// * Sie sehen dadurch aus wie die übrigen Apps auf dem Gerät. Das ist der
///   Punkt der Umstellung: großes Titel, Listen in Gruppen, Schalter wie von
///   iOS.
///
/// Die übrigen Werkzeuge reichen weiter an Flutter – dort steckt die Arbeit,
///   und dort ist die Umstellung noch nicht dran.
final class MoreScreen: ListScreen {
    init() {
        super.init(title: L.dashboard)
    }

    /// Baut die Abschnitte aus dem aktuellen Stand.
    ///
    /// Neu gelesen, weil eine Zeile von den Zugangsdaten abhängt, die es erst
    /// seit dem letzten Besuch geben kann.
    override func makeSections() -> [Section] {
        var einstellungen: [Row] = [
            .choice(
                title: L.appearance,
                subtitle: L.appearanceSubtitle,
                symbol: "paintpalette"
            ) {
                let controller = AppearanceScreen()
                navigationController?.pushViewController(controller, animated: true)
            },
            .choice(
                title: L.language,
                subtitle: L.languageSubtitle,
                symbol: "globe"
            ) {
                let controller = LanguageScreen()
                navigationController?.pushViewController(controller, animated: true)
            },
            .choice(
                title: L.schools,
                subtitle: L.schoolsSubtitle,
                symbol: "building.2"
            ) {
                let controller = SchoolsScreen()
                navigationController?.pushViewController(controller, animated: true)
            },
        ]

        // Die Zugangsdaten stehen **nur** da, wenn es welche gibt.
        //
        // Stehen sie immer, wäre die Zeile bei einer neuen Installation ein
        // Versprechen, das noch nicht eingelöst ist – und sie führt genau dann
        // ins Nichts, wenn jemand sie zuerst braucht. Deshalb erscheint sie
        // erst mit dem ersten Benutzernamen.
        if AppStore.hasCredentials {
            einstellungen.append(
                .choice(
                    title: L.credentials,
                    subtitle: L.credentialsSubtitle,
                    symbol: "lock"
                ) {
                    FlutterRoute.present(
                        .vplanLogin, from: navigationController)
                })
        }

        // Diese vier liegen in Flutter und standen vorher im Flutter-Dashboard.
        //
        // Das Dashboard gibt es als Reiter nicht mehr – es wurde durch diesen
        // Werkzeugkasten ersetzt. Ohne diese Zeilen wären sie auf iOS weg
        // gewesen, ohne dass es jemand gemerkt hätte, bis er die
        // Sicherung braucht.
        einstellungen.append(
            .choice(
                title: L.planSettings,
                subtitle: L.planSettingsSubtitle,
                symbol: "calendar.badge.clock"
            ) {
                FlutterRoute.present(.planSettings, from: navigationController)
            })
        einstellungen.append(
            .choice(
                title: L.teacherShorts,
                subtitle: L.teacherShortsSubtitle,
                symbol: "person.text.rectangle"
            ) {
                FlutterRoute.present(.teacherShorts, from: navigationController)
            })
        einstellungen.append(
            .choice(
                title: L.backup,
                subtitle: L.backupSubtitle,
                symbol: "externaldrive.badge.timemachine"
            ) {
                FlutterRoute.present(.backup, from: navigationController)
            })
        einstellungen.append(
            .choice(
                title: L.developerOptions,
                subtitle: L.developerOptionsSubtitle,
                symbol: "hammer"
            ) {
                FlutterRoute.present(.developerOptions, from: navigationController)
            })

        return [
            Section(
                header: L.settings,
                footer: L.settingsSubtitle,
                rows: einstellungen),
            Section(
                header: nil,
                rows: [
                    .choice(
                        title: L.sickTrack,
                        subtitle: L.sickTrackSubtitle,
                        symbol: "cross.case"
                    ) {
                        FlutterRoute.present(.sickTrack, from: navigationController)
                    }
                ]),
        ]
    }
}

/// Die Werkzeuge, die noch in Flutter stehen.
///
/// ## Warum sie über eine [FlutterRoute] gehen
///
/// Sie brauchen den Plan, die Klassen, die Listen – also alles, was in Flutter
/// liegt und dort auch bleiben soll. Sie werden deshalb **über** der
/// nativen Bildschirmreihe geöffnet, als eigene Flutter-Ansicht.
///
/// Sie sind damit keine „halben“ Bildschirme, sondern vollständige: Sie haben
/// ihre eigene Leiste oben, ihren eigenen Bildschirm und ihren eigenen Zustand.
/// Was sie nicht haben, ist die Tab-Leiste – und das ist richtig so: Man ist
/// gerade in einem Werkzeug, nicht auf einem anderen Reiter.
enum FlutterRoute {
    case vplanLogin
    case sickTrack
    case planSettings
    case teacherShorts
    case backup
    case developerOptions

    /// Die Dart-Route, zu der gehört.
    var dartRoute: String {
        switch self {
        case .vplanLogin: return "/werkzeug/anmelden"
        case .sickTrack: return "/werkzeug/krankheitstracker"
        case .planSettings: return "/werkzeug/plan-einstellungen"
        case .teacherShorts: return "/werkzeug/lehrerkuerzel"
        case .backup: return "/werkzeug/sicherung"
        case .developerOptions: return "/werkzeug/entwickleroptionen"
        }
    }

    /// Der Titel, solange die Ansicht noch keinen eigenen hat.
    var title: String {
        switch self {
        case .vplanLogin: return L.credentials
        case .sickTrack: return L.sickTrack
        case .planSettings: return L.planSettings
        case .teacherShorts: return L.teacherShorts
        case .backup: return L.backup
        case .developerOptions: return L.developerOptions
        }
    }

    /// Öffnet die Ansicht über der nativen Reihe.
    static func present(
        _ route: FlutterRoute, from navigation: UINavigationController?
    ) {
        let options = FlutterEngineGroupOptions()
        options.entrypoint = "main"
        // Ohne Rolle: Diese Ansicht ist **die ganze App** – sie hat ihre
        // eigene Leiste, und sie ist keine Karte der Leiste darunter.
        options.entrypointArgs = []
        options.initialRoute = route.dartRoute

        // Eine eigene Maschine: Das Werkzeug soll die Abschnitte nicht
        // zurücksetzen, in die man vorher gegangen ist.
        let group = FlutterEngineGroup(name: "substitute-werkzeug", project: nil)
        let engine = group.makeEngine(with: options)
        // Siehe [FlutterEngines.registerPlugins]: Ohne das hätte diese
        // Maschine kein Programm und damit auch keinen Speicher.
        FlutterEngines.registerPlugins(on: engine)

        let controller = FlutterViewController(
            engine: engine, nibName: nil, bundle: nil)
        controller.title = route.title

        navigation?.pushViewController(controller, animated: true)
    }
}