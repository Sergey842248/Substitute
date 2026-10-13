import Flutter
import UIKit

/// Die Tab-Leiste der App – der Teil, der auf iOS jetzt **nativ** ist.
///
/// ## Was hier passiert und warum es nicht andersherum
///
/// iOS erwartet, dass die Leiste ein `UITabBarController` ist: Das ist die
/// einzige Leiste, die sich richtig verhält – sie wird durchsichtig, sie
/// schrumpft beim Scrollen, sie hat Haptik, sie merkt sich den gewählten
/// Eintrag, sie wird vom System mit grossen Titeln versorgt.
///
/// Flutter baut aus einem Grund keine solche Leiste: Sie kennt keine
/// Bildschirmgrenzen, kein „unten ist gerade der Daumen", keine
/// Ebenenübergänge. Sie zeichnet eine Liste von Symbolen und nennt das Leiste.
///
/// Deshalb steht hier ein echter `UITabBarController`, und die Abschnitte der
/// App liegen als **echte** Ansichtssteuerer darin. Nur der Inhalt ist noch
/// Flutter – und genau dort, wo die App ihre complicierte Arbeit macht.
///
/// ## Wie die Abschnitte aufgebaut sind
///
/// Jeder Abschnitt bekommt **eine eigene** Flutter-Ansicht mit eigener
/// Maschine. Nicht eine für alle mit umgeschaltetem Inhalt, und das aus einem
/// Grund, der leicht zu übersehen ist:
///
/// Eine Flutter-Ansicht hat einen Bildschirm. Wenn drei Abschnitte sich dieselbe
/// teilen, sieht die Leiste immer die, die gerade obenauf liegt – und die
/// Abschnitte, die man verlassen hat, verlieren ihren Zustand: Der gewählte
/// Eintrag springt beim Zurückkommen auf das letzte Bild, der gewischte Plan
/// ist wieder oben, die halb getippte Suche ist weg.
///
/// Mit einer Ansicht je Abschnitt ist das nicht möglich. Jede behält ihren
/// Bildschirm, solange sie im Tab-Balken steht.
///
/// ## Der Preis, und warum er sich lohnt
///
/// Jede Ansicht ist eine eigene Dart-Isolate: Es gibt also drei Kopien davon,
/// was im Arbeitsspeicher steht. Deshalb macht **nur die Plan-Ansicht** den
/// Hintergrund-Sync und den Hintergrund-Abruf – sonst liefe beides dreimal.
/// Siehe `NativeShell.runsBackgroundWork` auf der Dart-Seite.
final class RootTabBarController: UITabBarController {
    // `FlutterEngineGroup` braucht einen Namen und das Projekt – die blosse
    // Initialisierung ist nicht zugelassen (`init NS_UNAVAILABLE`). Der Name
    // ist nur die Bezeichnung der gemeinsamen Gruppe; er erscheint nirgends.
    private let engines = FlutterEngineGroup(name: "substitute-shell", project: nil)
    private var controllers: [Tab] = []
    private var chromeHidden = false

    /// Die Abschnitte der Leiste, in der Reihenfolge, in der sie stehen.
    ///
    /// Gelesen von der Reihenfolge hier und **nicht** umgekehrt: Die Reihenfolge
    /// ist eine Entscheidung der Oberfläche, und die Abschnitte wählen sich nicht
    /// gegenseitig aus.
    ///
    /// `Equatable` braucht es, weil [bauen] die alte Liste mit der gewünschten
    /// vergleicht, um zu erfahren, ob sich überhaupt etwas geändert hat – und
    /// einen **Schlüssel**, um den zuletzt gesehen Abschnitt wiederzufinden.
    private enum Tab: Equatable {
        case plan
        case search
        case sync
        case more

