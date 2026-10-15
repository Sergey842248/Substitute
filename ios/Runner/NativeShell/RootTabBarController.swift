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
    /// Die untere iPad-Leiste ist nicht die vom `UITabBarController`
    /// verwaltete Leiste. Ihr Delegate darf daher nicht der Controller selbst
    /// sein: UIKit verwendet dessen eigene Delegate-Implementierung intern
    /// für die Systemleiste. Ein getrenntes Objekt verhindert, dass ein Tap
    /// auf die Zusatzleiste die App mit einer inkonsistenten Tabbar beendet.
    private final class UntereTabLeistenDelegate: NSObject, UITabBarDelegate {
        weak var host: RootTabBarController?

        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            host?.unterenTabWaehlen(tabBar, item: item)
        }
    }

    // `FlutterEngineGroup` braucht einen Namen und das Projekt – die blosse
    // Initialisierung ist nicht zugelassen (`init NS_UNAVAILABLE`). Der Name
    // ist nur die Bezeichnung der gemeinsamen Gruppe; er erscheint nirgends.
    private let engines = FlutterEngineGroup(name: "substitute-shell", project: nil)
    private var controllers: [Tab] = []
    private var chromeHidden = false
    /// iPadOS legt die Tab-Leiste seit iPadOS 18 oberhalb des Inhalts ab –
    /// auch dann, wenn [mode] auf `.tabBar` steht. Die App braucht die
    /// Navigation jedoch wie auf dem iPhone am unteren Bildschirmrand. Daher
    /// bekommt das iPad eine eigene, native `UITabBar`, während der vom
    /// `UITabBarController` verwaltete Balken unsichtbar bleibt.
    private let untereTabLeiste = UITabBar()
    private let untereTabLeistenDelegate = UntereTabLeistenDelegate()
    /// Die Schule, die vor einer noch nicht eingerichteten Schule aktiv war.
    /// Beim Abbrechen der Anmeldung wird sie wiederhergestellt.
    private var schoolBeforeLogin: String?
    private var lastActiveSchoolId = AppStore.activeSchoolId

    /// Die Abschnitte der Leiste, in der Reihenfolge, in der sie stehen.
    ///
    /// Gelesen von der Reihenfolge hier und **nicht** umgekehrt: Die Reihenfolge
    /// ist eine Entscheidung der Oberfläche, und die Abschnitte wählen sich nicht
    /// gegenseitig aus.
    ///
    /// `Equatable` braucht es, weil [bauen] die alte Liste mit der gewünschten
    /// vergleicht, um zu erfahren, ob sich überhaupt etwas geändert hat – und
    /// einen **Schlüssel**, um den zuletzt gesehen Abschnitt wiederzufinden.
    private enum Tab: Hashable {
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

    /// Legt die Darstellung des vom System verwalteten Tab-Controllers fest.
    ///
    /// ## Warum das überhaupt festzulegen ist
    ///
    /// `UITabBarController` darf sich seine Form selbst wählen. Auf dem iPad
    /// verhindert `.tabBar` die Seitenspalte; die Position bleibt dennoch oben.
    /// Für die tatsächlich untere Leiste ist deshalb [untereTabLeiste] zuständig.
    ///
    /// Die Versionsprüfungen halten die App weiterhin mit iOS 15 kompatibel.
    ///
    /// Beide Werte gibt es erst ab iPadOS 18 bzw. 26. Die App baut aber bis
    /// iOS 15 – dort steht hinter der Prüfung nichts, und die Leiste bleibt so,
    /// wie sie auf diesen Geräten ohnehin aussieht: unten.
    private func stellungSetzen() {
        if #available(iOS 18.0, *) {
            mode = .tabBar
        }
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Appearance.background
        delegate = self

        stellungSetzen()
        untereLeisteEinrichten()

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

        // Die Schulen-Übersicht **öffnet** einen Bereich (siehe
        // [oeffneSchule]). Das ist etwas anderes als ein Wechsel – und wird
        // darum auch nicht über [AppStore.activeSchoolDidChange] gemeldet:
        // Ein Wechsel baut die Abschnitte neu auf, ein Öffnen will nur den
        // passenden Abschnitt zeigen.
        NotificationCenter.default.addObserver(
            self, selector: #selector(openSchool),
            name: AppStore.openSchoolRequested, object: nil)

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

        // Die Controller der weiterhin sichtbaren Tabs bleiben erhalten. Das
        // ist nicht nur schneller: Der Einstellungen-Stack im „Mehr"-Tab darf
        // nicht verschwinden, nur weil der Sync-Tab hinzugefügt oder entfernt
        // wird.
        let vorhandeneController = Dictionary(
            uniqueKeysWithValues: zip(controllers, viewControllers ?? []))
        var neuer: [UIViewController] = []
        var neuListe: [Tab] = []

        for section in gewuenscht {
            let controller = vorhandeneController[section] ?? neuerController(for: section)
            neuer.append(controller)
            neuListe.append(section)
        }

        controllers = neuListe
        setViewControllers(neuer, animated: false)
        untereTabLeiste.items = neuListe.enumerated().map { index, section in
            let item = untererTabBarEintrag(for: section)
            // `UITabBar` darf seine Einträge intern neu aufbauen. Der Tag
            // bleibt dabei der stabile Bezug zum gleichnamigen Controller.
            item.tag = index
            return item
        }

        // Der zuletzt gesehen Abschnitt wird wiederhergestellt, wenn er noch
        // da ist – sonst die erste Stelle.
        if let vorherAktiv,
           let index = neuListe.firstIndex(of: vorherAktiv)
        {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
        untereAuswahlAktualisieren()
    }

    /// Erzeugt nur Tabs, die vorher noch nicht Teil der Leiste waren.
    private func neuerController(for section: Tab) -> UIViewController {
        let controller: UIViewController
        switch section {
        case .plan, .search, .sync:
            let flutterSection = PlanSectionController(engines: engines)
            // Die Rolle muss vor dem ersten Flutter-Frame feststehen.
            flutterSection.einrichten(role: section.dartRole)
            controller = flutterSection
        case .more:
            controller = MoreSectionController()
        }
        controller.tabBarItem = tabBarItem(for: section)
        return controller
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
            // „Einstellungen“, nicht „Dashboard“: Der Reiter **ist** die Seite
            // mit den Einstellungen (siehe [MoreScreen]), und der Name im
            // Werkzeugkasten sagte nichts über das, was dort zu sehen ist.
            titel = L.settings
            symbol = "gearshape"
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

    /// Die iPad-Variante benutzt dieselben Symbole und zugänglichen Namen wie
    /// die Systemleiste, aber als eigenständige Leiste am unteren Rand.
    private func untererTabBarEintrag(for section: Tab) -> UITabBarItem {
        let item = tabBarItem(for: section)
        item.title = nil
        return item
    }

    private var benutztUntereTabLeiste: Bool {
        traitCollection.userInterfaceIdiom == .pad
    }

    private func untereLeisteEinrichten() {
        untereTabLeistenDelegate.host = self
        untereTabLeiste.delegate = untereTabLeistenDelegate
        untereTabLeiste.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(untereTabLeiste)

        let hoehe = untereTabLeiste.heightAnchor.constraint(equalToConstant: 49)
        NSLayoutConstraint.activate([
            untereTabLeiste.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            untereTabLeiste.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            untereTabLeiste.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            hoehe,
        ])
        untereTabLeiste.isHidden = !benutztUntereTabLeiste
    }

    private func untereAuswahlAktualisieren() {
        guard selectedIndex >= 0,
              selectedIndex < (untereTabLeiste.items?.count ?? 0)
        else { return }
        untereTabLeiste.selectedItem = untereTabLeiste.items?[selectedIndex]
    }

    //// Trägt die gewählte Helligkeit auf die Leiste.
    ///
    /// Nur die Leiste, nicht den ganzen Bildschirm: Die Abschnitte tragen ihr
    /// Bild selbst, und würde man ihnen das hier aufzwingen, sähe man beim
    /// Umschalten kurz das falsche.
    private func farbenSetzen() {
        tabBar.tintColor = Appearance.accent
        untereTabLeiste.tintColor = Appearance.accent
        view.backgroundColor = Appearance.background

        // Die Leiste ist die oberste Ebene direkt über dem Flutter-Inhalt.
        // Sie bekommt deshalb weder einen eigenen Hintergrund noch einen
        // Schatten oder einen Abstand zum unteren Rand. So bleiben Pläne,
        // Listen und Karten hinter ihr sichtbar statt durch eine zusätzliche
        // Fläche getrennt zu werden.
        //
        // Der Platz, in den man am Ende einer Liste scrollen kann, wird nicht
        // hier reserviert: Das erledigt der Abschluss der jeweiligen
        // Scroll-Ansicht auf der Dart-Seite. Ein globaler Innenabstand würde
        // nämlich auch dann als leere Fläche sichtbar, wenn man noch gar nicht
        // am Ende des Inhalts ist.
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        tabBar.isTranslucent = true
        untereTabLeiste.isTranslucent = true
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.backgroundColor = .clear
        untereTabLeiste.standardAppearance = appearance
        untereTabLeiste.scrollEdgeAppearance = appearance
        untereTabLeiste.backgroundColor = .clear

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
        let sichtbar = !chromeHidden && AppStore.hasCredentials
        // iPadOS platziert die vom Controller verwaltete Leiste grundsätzlich
        // oben. Sie darf dort nie Platz beanspruchen; die eigene Leiste liegt
        // stattdessen fest unten.
        if benutztUntereTabLeiste {
            // Das ist mehr als `tabBar.isHidden = true`: Der Controller gibt
            // seinen oberen Inhaltsbereich ebenfalls frei. Sonst bliebe nach
            // dem Ausblenden eine unsichtbare Safe-Area über der Appbar.
            if #available(iOS 18.0, *) {
                setTabBarHidden(true, animated: false)
            } else {
                tabBar.isHidden = true
            }
        } else {
            tabBar.isHidden = !sichtbar
        }
        untereTabLeiste.isHidden = !benutztUntereTabLeiste || !sichtbar
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
    ///
    /// ## Warum hier auch `0` gemeldet wird
    ///
    /// Früher stand hier ein `guard !tabBar.isHidden … else { return }`. Damit
    /// wurde bei ausgeblendeter Leiste **gar nichts** gesagt – und die Ansicht
    /// behielt den **letzten** Wert behalten. Wer die Leiste also verlor, sah
    /// weiterhin den Platz, den sie belegt hatte: ein Loch am unteren Rand, das
    /// niemand erklären konnte.
    ///
    /// Jetzt wird in jedem Fall gemeldet. `0` ist dabei nicht „nichts",
    /// sondern der **richtige** Wert: Es ist nichts verdeckt.
    private func meldeUeberdeckung() {
        guard !view.bounds.isEmpty else { return }

        // Ohne Leiste verdeckt sie nichts – und die Ansicht reicht dann bis zum
        // unteren Rand. `safeAreaInsets.bottom` greift trotzdem, weil der
        // Inhalt nicht in die Geste-Zone hineinreichen soll.
        let aktiveLeiste = benutztUntereTabLeiste ? untereTabLeiste : tabBar
        guard !aktiveLeiste.isHidden else {
            NativeShellBridge.setzeUeberdeckung(view.safeAreaInsets.bottom)
            return
        }

        // Der obere Rand der Leiste, bezogen auf **diesen** Bildschirm. Liegt
        // die Leiste ausserhalb (etwa weil sie gerade weganimiert wird), ergibt
        // das einen Unsinn – deshalb wird das abgefangen.
        //
        // Und ist sie gar nicht die untere, sondern etwa eine Seitenspalte, gilt
        // derselbe Satz: Eine schmale Spalte am Rand verdeckt nichts flächig am
        // unteren, und ihre Position erlaubt keine Rückschlüsse auf ihn. Nach
        // [stellungSetzen] kommt das nicht mehr vor – aber eine Zahl, die sich
        // aus einer fremden Form ergibt, wäre schlimmer als gar keine.
        let rahmen = aktiveLeiste.frame
        let istUnten =
            rahmen.width >= view.bounds.width / 2
            && rahmen.height > 0
            && rahmen.minY > 0
            && rahmen.minY < view.bounds.height
        guard istUnten else {
            NativeShellBridge.setzeUeberdeckung(view.safeAreaInsets.bottom)
            return
        }

        let ueberdeckt = view.bounds.height - rahmen.minY
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

    /// Aus der Schulen-Übersicht heraus: den aktiven Bereich öffnen.
    @objc private func openSchool() {
        oeffneSchule()
    }

    // ------------------------------------------------------------ von Flutter

    /// Wird von `NativeShellBridge` gerufen, wenn Flutter etwas geändert hat.
    func settingsGeaendertInFlutter() {
        // Wurden die Zugangsdaten gespeichert, ist die Anmeldung erfolgreich
        // abgeschlossen; ein späteres Zurück darf nicht in die alte Schule
        // springen.
        if AppStore.hasCredentials {
            schoolBeforeLogin = nil
            AppStore.clearLoginReturnSchool()
        }
        bauen()
        farbenSetzen()
    }

    /// Ein anderer Schulbereich wurde gewählt – in den Einstellungen.
    ///
    /// ## Was hier passiert und warum
    ///
    /// Ein Schulwechsel ist der eine Vorgang, bei dem sich **zwei** Dinge
    /// ändern: ob die Leiste überhaupt stehen darf (der neue Bereich kann
    /// Zugangsdaten haben oder keine) und welcher Abschnitt offen ist.
    ///
    /// Der zweite Teil ist der Grund, warum es diese Methode gibt und nicht bloß
    /// ein weiteres `farbenSetzen()`: Eine neu angelegte Schule hat **keine**
    /// Zugangsdaten, und eine bestehende, gerade nicht verwendete vielleicht
    /// auch nicht. In dem Fall wäre die Leiste fortan weg – und wer gerade in
    /// den Einstellungen steht, käme von dort nicht mehr heraus: Die Leiste ist
    /// der einzige Weg zu den Abschnitten, und in den Einstellungen gäbe es die
    /// Zeile „Zugangsdaten" gar nicht (sie hängt an denselben Zugangsdaten).
    ///
    /// Deshalb wird der Plan gezeigt, wenn die Leiste ausbleiben würde. Er ist
    /// der Abschnitt, der ohnehin die Anmeldung zeigt, und von dort aus kann man
    /// sich anmelden – worauf die Leiste wieder erscheint. Auf Android macht es
    /// dasselbe: Nach dem Anlegen einer Schule öffnet sich sofort die Anmeldung.
    func schuleGeaendert() {
        let activeSchoolId = AppStore.activeSchoolId
        if !AppStore.hasCredentials, activeSchoolId != lastActiveSchoolId {
            schoolBeforeLogin = lastActiveSchoolId
        }
        lastActiveSchoolId = activeSchoolId

        bauen()
        farbenSetzen()

        if !AppStore.hasCredentials {
            // Der Plan ist der erste Abschnitt der Leiste – er ist die einzige
            // Stelle, von der aus die Anmeldung zu erreichen ist, und er ist
            // immer gebaut (siehe [abschnitte]).
            //
            // Wichtig ist die Reihenfolge: Erst wird der Abschnitt sichtbar
            // (und seine Flutter-Maschine damit sicher eingerichtet), *dann*
            // wird der Schulwechsel an Flutter gemeldet. Sonst kann die
            // Meldung beim Anlegen einer Schule ins Leere gehen, wenn der
            // Plan-Abschnitt bisher noch nicht geladen war. Dann blieb die
            // alte Home-Ansicht stehen, bis ein App-Neustart den Speicher neu
            // gelesen hat.
            zeigePlan()
        }

        // Alle bereits bestehenden Flutter-Abschnitte müssen ihren Cache auf
        // den neuen Bereich umstellen. Noch nicht erzeugte Abschnitte lesen
        // den aktiven Bereich beim Start selbst.
        NativeShellBridge.activeSchoolChanged()
    }

    /// Öffnet den aktiven Schulbereich: den Plan, oder – bei einem Bereich ohne
    /// Zugangsdaten – dessen Anmeldung.
    ///
    /// Aufgerufen von der Schulen-Übersicht, wenn eine Schule geöffnet wird.
    /// Siehe [AppStore.openSchool].
    func oeffneSchule() {
        bauen()
        farbenSetzen()
        zeigePlan()
    }

    private func zeigePlan() {
        guard controllers.first == .plan else { return }

        // `selectedIndex` kann die View erst im nächsten UIKit-Durchlauf
        // laden. Der anschließende Kanalruf für den Schulwechsel hätte dann
        // noch keinen Empfänger. Das Laden hier ist absichtlich synchron.
        (viewControllers?.first as? PlanSectionController)?.loadViewIfNeeded()

        if selectedIndex != 0 {
            selectedIndex = 0
        }
        untereAuswahlAktualisieren()
    }

    /// Führt aus einem **Abschnitt** zurück in die Schulen-Übersicht.
    ///
    /// ## Warum das kein `popViewController` sein kann
    ///
    /// Die Schulen-Übersicht steht in der Bildschirmreihe des Abschnitts
    /// „Mehr“, der Plan in einem ganz anderen Stapel – der erste Abschnitt der
    /// Leiste hat gar keine Bildschirmreihe, sondern eine Flutter-Ansicht. Von
    /// dort aus gibt es kein Zurückgeben, das irgendwo ankäme.
    ///
    /// Deshalb wird der Abschnitt gewechselt und dort die Schulen-Übersicht
    /// erneut gezeigt. Liegt sie noch im Stapel, wird **nicht** neu gebaut: Man
    /// erwartet genau dieselbe Liste an derselben Stelle wieder, mit
    /// Markierung und Scrollstand.
    func zurueckInDieSchulen() {
        if let previousSchool = schoolBeforeLogin ?? AppStore.loginReturnSchoolId,
           previousSchool != AppStore.activeSchoolId
        {
            // Das Verlassen der Anmeldung verwirft nicht die zuvor benutzte
            // Schule. Sie hat Zugangsdaten und damit wieder eine sichtbare
            // Tab-Leiste; erst danach wird die Schulen-Liste gezeigt.
            schoolBeforeLogin = nil
            AppStore.clearLoginReturnSchool()
            AppStore.setActiveSchool(previousSchool)
            schuleGeaendert()
        } else {
            schoolBeforeLogin = nil
            AppStore.clearLoginReturnSchool()
        }

        guard let index = controllers.firstIndex(of: .more) else { return }
        // `controllers` und `viewControllers` werden in [bauen] immer
        // gemeinsam gesetzt – die Prüfung ist nur deshalb da, weil ein
        // Index-Zugriff sonst ein Absturz wäre statt einer ausgelassenen
        // Aktion.
        guard index < (viewControllers?.count ?? 0) else { return }
        guard let mehr = viewControllers?[index] as? MoreSectionController
        else { return }

        mehr.zeigeSchulen()
        selectedIndex = index
        untereAuswahlAktualisieren()
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

    private func unterenTabWaehlen(_ tabBar: UITabBar, item: UITabBarItem) {
        let index = item.tag
        guard tabBar === untereTabLeiste,
              index >= 0,
              index < (viewControllers?.count ?? 0),
              let controller = viewControllers?[index]
        else { return }

        // Dasselbe Verhalten wie bei der Systemleiste: Ein erneutes Antippen
        // des Einstellungen-Reiters führt in dessen Wurzel zurück.
        if index == selectedIndex,
           let navigation = controller as? UINavigationController,
           navigation.viewControllers.count > 1
        {
            navigation.popToRootViewController(animated: true)
            return
        }

        selectedIndex = index
        untereAuswahlAktualisieren()
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

    func tabBarController(
        _ tabBarController: UITabBarController, didSelect viewController: UIViewController
    ) {
        untereAuswahlAktualisieren()
    }
}

/// Ein Flutter-Abschnitt: ein `FlutterViewController` als Wurzel.
///
/// Die Ansicht wird **nicht** sofort gebaut. Sie entsteht erst, wenn der
/// Abschnitt zum ersten Mal aufgerufen wird – vorher wäre eine Dart-Isolate da,
/// die niemand sieht, und die Zeit, bis der erste Plan erscheint, wäre um die
/// Zeit für **alle drei** Abschnitte länger.
class PlanSectionController: UIViewController, UIGestureRecognizerDelegate {
    private let engines: FlutterEngineGroup
    private var flutterViewController: FlutterViewController?
    private var role = "plan"
    private lazy var schoolLoginBackGesture: UIScreenEdgePanGestureRecognizer = {
        let gesture = UIScreenEdgePanGestureRecognizer(
            target: self, action: #selector(handleSchoolLoginBackGesture(_:)))
        gesture.edges = .left
        gesture.delegate = self
        return gesture
    }()

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
        // Die Anmeldung einer zusätzlich angelegten Schule ist die Wurzel
        // dieses Flutter-Abschnitts. Es gibt dort keine Flutter-Route, die
        // eine interaktive iOS-Zurück-Geste auslösen könnte. Die echte
        // Bildschirmrand-Geste führt deshalb denselben nativen Rückweg aus
        // wie der sichtbare Zurück-Pfeil.
        hostView.addGestureRecognizer(schoolLoginBackGesture)

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

    @objc private func handleSchoolLoginBackGesture(
        _ gesture: UIScreenEdgePanGestureRecognizer
    ) {
        guard role == "plan",
              AppStore.activeSchoolId != "default",
              !AppStore.hasCredentials,
              gesture.state == .ended
        else { return }

        let translation = gesture.translation(in: view).x
        let velocity = gesture.velocity(in: view).x
        // Nicht jede Berührung am Rand ist ein Zurückgehen. Die Schwelle
        // entspricht der Erwartung an eine absichtliche iOS-Wischgeste.
        guard translation > 60 || velocity > 500 else { return }
        (tabBarController as? RootTabBarController)?.zurueckInDieSchulen()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer)
        -> Bool
    {
        // Außerhalb der Anmeldung darf der Erkenner nicht einmal anfangen:
        // Sonst würde er horizontale Flutter-Gesten im Plan unnötig
        // unterbrechen, obwohl er am Ende ohnehin nichts tun dürfte.
        guard gestureRecognizer === schoolLoginBackGesture,
              role == "plan",
              AppStore.activeSchoolId != "default",
              !AppStore.hasCredentials,
              let edgeGesture = gestureRecognizer as? UIScreenEdgePanGestureRecognizer
        else { return false }

        let velocity = edgeGesture.velocity(in: view)
        return velocity.x > 0 && abs(velocity.x) > abs(velocity.y)
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

    /// Zeigt die Schulen-Übersicht – und zwar die **gleiche**, von der aus man
    /// zuletzt wegging.
    ///
    /// Liegt sie noch im Stapel, wird nur zu ihr zurückgegangen: Sie zu ersetzen
    /// würde die Liste neu aufbauen und Scrollstand und Markierung wegwerfen,
    /// obwohl sich an ihr nichts geändert hat.
    ///
    /// Andernfalls wird sie **ohne Animation** aufgesetzt. Sie kam aus einem
    /// anderen Abschnitt, in dem sie nie stand – es gibt keine Bewegung, von der
    /// aus man dorthin zurückfahren könnte, und eine erfundene Übergangsbewegung
    /// wäre eine Behauptung, die nicht dem entspricht, was man gedrückt hat.
    func zeigeSchulen() {
        // Die Bildschirmreihe entsteht erst in [viewDidLoad]. Solange dieser
        // Abschnitt noch nie sichtbar war, ist sie noch nicht da – und genau
        // das ist hier der Normalfall: Man kommt aus dem Plan, in dem „Mehr“
        // unter Umständen noch gar nicht aufgebaut wurde.
        loadViewIfNeeded()
        guard let nav = navigation else { return }

        if let vorhanden = nav.viewControllers.first(where: { $0 is SchoolsScreen }) {
            nav.popToViewController(vorhanden, animated: true)
        } else {
            nav.popToRootViewController(animated: false)
            nav.pushViewController(SchoolsScreen(), animated: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.background

        let liste = MoreScreen()
        navigation = UINavigationController(rootViewController: liste)
        // Grosse Titel: Sie sind der Grund, warum die Leiste in iOS wie in iOS
        // aussieht. Jeder Bildschirm dieser Reihe traegt seinen Namen als
        // solchen – auch der Werkzeugkasten (siehe [MoreScreen]).
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
