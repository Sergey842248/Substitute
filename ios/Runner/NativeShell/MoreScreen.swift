import UIKit

/// Der Werkzeugkasten – der Abschnitt „Mehr“.
///
/// ## Was hier steht und was nicht
///
/// Hier stehen die Dinge, die man **seltener** braucht: die Einstellungen, der
/// Schulbereich, der Krankheitstracker. Was man täglich braucht – den Plan,
/// die Suche, den Abgleich mit anderen Geräten – steht in der Leiste.
///
/// ## Fast alles hier ist jetzt nativ
///
/// Aussehen, Sprache, Schulen, Anmeldedaten, Plan-Einstellungen mit ihren vier
/// Untermenüs und die Entwickleroptionen sind in `UIKit` gebaut, nicht in
/// Flutter. Nicht, weil Flutter das nicht könnte, sondern weil sie es nicht
/// brauchen:
///
/// * Sie brauchen keine Dart-Isolate. Ein Bildschirm, der ein paar Werte liest
///   und schreibt, wäre in Flutter eine ganze laufende Umgebung, die es am
///   Anfang hochfährt und danach den Platz belegt.
/// * Sie sehen dadurch aus wie die übrigen Apps auf dem Gerät. Das ist der
///   Punkt der Umstellung: grosses Titel, Listen in Gruppen, Schalter wie von
///   iOS.
///
/// ## Drei bleiben in Flutter – und aus guten Gründen
///
/// * **Lehrerkürzel** braucht den Vertretungsplan: Die Liste der Lehrenden steht
///   im Plan, den der VPlan liefert. Sie hier nachzubauen hieße, den ganzen
///   Abruf, das Einloggen und die Fehlerbehandlung ein zweites Mal – in einer
///   Sprache, in der sie bisher nicht existiert.
/// * **Sichern & Wiederherstellen** braucht das Dateiwahl-Fenster, das
///   Teilen-Menü und die Verschlüsselung. Das sind drei fremde Frameworks, die
///   in Flutter schon dastehen.
/// * **Krankheitstracker** bleibt, weil es eine eigene Aufgabe ist: Unterschriften
///   einsammeln.
///
/// Die beiden ersten öffnen eine Flutter-Ansicht über der nativen Bildschirmreihe
/// ([FlutterRoute]) – vollständige Bildschirme mit eigener Leiste und eigenem
/// Zustand, nur ohne die Tab-Leiste darunter. Man ist gerade in einem Werkzeug,
/// nicht auf einem anderen Reiter.
final class MoreScreen: ListScreen {
    /// Bewusst **ohne** Überschrift.
    ///
    /// ## Warum
    ///
    /// „Dashboard" stand hier als grosser Titel über der Liste – und die Liste
    /// sagt bereits alles: Das sind Werkzeuge. Ein Titel, der nichts hinzufügt,
    /// nimmt dem oberen Drittel des Bildschirms nur Platz weg und schiebt die
    /// erste Zeile aus dem Blick, sobald man gerade weit unten in der Liste war.
    ///
    /// ## Warum kein leerer Titel, sondern wirklich keiner
    ///
    /// `[ListScreen]` bekommt einen Titel für die **Sprache**, nicht für die
    /// Anzeige. Ohne grossen Titel bleibt aber ein kleiner in der Leiste stehen –
    /// und der hiesse dann immer noch „Dashboard". Deshalb wird hier beides
    /// abgestellt: kein grosser Titel und kein Wort in der Leiste.
    ///
    /// Der Name des Werkzeugkastens lebt trotzdem weiter: als
    /// `accessibilityLabel` des Reiters in der Leiste
    /// ([RootTabBarController]), denn für VoiceOver muss die Leiste beschriftet
    /// sein, auch wenn sie unter den Symbolen keinen Text zeigt.
    init() {
        super.init(title: "", largeTitle: false)
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
            ) { self.zeige(AppearanceScreen()) },

            .choice(
                title: L.language,
                subtitle: L.languageSubtitle,
                symbol: "globe"
            ) { self.zeige(LanguageScreen()) },