        /// Der Name, den die Dart-Seite als Startargument bekommt.
        ///
        /// Bewusst ein **einfacher englischer Name** und nicht der Anzeigename:
        /// Der ist übersetzt und sprachabhängig, und ein Argument, das sich mit
        /// der eingestellten Sprache ändert, wäre eine Fehlerquelle, die man
        /// erst beim Umstellen der Sprache suchen müsste.
        var dartRole: String {
            switch self {
            case .plan: return "plan"
            case .search: return "search"
            case .sync: return "sync"
            case .more: return ""
            }
        }
    }

    // --------------------------------------------------------------- Aufbau

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Appearance.background
        delegate = self

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsDidChange),
            name: AppStore.settingsDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsDidChange),
            name: AppStore.syncTabDidChange, object: nil)

        // ## Warum zusätzlich ans Wiedererwachen der App
        ///
        // Ob die Leiste stehen darf, hängt an den Zugangsdaten – und die werden
        // **in Flutter** eingetragen, auf der Anmeldeseite. Das erreicht diese
        // Seite über keinen der obigen Wege: `settingsChanged` melden nur das
        // Aussehen und die Sprache, weil nur dort etwas darüber gesagt wird.
        ///
        // Ohne diesen Zuhörer bliebe die Leiste nach dem Anmelden weg – und
        // bliebe auch dann weg, wenn man sie von Hand schliesse und die App
        // wieder aufmacht. Sie käme erst nach einem Neustart zurück, was sich
        // wie ein Fehler anfühlt und nicht wie eine Regel.
        //
        // Beim Wiedererwachen wird deshalb nur **geprüft**, ob die Leiste
        // gerade stehen darf. Das ist billig und kommt genau dann zum Tragen,
        // wenn sich etwas geändert haben könnte.
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsDidChange),
            name: UIApplication.didBecomeActiveNotification, object: nil)

        bauen()
        farbenSetzen()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Setzt die Leiste aus den Abschnitten zusammen.
    ///
    /// ## Warum hier **nicht** bei jeder Änderung neu gebaut wird
    ///
    /// Der naheliegende Aufbau wäre: bei jeder Meldung alles neu erzeugen. Das
    /// ist aber falsch, und zwar teuer:
    ///
    /// Jeder Abschnitt besitzt eine **Flutter-Maschine**, und die bringt beim
    /// Start die ganze App mit – auch die teuren Durchgänge beim Start
    /// (`healForms`, `repairLists`). Würde ein **Hell-auf-Dunkel**-Wechsler die
    /// Leiste neu bauen, liefen die **dreimal** durch, obwohl sich an der Zahl
    /// der Abschnitte **nichts** geändert hat.
    ///
    /// Gebaut wird deshalb nur, wenn sich die Menge der Abschnitte wirklich
    /// geändert hat – also genau dann, wenn der Sync-Eintrag ein- oder
    /// weggenommen wird. Sonst genügt es, die Farben zu setzen.
    private func bauen() {
        let gewuenscht = abschnitte()

        // Nichts hinzugekommen, nichts weg: Nichts zu tun. Das ist der Fall für
        // **jede** Helligkeits- und Sprachänderung.
        guard gewuenscht != controllers else {
            farbenSetzen()
            return
        }

        let aktuelleAuswahl = selectedIndex
        // Welcher Abschnitt war gerade da? Das wird über seinen **Schlüssel**
        // behalten und nicht über seine Nummer – die verschiebt sich, sobald der
        // Sync-Eintrag davor weggeht.
        //
        // Ohne das sprang die Leiste beim Abschalten von „Sync" vom Plan auf
        // „Suche", obwohl man im Plan war.
        let vorherAktiv: Tab? =
            aktuelleAuswahl >= 0 && aktuelleAuswahl < controllers.count
            ? controllers[aktuelleAuswahl] : nil

        var neuer: [UIViewController] = []
        var neuListe: [Tab] = []

        for section in gewuenscht {
            let controller: UIViewController
            switch section {
            case .plan, .search, .sync:
                let flutterSection = PlanSectionController(engines: engines)
                // Die Rolle **muss** hier gesetzt sein: Sie entscheidet, welcher
                // Abschnitt in dieser Ansicht steht, und sie entscheidet es
                // vor dem ersten Frame. Würde sie erst beim Aufbau gesetzt,
                // stünde für einen Moment die falsche Seite.
                flutterSection.einrichten(role: section.dartRole)
                controller = flutterSection
            case .more:
                controller = MoreSectionController()
            }
            controller.tabBarItem = tabBarItem(for: section)
            neuer.append(controller)
            neuListe.append(section)
        }

        controllers = neuListe
        setViewControllers(neuer, animated: false)

        // Der zuletzt gesehen Abschnitt wird wiederhergestellt, wenn er noch
        // da ist – sonst die erste Stelle.
        if let vorherAktiv,
           let index = neuListe.firstIndex(of: vorherAktiv)
        {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
    }

    /// Welche Abschnitte gerade stehen.
    ///
    /// Der Sync-Abschnitt ist der einzige, der von einer Einstellung abhängt –
    /// und er fehlt dann **ganz**. Nicht ausgegraut: Ein ausgegrautes Symbol
    /// verspricht eine Funktion und gibt sie nicht, und wer sie ausschaltet,
    /// will sie nicht im Weg haben.
    private func abschnitte() -> [Tab] {
        var liste: [Tab] = [.plan, .search]
        if AppStore.showsSyncShareTab { liste.append(.sync) }
        liste.append(.more)
        return liste
    }

    /// Der Eintrag eines Reiters: **nur** ein Symbol, kein Text.
    ///
    /// ## Warum kein Text unter dem Symbol
    ///
    /// Gewünscht ist eine Leiste mit Symbolen allein. Das ist auch in Ordnung
    /// so – allerdings nur, wenn die Symbole **selbsterklärend** sind.
    ///
    /// ## Warum trotzdem ein Name für VoiceOver
    ///
    /// Ein sichtbarer Titel ist nicht dasselbe wie ein zugänglicher Name. Ohne
    /// `accessibilityLabel` sagt VoiceOver nur „Button“ – und die Leiste ist
    /// genau die Stelle, über die man mit den Augen nichts erfährt. Der Name
    /// wird deshalb gesetzt, auch wenn er nirgends **zu sehen** ist.
    ///
    /// ## Warum kein eigenes Symbol für den gewählten Zustand
    ///
    /// Früher lag hier ein `selectedImage`. Mehrere davon – etwa
    /// `magnifyingglass.circle.fill` oder
    /// `arrow.triangle.2.circlepath.circle.fill` – **gibt es in SF Symbols
    /// nicht**. `UIImage(systemName:)` liefert dafür `nil`, und `nil` als
    /// ausgewähltes Bild bedeutet: Der Reiter zeigt im aktiven Zustand
    /// **gar nichts**, weil das ungewählte Bild dann ebenfalls wegfällt.
    ///
    /// Statt eine Liste zu pflegen, die immer einen Teil falsch hat, wird die
    /// Auswahl allein über die **Farbe** gezeigt: `tabBar.tintColor` färbt den
    /// gewählten Eintrag, die anderen bleiben grau. Das ist zugleich das, was
    /// iOS selbst tut, wenn man `isEnabled`-Zustände über `tintColor` steuert.
    private func tabBarItem(for section: Tab) -> UITabBarItem {
        let titel: String
        let symbol: String

        switch section {
        case .plan:
            titel = L.vplanStudents
            symbol = "calendar"
        case .search:
            titel = L.search
            symbol = "magnifyingglass"
        case .sync:
            titel = L.syncShare
            symbol = "arrow.triangle.2.circlepath"
        case .more:
            titel = L.dashboard
            symbol = "ellipsis.circle"
        }

        // `title: nil` – **nicht** `title: ""`. Ein leerer Titel würde in manchen
        // iOS-Versionen den Platz trotzdem reservieren und die Symbole
        // nach oben schieben, statt sie zu zentrieren.
        let eintrag = UITabBarItem(
            title: nil,
            image: UIImage(systemName: symbol),
            selectedImage: nil)

        // Für VoiceOver und für „Was ist das?"-Menüs, nie sichtbar.
        eintrag.accessibilityLabel = titel
        eintrag.accessibilityTraits = .button
        return eintrag
    }

    //// Trägt die gewählte Helligkeit auf die Leiste.
    ///
    /// Nur die Leiste, nicht den ganzen Bildschirm: Die Abschnitte tragen ihr
    /// Bild selbst, und würde man ihnen das hier aufzwingen, sähe man beim
    /// Umschalten kurz das falsche.
    private func farbenSetzen() {
        tabBar.tintColor = Appearance.accent
        view.backgroundColor = Appearance.background

        // Die Leiste liegt **auf** dem Inhalt, nicht als eigene Schicht darüber.
        //
        // Ohne diese drei Angaben malt das System die Leiste als schwebendes
        // Gebilde: durchsichtig, mit weichem Rand und einem Schatten, und mit
        // Abstand zum unteren Bildschirmrand. Zwischen ihr und dem Inhalt steht
        // dann eine Lücke, in der der Inhalt durchscheint – genau die „Schicht
        // dazwischen", die stört.
        //
        // * `isTranslucent` aus: eine deckende Leiste kann keinen Inhalt
        //   durchlassen.
        // * Der Hintergrund in der **Farbe des Inhaltsgrunds**: Wäre er eine
        //   andere, sähe man den Übergang als Streifen.
        // * `scrollEdgeAppearance` ebenfalls: Das ist die Variante, die das
        //   System beim Scrollen einsetzt, und sie ist die schwebende.
        tabBar.isTranslucent = false
        tabBar.backgroundColor = Appearance.background
        tabBar.scrollEdgeAppearance = tabBar.standardAppearance

        // Das Fenster trägt die Helligkeit für alles, was **das System** malt:
        // Alarme, Auswahllisten, die Action-Sheets. Ohne dieses Nachziehen
        // bliebe es beim hellen Bild dunkel – die Leiste und die
        // Einstellungsseite wären hell, jeder vom System gezeichnete Dialog
        // aber dunkel.
        //
        // Der AppDelegate setzt das einmal beim Start; ab hier wird es bei jeder
        // Änderung nachgezogen, sonst gälte nur der Stand von damals.
        view.window?.overrideUserInterfaceStyle =
            Appearance.current == .dark ? .dark : .light

        // Ausdrücklich **beide** Zustände, nicht nur „verstecken, wenn
        // ausgeblendet". Sonst hinge die Leiste in einem Zustand fest, den
        // jemand anders gesetzt hat, und niemand bräuchte sie wieder
        // einzuschalten.
        tabBar.isHidden = chromeHidden || !AppStore.hasCredentials
    }

    // MARK: - Wie viel die Leiste überdeckt

    /// Wie viele Punkte am unteren Rand die Leiste verdeckt – **gemessen**, nicht
    /// angenommen.
    ///
    /// ## Warum gemessen und nicht gerechnet
    ///
    /// Das Verhalten von `UITabBarController` unterscheidet sich je iOS-Version.
    /// Früher legte das System die Leiste **unter** den Inhalt und kürzte den
    /// Bildschirm darüber; der Bildschirm endete dann genau über der Leiste, und
    /// es gab nichts zu überdecken. Neuere Systeme lassen die Leiste über dem
    /// Inhalt schweben, und der Inhalt reicht bis zum unteren Bildschirmrand.
    ///
    /// Eine Zahl im Quelltext – „die Leiste ist 49 Punkte hoch" – wäre damit
    /// entweder zu klein (ein Stück Content bliebe verdeckt) oder zu gross (ein
    /// Loch stünde darunter). Gemessen stimmt beides nicht: Es ist genau der
    /// Abstand, um den der Inhalt wirklich zu kurz ist.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        meldeUeberdeckung()
    }

    /// Berechnet den verdeckten Streifen und sagt ihn allen Ansichten.
    private func meldeUeberdeckung() {
        guard !tabBar.isHidden, !view.bounds.isEmpty else { return }

        // Der obere Rand der Leiste, bezogen auf **diesen** Bildschirm. Liegt
        // die Leiste ausserhalb (etwa weil sie gerade weganimiert wird), ergibt
        // das einen Unsinn – deshalb wird das abgefangen.
        let leistenOberrand = tabBar.frame.minY
        guard leistenOberrand > 0, leistenOberrand < view.bounds.height else {
            return
        }

        let ueberdeckt = view.bounds.height - leistenOberrand
        // Der sichere Bereich kommt mit: Ist die Leiste unterhalb des Inhalts,
        // ist der Streifen zwar leer, aber das Gerät hat unten einen Bereich,
        // in den der Inhalt nicht hineinreichen soll.
        let gebraucht = max(ueberdeckt, view.safeAreaInsets.bottom)

        NativeShellBridge.setzeUeberdeckung(gebraucht)
    }

    @objc private func settingsDidChange() {
        bauen()
        farbenSetzen()
    }

    // ------------------------------------------------------------ von Flutter

    /// Wird von `NativeShellBridge` gerufen, wenn Flutter etwas geändert hat.
    func settingsGeaendertInFlutter() {
        bauen()
        farbenSetzen()
    }

    /// Blendet die Leiste aus – für die Einführung und die Anmeldung.
    ///
    /// Die beiden Bildschirme stehen **über** allem. Eine halb sichtbare Leiste
    /// unter ihnen sähe aus wie ein Fehler, und sie würde den Daumen auf
    /// Einträge führen, hinter denen gerade nichts liegt.
    func setzeChromeSichtbar(_ sichtbar: Bool) {
        chromeHidden = !sichtbar
        farbenSetzen()
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        farbenSetzen()
    }
}

