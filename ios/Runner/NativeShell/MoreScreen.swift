import UIKit

/// Der Werkzeugkasten – der Abschnitt „Mehr“.
///
/// ## Was hier steht und was nicht
///
/// Hier stehen die Dinge, die man **nicht** jeden Tag braucht – und die drei
/// Bildschirme, die auf iOS jetzt **nativ** sind. Sie stehen deshalb hier und
/// nicht in Flutter: Sie sind reine Einstellungen, sie brauchen keine
/// Dart-Isolate, und sie sehen dadurch aus wie die übrigen Apps auf dem Gerät.
///
/// Der Krankheitstracker ist von hier in die **Suche** gewandert. Er sucht
/// genauso wie die beiden anderen dort – nach der Klasse, der Stunden gefehlt
/// haben –, und die Suche ist auch auf iOS ein Reiter.
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
/// ## Zwei bleiben in Flutter – und aus guten Gründen
///
/// * **Lehrerkürzel** braucht den Vertretungsplan: Die Liste der Lehrenden steht
///   im Plan, den der VPlan liefert. Sie hier nachzubauen hieße, den ganzen
///   Abruf, das Einloggen und die Fehlerbehandlung ein zweites Mal – in einer
///   Sprache, in der sie bisher nicht existiert.
/// * **Sichern & Wiederherstellen** braucht das Dateiwahl-Fenster, das
///   Teilen-Menü und die Verschlüsselung. Das sind drei fremde Frameworks, die
///   in Flutter schon dastehen.
///
/// Beide öffnen eine Flutter-Ansicht über der nativen Bildschirmreihe
/// ([FlutterRoute]) – vollständige Bildschirme mit eigener Leiste und eigenem
/// Zustand, nur ohne die Tab-Leiste darunter. Man ist gerade in einem Werkzeug,
/// nicht auf einem anderen Reiter.
final class MoreScreen: ListScreen {
    /// Bewusst **ohne** Überschrift.
    ///
    /// ## Warum
    ///
    /// „Einstellungen“ steht hier als grosser Titel über der Liste – und die
    /// Liste sagt bereits alles: Das sind Einstellungen. Ein Titel, der nichts
    /// hinzufügt, nimmt dem oberen Drittel des Bildschirms nur Platz weg und
    /// schiebt die erste Zeile aus dem Blick, sobald man gerade weit unten in
    /// der Liste war.
    ///
    /// ## Warum kein leerer Titel, sondern wirklich keiner
    ///
    /// `[ListScreen]` bekommt einen Titel für die **Sprache**, nicht für die
    /// Anzeige. Ohne grossen Titel bleibt aber ein kleiner in der Leiste stehen
    /// – und der hiesse dann immer noch „Einstellungen“ über einer Liste, die
    /// sich schon als Einstellungen zu erkennen gibt. Deshalb wird hier beides
    /// abgestellt: kein grosser Titel und kein Wort in der Leiste.
    ///
    /// Der Name lebt trotzdem weiter: als `accessibilityLabel` des Reiters in der
    /// Leiste ([RootTabBarController]), denn für VoiceOver muss die Leiste
    /// beschriftet sein, auch wenn sie unter den Symbolen keinen Text zeigt.
    ///
    /// ## Warum das hier mehr ist als ein abgestellter Titel
    ///
    /// `largeTitleDisplayMode = .never` allein lässt den **Platz** stehen: Die
    /// Bildschirmreihe hat ihre Leiste auf grosse Titel gestellt (siehe
    /// [RootTabBarController]), und die reserviert deren Höhe, bis man
    /// scrollt – mit leerem Titel und ohne jeden Zweck. Deshalb schaltet
    /// `ListScreen` die grossen Titel beim Erscheinen **ab** (siehe
    /// [ListScreen.viewWillAppear]) und wieder ein, sobald ein Bildschirm mit
    /// Titel aufgeschoben wird.
    init() {
        super.init(title: "", largeTitle: false)
    }

    /// Baut die Abschnitte aus dem aktuellen Stand.
    ///
    /// Neu gelesen, weil eine Zeile von den Zugangsdaten abhängt, die es erst
    /// seit dem letzten Besuch geben kann.
    ///
    /// ## Die Reihenfolge ist auf beiden Plattformen **gleich**
    ///
    /// Dieselbe Liste steht in `Settings.dart`. Zwei Reihenfolgen an zwei
    /// Stellen laufen auseinander, sobald eine Zeile verschoben wird – und auf
    /// iOS merkt es niemand, weil dort nur eine der beiden Listen zu sehen ist.
    ///
    /// Von oben: was man beim ersten Öffnen sucht (Aussehen), was den Alltag
    /// betrifft (Plan, Sprache, Lehrerkürzel), was man ab und zu braucht
    /// (Zugangsdaten, Schulen) – und ganz unten die Dinge, die man nur anfasst,
    /// wenn etwas nicht stimmt (Sicherung, Entwickleroptionen).
    ///
    /// **Zugangsdaten und Schulen stehen unmittelbar untereinander:** Beide sagen,
    /// woher die Daten kommen. Wer den Schulbereich wechselt, fasst danach die
    /// Schulen an – sie gehören deshalb nicht an zwei getrennte Stellen der App.
    override func makeSections() -> [Section] {
        var einstellungen: [Row] = [
            .choice(
                title: L.appearance,
                subtitle: L.appearanceSubtitle,
                symbol: "paintpalette"
            ) { self.zeige(AppearanceScreen()) },

            .choice(
                title: L.planSettings,
                subtitle: L.planSettingsSubtitle,
                symbol: "calendar.badge.clock"
            ) { self.zeige(PlanSettingsScreen()) },

            .choice(
                title: L.language,
                subtitle: L.languageSubtitle,
                symbol: "globe"
            ) { self.zeige(LanguageScreen()) },

            .choice(
                title: L.teacherShorts,
                subtitle: L.teacherShortsSubtitle,
                symbol: "person.text.rectangle"
            ) { self.zeigeFlutter(.teacherShorts) },
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
        //
        // Die Schulen folgen ihm unmittelbar – siehe die Beschreibung von
        // [MoreScreen.makeSections].
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
                title: L.schools,
                subtitle: L.schoolsSubtitle,
                symbol: "building.2"
            ) { self.zeige(SchoolsScreen()) })

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

    /// Die Dart-Route, zu der gehört.
    var dartRoute: String {
        switch self {
        case .teacherShorts: return "/werkzeug/lehrerkuerzel"
        case .backup: return "/werkzeug/sicherung"
        }
    }

    /// Der Titel, solange die Ansicht noch keinen eigenen hat.
    var title: String {
        switch self {
        case .teacherShorts: return L.teacherShorts
        case .backup: return L.backup
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