            .choice(
                title: L.schools,
                subtitle: L.schoolsSubtitle,
                symbol: "building.2"
            ) { self.zeige(SchoolsScreen()) },
        ]

        // Die Zugangsdaten stehen **nur** da, wenn es welche gibt.
        //
        // Stehen sie immer, wäre die Zeile bei einer neuen Installation ein
        // Versprechen, das noch nicht eingelöst ist – und sie führt genau dann
        // ins Nichts, wenn jemand sie zuerst braucht. Deshalb erscheint sie
        // erst mit dem ersten Benutzernamen.
        //
        // Das ist dasselbe Kriterium, nach dem die Tab-Leiste erscheint
        // ([AppStore.hasCredentials]): Der Werkzeugkasten ohne Leiste ist genau
        // die Lage, in der es auch ohne Zugangsdaten nichts zu tun gäbe.
        if AppStore.hasCredentials {
            einstellungen.append(
                .choice(
                    title: L.credentials,
                    subtitle: L.credentialsSubtitle,
                    symbol: "lock"
                ) { self.zeige(CredentialsScreen()) })
        }

        einstellungen.append(
            .choice(
                title: L.planSettings,
                subtitle: L.planSettingsSubtitle,
                symbol: "calendar.badge.clock"
            ) { self.zeige(PlanSettingsScreen()) })

        einstellungen.append(
            .choice(
                title: L.teacherShorts,
                subtitle: L.teacherShortsSubtitle,
                symbol: "person.text.rectangle"
            ) { self.zeigeFlutter(.teacherShorts) })

        einstellungen.append(
            .choice(
                title: L.backup,
                subtitle: L.backupSubtitle,
                symbol: "externaldrive.badge.timemachine"
            ) { self.zeigeFlutter(.backup) })

        einstellungen.append(
            .choice(
                title: L.developerOptions,
                subtitle: L.developerOptionsSubtitle,
                symbol: "hammer"
            ) { self.zeige(DeveloperOptionsScreen()) })

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
                    ) { self.zeigeFlutter(.sickTrack) }
                ]),
        ]
    }

    // --------------------------------------------------------------- Wege

    /// Öffnet einen **nativen** Bildschirm.
    private func zeige(_ screen: UIViewController) {
        navigationController?.pushViewController(screen, animated: true)
    }

    /// Öffnet einen Bildschirm, der in Flutter liegt.
    private func zeigeFlutter(_ route: FlutterRoute) {
        FlutterRoute.present(route, from: navigationController)
    }
}

/// Die Werkzeuge, die noch in Flutter stehen.
///
/// ## Warum sie über eine [FlutterRoute] gehen
///
/// Sie brauchen den Plan, die Klassen, das Dateiwahl-Fenster – also alles, was
/// in Flutter liegt und dort auch bleiben soll. Sie werden deshalb **über** der
/// nativen Bildschirmreihe geöffnet, als eigene Flutter-Ansicht.
///
/// Sie sind damit keine „halben“ Bildschirme, sondern vollständige: Sie haben
/// ihre eigene Leiste oben, ihren eigenen Bildschirm und ihren eigenen Zustand.
/// Was sie nicht haben, ist die Tab-Leiste – und das ist richtig so: Man ist
/// gerade in einem Werkzeug, nicht auf einem anderen Reiter.
enum FlutterRoute {
    case teacherShorts
    case backup
    case sickTrack

    /// Die Dart-Route, zu der gehört.
    var dartRoute: String {
        switch self {
        case .teacherShorts: return "/werkzeug/lehrerkuerzel"
        case .backup: return "/werkzeug/sicherung"
        case .sickTrack: return "/werkzeug/krankheitstracker"
        }
    }

    /// Der Titel, solange die Ansicht noch keinen eigenen hat.
    var title: String {
        switch self {
        case .teacherShorts: return L.teacherShorts
        case .backup: return L.backup
        case .sickTrack: return L.sickTrack
        }
    }

    /// Öffnet die Ansicht über der nativen Reihe.
    static func present(
        _ route: FlutterRoute, from navigation: UINavigationController?
    ) {
        let options = FlutterEngineGroupOptions()
        options.entrypoint = "main"
        // Werkzeuge sind keine Reiter, aber sie stehen in der nativen Hülle.
        // Die Rolle verhindert, dass Flutter ihren weiterhin gemeldeten
        // unteren Safe-Area-Bereich als dauerhafte leere Schicht zeichnet.
        // Sie bleibt bewusst von den Reiter-Rollen getrennt: Die Tab-Leiste
        // wird für ein Werkzeug weiterhin ausgeblendet.
        options.entrypointArgs = ["--substitute-role=tool"]
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