extension RootTabBarController: UITabBarControllerDelegate {
    func tabBarController(
        _ tabBarController: UITabBarController, shouldSelect viewController: UIViewController
    ) -> Bool {
        // Die Leiste ist ein Ziel für den Daumen, kein Umschalter. Wer einen
        // Eintrag antippt, der schon offen ist, erwartet, dass er wieder
        // obenauf kommt – das ist die einzige Bewegung, die die Leiste sonst
        // noch machen soll.
        if viewController === tabBarController.selectedViewController,
           let nav = viewController as? UINavigationController,
           nav.viewControllers.count > 1
        {
            nav.popToRootViewController(animated: true)
            return false
        }
        return true
    }
}

/// Ein Flutter-Abschnitt: ein `FlutterViewController` als Wurzel.
///
/// Die Ansicht wird **nicht** sofort gebaut. Sie entsteht erst, wenn der
/// Abschnitt zum ersten Mal aufgerufen wird – vorher wäre eine Dart-Isolate da,
/// die niemand sieht, und die Zeit, bis der erste Plan erscheint, wäre um die
/// Zeit für **alle drei** Abschnitte länger.
class PlanSectionController: UIViewController {
    private let engines: FlutterEngineGroup
    private var flutterViewController: FlutterViewController?
    private var role = "plan"

    init(engines: FlutterEngineGroup) {
        self.engines = engines
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    /// Wird von [RootTabBarController] aufgerufen, wenn der Abschnitt gebaut
    /// wird.
    func einrichten(role: String) {
        self.role = role
        title = titleForSection()
    }

    override func loadView() {
        // Wird erst hier aufgerufen – beim ersten Erscheinen.
        let options = FlutterEngineGroupOptions()
        options.entrypoint = "main"
        // Der Abschnitt kommt als Argument hinein, damit die Dart-Seite vor dem
        // ersten Frame weiß, was sie zeigen soll. Siehe `NativeShell.readRole`.
        options.entrypointArgs = ["--substitute-role=\(role)"]
        options.initialRoute = "/abschnitt/\(role)"

        let engine = engines.makeEngine(with: options)
        FlutterEngines.registerPlugins(on: engine)

        let controller = FlutterViewController(
            engine: engine, nibName: nil, bundle: nil)
        // `opaque` an `true`: Flutter zeichnet in der Regel sein eigenes
        // Rechteck voll, und ohne das bliebe beim Wischen zwischen den
        // Abschnitten kurz der Bildschirm dahinter durchscheinen.
        controller.view.backgroundColor = Appearance.background

        NativeShellBridge.register(on: engine)

        // Die Flutter-View gehört dem `FlutterViewController`. Sie darf nicht
        // zugleich die Root-View dieses Controllers sein: UIKit bricht dann
        // beim ersten Anzeigen mit einer Ausnahme ab ("A view can only be
        // associated with at most one view controller at a time").
        //
        // Deshalb bekommt dieser Tab eine eigene Host-View und nimmt Flutter
        // als Kind auf. So werden die View-Controller-Lebenszyklen auch
        // korrekt an Flutter weitergegeben.
        let hostView = UIView()
        hostView.backgroundColor = Appearance.background
        view = hostView

        addChild(controller)
        let flutterView = controller.view!
        flutterView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(flutterView)
        NSLayoutConstraint.activate([
            flutterView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            flutterView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            flutterView.topAnchor.constraint(equalTo: hostView.topAnchor),
            flutterView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
        ])
        controller.didMove(toParent: self)
        flutterViewController = controller
    }

    private func titleForSection() -> String? {
        switch role {
        case "plan": return L.vplanStudents
        case "search": return L.search
        case "sync": return L.syncShare
        default: return nil
        }
    }
}

/// Das Anmelden der Zusatzprogramme an eine **eigene** Maschine.
///
/// ## Warum das überhaupt nötig ist
///
/// `GeneratedPluginRegistrant.register(with:)` im `AppDelegate` meldet die
/// Programme nur der Maschine an, die iOS **von selbst** angelegt hat – der
/// einen, die aus `Main.storyboard` herausläuft.
///
/// Jede Maschine, die hier von Hand entsteht, ist eine andere. Ohne dieses
/// Anmelden hätte sie **kein** Programm:
///
/// * `shared_preferences` – und damit **keinen** Speicher: Es gäbe weder die
///   Pläne noch die Zugangsdaten noch das Theme, und die App käme frisch
///   installiert daher.
/// * `url_launcher` – die Links aus dem Info-Dialog.
/// * `package_info_plus`, `share_plus`, `mobile_scanner`, `file_picker`.
///
/// Der Fehler fiele also nicht beim Start auf, sondern später, an
/// irgendeiner Stelle, die mit dem fehlenden Programm nichts zu tun hat.
///
/// Deshalb steht es an **einer** Stelle und wird von jedem Weg aus aufgerufen,
/// der eine Maschine anlegt – und es steht in derselben Datei wie die
/// Maschinen, damit man es beim Suchen danach findet.
enum FlutterEngines {
    static func registerPlugins(on engine: FlutterEngine) {
        GeneratedPluginRegistrant.register(with: engine)
    }
}

/// Der Abschnitt „Mehr“: der Werkzeugkasten.
///
/// Hier stehen die Dinge, die man **nicht** jeden Tag braucht – und die drei
/// Bildschirme, die auf iOS jetzt **nativ** sind. Sie stehen deshalb hier und
/// nicht in Flutter: Sie sind reine Einstellungen, sie brauchen keine
/// Dart-Isolate, und sie sehen dadurch aus wie die übrigen Apps auf dem Gerät.
class MoreSectionController: UIViewController {
    private var navigation: UINavigationController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.background

        let liste = MoreScreen()
        navigation = UINavigationController(rootViewController: liste)
        // Grosse Titel: Sie sind der Grund, warum die Leiste in iOS wie in iOS
        // aussieht.
        navigation.navigationBar.prefersLargeTitles = true
        navigation.navigationBar.tintColor = Appearance.accent

        addChild(navigation)
        view.addSubview(navigation.view)
        navigation.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navigation.view.topAnchor.constraint(equalTo: view.topAnchor),
            navigation.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigation.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigation.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        navigation.didMove(toParent: self)
    }
}
