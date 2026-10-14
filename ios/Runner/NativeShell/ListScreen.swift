import UIKit

/// Eine Zeile in einer Liste mit Abschnitten.
///
/// Nachgebaut nach dem, was iOS unter „eingetragene Ansicht" versteht: eine
/// Liste in abgerundeten Gruppen, in der das Aussehen einer Zeile den Rand
/// andeutet und zwischen den Zeilen **keine** Linie läuft.
///
/// ## Warum eine eigene Art und nicht `UITableView.Style.insetGrouped`
///
/// Der Stil bringt das Aussehen. Die Zeilen, die er zeigen soll, bringt er
/// nicht – und genau die sind hier das Interessante: Ein neuer Bildschirm ist
/// eine Liste von Werten und sonst nichts, statt eines Haufens von
/// `UITableViewCell`-Aufbau.
enum Row {
    /// Eine Zeile, die beim Tippen etwas tut.
    ///
    /// `accessory` entscheidet, was am rechten Rand steht: iOS setzt einen
    /// Haken neben einen gewählten Wert und einen Pfeil neben etwas, das
    /// weiterführt. Der Unterschied ist keine Dekoration, sondern der einzige
    /// Hinweis **vor** dem Tippen darauf, ob man etwas auswählt oder
    /// irgendwohin geht.
    case choice(
        title: String,
        subtitle: String?,
        symbol: String,
        accessory: Accessory,
        destructive: Bool,
        action: () -> Void)

    /// Eine Zeile mit einem Schalter.
    ///
    /// Der Wert wird hier **nicht** gemerkt. Wer den Bildschirm baut, gibt ihn
    /// bei jedem Aufbau mit, und der Schalter schreibt ihn – so kann die Zeile
    /// gar nichts anderes anzeigen, als gespeichert ist.
    ///
    /// Der Fall heißt `toggleRow` und nicht `toggle`, weil es unterhalb schon
    /// eine gleichnamige [Row.toggle]-Funktion gibt: Zwei Dinge mit derselben
    /// Signatur an einem Ort lässt Swift nicht zu – und die Funktion ist die,
    /// die man aufrufen will, weil sie die Vorgaben mitbringt.
    case toggleRow(
        title: String,
        subtitle: String?,
        symbol: String,
        value: Bool,
        action: (Bool) -> Void)

    /// Eine Wahl aus mehreren Werten – als **Aufklappmenü**.
    ///
    /// ## Warum ein Menü und keine Kacheln nebeneinander
    ///
    /// Beides ist „wähle eins von mehreren". Der Unterschied ist, was man
    /// **vorher** sieht:
    ///
    /// * Kacheln nebeneinander zeigen **alle** Möglichkeiten auf einen Blick.
    ///   Das ist gut bei zwei kurzen Werten – und schlecht, sobald eine dritte
    ///   Möglichkeit dazukommt: Sie passt nicht mehr daneben, sie rutscht in
    ///   die nächste Zeile und macht aus einer Zeile zwei.
    /// * Ein Menü zeigt **nur** das Gewählte, rechts daneben, mit einem kleinen
    ///   Doppelpfeil. Der Platz reicht immer, und die Zeile bleibt eine Zeile –
    ///   egal ob zwei oder fünf Möglichkeiten dahinterstecken.
    ///
    /// Der Wert steht **rechts** in der Zeile, nicht in der Erklärung darunter:
    /// Er ist das, woran man merkt, was gerade gilt.
    case menuRow(
        title: String,
        subtitle: String?,
        symbol: String,
        options: [MenuOption])

    /// Eine Zeile, die nichts tut, sondern nur einen Text zeigt.
    case textRow(title: String, subtitle: String?, symbol: String)

    /// Eine Zeile, die schon auf sich selbst aufmerksam macht.
    ///
    /// Bei einem Fehler, einer Warnung oder einem leeren Zustand: Nur diese
    /// eine Zeile wird rot, nicht der ganze Bildschirm.
    case warning(title: String, subtitle: String?, symbol: String)

    enum Accessory {
        case none
        case disclosure
        case checkmark
    }
}

// Swift erlaubt in einem `case` **keine** Vorgabewerte – anders als in einer
// Funktion. Damit die Aufrufe trotzdem kurz bleiben, stehen hier die Wege, die
// fast jeder Bildschirm braucht. Die Vorgaben liegen damit an **einer** Stelle
// statt an fünf.
extension Row {
    /// Eine Zeile, die weiterführt.
    static func choice(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        action: @escaping () -> Void
    ) -> Row {
        .choice(
            title: title, subtitle: subtitle, symbol: symbol,
            accessory: .disclosure, destructive: false, action: action)
    }

    /// Eine Zeile, die einen gewählten Wert zeigt **und** beim Tippen etwas tut.
    ///
    /// Das ist der Fall bei der Sprache: Die Zeile zeigt den Haken und stellt
    /// die Sprache um.
    static func choice(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        accessory: Accessory,
        action: @escaping () -> Void
    ) -> Row {
        .choice(
            title: title, subtitle: subtitle, symbol: symbol,
            accessory: accessory, destructive: false, action: action)
    }

    /// Eine Zeile, die einen gewählten Wert zeigt, ohne etwas zu tun.
    static func choice(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        accessory: Accessory
    ) -> Row {
        .choice(
            title: title, subtitle: subtitle, symbol: symbol,
            accessory: accessory, destructive: false, action: {})
    }

    /// Eine Zeile, die etwas unwiederbringlich wegnimmt.
    ///
    /// Rot, weil sie es ankündigt – die Farbe ist hier nicht Auslegung,
    /// sondern die Warnung selbst.
    static func destructive(
        title: String, symbol: String, action: @escaping () -> Void
    ) -> Row {
        .choice(
            title: title, subtitle: nil, symbol: symbol,
            accessory: .none, destructive: true, action: action)
    }

    /// Eine Zeile, die etwas unwiederbringlich wegnimmt – **mit** Erklärung.
    ///
    /// Ohne `subtitle` bewusst ohne Vorgabewert: Eine Vorgabe machte beide
    /// Aufrufe gleich gut passend, und Swift könnte beim Aufruf mit drei
    /// Argumenten nicht mehr sagen, welche der beiden gemeint war.
    static func destructive(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> Row {
        .choice(
            title: title, subtitle: subtitle, symbol: symbol,
            accessory: .none, destructive: true, action: action)
    }

    /// Eine Zeile mit Schalter und Erklärung.
    static func toggle(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        value: Bool,
        action: @escaping (Bool) -> Void
    ) -> Row {
        .toggleRow(
            title: title, subtitle: subtitle, symbol: symbol,
            value: value, action: action)
    }

    /// Eine Auswahl aus zwei oder mehr Möglichkeiten – als Aufklappmenü.
    ///
    /// Die Zeile selbst zeigt den **gewählten** Wert rechts; sie braucht deshalb
    /// keine Erklärung darüber, was gerade gilt. Wer trotzdem einen Hinweis
    /// möchte, gibt ihn als `subtitle` mit – der steht dann **unter** dem Titel,
    /// wie bei jeder anderen Zeile.
    static func menu(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        options: [MenuOption]
    ) -> Row {
        .menuRow(
            title: title, subtitle: subtitle, symbol: symbol,
            options: options)
    }

    /// Ein Text, der nur dasteht.
    static func text(title: String, subtitle: String? = nil, symbol: String)
        -> Row
    {
        .textRow(title: title, subtitle: subtitle, symbol: symbol)
    }
}

/// Ein Angebot in einer [Row.menuRow]-Zeile.
///
/// `isSelected` wird bei jedem Aufbau neu gesetzt – die Zelle merkt sich
/// nichts, sondern zeigt das, was der Bildschirm ihr gerade gegeben hat. So
/// kann die Zeile gar nichts anderes anzeigen, als gespeichert ist.
struct MenuOption {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void
}

/// Eine Gruppe von Zeilen, mit Überschrift und Fussnote.
///
/// Die Überschrift steht **oberhalb** und die Fussnote **unterhalb** der Gruppe
/// – so, wie iOS es macht. Beide sind optional, beide in kleinerer Schrift, und
/// beide lesen sich als Erklärung und nicht als Inhalt.
struct Section {
    let header: String?
    let footer: String?
    let rows: [Row]

    init(header: String? = nil, footer: String? = nil, rows: [Row]) {
        self.header = header
        self.footer = footer
        self.rows = rows
    }
}

/// Der Bildschirm, in dem eine Liste aus [Section]en steht.
///
/// Er weiss **wie** eine Zeile aussieht, aber nicht **was** in ihr steht. Das
/// kommt von aussen herein, und genau darin liegt der Wert: Ein neuer
/// Bildschirm ist eine Liste von Werten und sonst nichts.
///
/// ## Das Aussehen kommt nicht von hier
///
/// Die Zellen holen ihre Farben bei [Appearance], und der Bildschirm meldet
/// sich für Änderungen an. Wer die Farben hier festsetzen würde, hätte sie an
/// zwei Stellen – und beim Umstellen auf Hell stünde die eine noch auf der
/// anderen.
///
/// ## Die Abschnitte werden bei jedem Erscheinen neu gebaut
///
/// [neuLaden] liest [makeSections] erneut. Das ist wichtig, weil manche Zeilen
/// vom Speicher abhängen – die Zugangsdaten erscheinen erst mit dem ersten
/// Benutzernamen, und ein aktiver Schulbereich ist ein anderer nach dem
/// Wechseln.
class ListScreen: UIViewController {
    /// Die Abschnitte, aus denen gerade gebaut wird.
    private(set) var sections: [Section] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var appearanceToken: UUID?

    /// Ob dieser Bildschirm einen grossen Titel in der Leiste führen soll.
    ///
    /// Gespeichert und nicht nur einmal im `init` gesetzt, weil die Leiste
    /// erst beim **Erscheinen** Bescheid wissen darf – siehe [viewWillAppear].
    private let grosseTitel: Bool

    init(title: String, largeTitle: Bool = true) {
        self.grosseTitel = largeTitle
        super.init(nibName: nil, bundle: nil)
        self.title = title
        // Grosse Titel sind ein Teil davon, warum die Leiste in iOS wie in iOS
        // aussieht: Sie zeigen den Bildschirmnamen in der Schriftgrösse der
        // Überschrift und schrumpfen erst beim Scrollen darunter weg.
        navigationItem.largeTitleDisplayMode =
            largeTitle ? .always : .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    // -------------------------------------------------- von den Unterklassen

    /// Die Abschnitte dieses Bildschirms.
    ///
    /// Wird bei [neuLaden] gerufen, nicht einmal beim Aufbau – deshalb darf
    /// hier gelesen werden, ohne dass man sich sorgen muss, wann.
    func makeSections() -> [Section] { [] }

    /// Was beim Wischen nach links passiert.
    ///
    /// ## Warum ein **Haken** und nicht das Überschreiben der Methode
    ///
    /// Der naheliegende Weg wäre gewesen, in einer Unterklasse
    /// `tableView(_:trailingSwipeActionsConfigurationForRowAt:)` mit `override`
    /// zu überschreiben. Das lässt Swift **nicht** zu: Die Delegate-Methoden
    /// stehen in einer Erweiterung, und was dort steht, kann eine Unterklasse
    /// nicht überschreiben – der Compiler sagt „does not override any method
    /// from its superclass", und die Aktion fällt still weg.
    ///
    /// Deshalb geht der Weg über diese Methode: Sie steht im Klassenrumpf und
    /// ist damit ganz normal überschreibbar, und die Liste fragt sie nur ab.
    func swipeActions(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        nil
    }

    /// Liest die Abschnitte neu und baut die Liste neu auf.
    func neuLaden() {
        sections = makeSections()
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    /// Dürfen die Zeilen dieser Liste verschoben werden?
    ///
    /// ## Warum das eine **Frage** ist und kein Kennzeichen
    ///
    /// `UITableView` fragt bei **jeder** Zeile, ob sie sich verschieben lässt.
    /// Eine Liste, in der nichts zu verschieben ist, würde es sonst nur an einer
    /// Stelle sagen – am Bildschirm –, und die Liste selbst wüsste nichts davon.
    ///
    /// Voreingestellt ist `false`, weil fast alle Listen hier aus Zeilen bestehen,
    /// deren Reihenfolge **irrelevant** ist: Sprache, Schulen, Schalter.
    /// Verschieben ergibt dort nichts, und ein sichtbarer Ziehpfeil an einer
    /// Zeile, deren Platz beliebig ist, wäre eine Einladung zu etwas, das keinen
    /// Unterschied macht.
    var reihenfolgeMoeglich: Bool { false }

    /// Aufgerufen, wenn eine Zeile an eine neue Stelle gezogen wurde.
    ///
    /// ## Warum hier **nicht** die `UITableViewDataSource`-Methode überschrieben
    /// wird
    ///
    /// Siehe die ausführliche Begründung bei [swipeActions(at:)]: Die
    /// Delegate-Methoden stehen in einer Erweiterung, und was dort steht, kann
    /// eine Unterklasse nicht überschreiben.
    func zeileVerschoben(von quelle: IndexPath, nach ziel: IndexPath) {}

    /// Schaltet den Bearbeitungsmodus um und hält den Knopf daneben aktuell.
    ///
    /// Der Knopf ist deshalb hier und nicht in jeder Liste: Er ist immer
    /// derselbe, und der Begleittext („Bearbeiten"/„Fertig") ändert sich mit dem
    /// Zustand. Zwei Stellen, an denen die Beschriftung festgeschrieben wird,
    /// wären zwei Stellen, an denen sie auseinanderlaufen könnten.
    func setzeBearbeitungsmodus(_ an: Bool) {
        bearbeitet = an
        liste.setEditing(an, animated: true)
        bearbeitungsknopfAktualisieren()
    }

    private var bearbeitet = false

    private var bearbeitungsknopf: UIBarButtonItem?

    /// Legt den Bearbeitungsknopf rechts oben an.
    ///
    /// Ein Bildschirm, der dort schon etwas hat – etwa „Hinzufügen" bei den
    /// Schulen –, verliert es dadurch nicht: Bestehende Knöpfe bleiben stehen,
    /// der neue kommt dazu. Ohne diese Trennung müsste sich jeder Bildschirm
    /// selbst entscheiden, welcher von beiden wichtiger ist, und diese
    /// Entscheidung fiele überall anders aus.
    func zeigeBearbeitungsknopf() {
        let knopf = UIBarButtonItem(
            title: bearbeitet ? L.done : L.edit,
            style: .plain,
            target: self,
            action: #selector(bearbeitungsumschalten))
        bearbeitungsknopf = knopf

        var vorhanden = navigationItem.rightBarButtonItems ?? []
        // Ein zweiter Aufruf soll den Knopf nicht verdoppeln.
        vorhanden.removeAll { $0 === bearbeitungsknopf }
        vorhanden.append(knopf)
        navigationItem.rightBarButtonItems = vorhanden
    }

    @objc private func bearbeitungsumschalten() {
        setzeBearbeitungsmodus(!bearbeitet)
    }

    private func bearbeitungsknopfAktualisieren() {
        bearbeitungsknopf?.title = bearbeitet ? L.done : L.edit
    }

    // --------------------------------------------------------------- Aufbau

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.background

        tableView.backgroundColor = .clear
        // Zwischen den Zeilen einer Gruppe läuft in iOS **keine** Linie; die
        // Gruppen selbst sind es, die den Abschnitt teilen.
        tableView.separatorStyle = .none
        // Die Zeilenhöhe folgt dem Text – siehe [heightForRowAt].
        //
        // Der Schätzwert ist nicht Kosmetik: Er ist der Wert, mit dem die Liste
        // beim Scrollen rechnet. Ohne ihn wüsste sie nicht, wo die nächste
        // Zeile steht, und würde beim Scrollen springen.
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.reuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Wer die Einstellung ändert, muss es auch gesagt bekommen – sonst
        // stünde hier die alte Helligkeit, während der Bildschirm daneben
        // schon die neue zeigt.
        appearanceToken = AppearanceObserver.observe { [weak self] in
            self?.farbenSetzen()
        }

        neuLaden()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setzeGrosseTitel()
        farbenSetzen()
        // Beim Zurückkommen kann sich der Speicher geändert haben.
        neuLaden()
    }

    /// Stellt die Leiste auf die Art von Titel ein, die dieser Bildschirm will.
    ///
    /// ## Warum das hier und nicht nur im `init` steht
    ///
    /// `largeTitleDisplayMode = .never` lässt nur den **Text** verschwinden,
    /// nicht den **Platz**. Solange `UINavigationBar.prefersLargeTitles` an
    /// ist, hält die Leiste die volle Höhe eines grossen Titels bereit – man
    /// sieht eine leere Fläche, und die erste Zeile rutscht darunter weg. Genau
    /// das ist beim Werkzeugkasten passiert: Die Überschrift „Dashboard“ wurde
    /// entfernt, und der leere Platz, den sie innehatte, blieb.
    ///
    /// Der Platz hängt aber an der Leiste und nicht am Bildschirm, also muss
    /// **die Leiste** umgestellt werden – und die ist an die ganze Bildschirmreihe
    /// gegeben. Deshalb wird hier beides getan: Der Bildschirm sagt, was er
    /// braucht, und die Bildschirmreihe folgt ihm.
    ///
    /// ## Warum beim Erscheinen und nicht beim Aufbau
    ///
    /// Beim Aufbau existiert die Bildschirmreihe noch gar nicht sicher – und
    /// beim Zurückkommen vom Bildschirm darunter wäre der Zustand vom Weggehen
    /// wieder da. `viewWillAppear` läuft in beiden Fällen.
    private func setzeGrosseTitel() {
        navigationController?.navigationBar.prefersLargeTitles = grosseTitel
    }

    deinit {
        if let token = appearanceToken {
            AppearanceObserver.removeObserver(token)
        }
    }

    /// Trägt die gewählte Helligkeit auf den Bildschirm.
    ///
    /// Nur auf Leiste und Liste, **nicht** auf den ganzen Bildschirm: Die
    /// Abschnitte tragen ihr Bild selbst, und würde man ihnen das hier
    /// aufzwingen, sähe man beim Umschalten kurz das falsche.
    private func farbenSetzen() {
        view.backgroundColor = Appearance.background
        tableView.reloadData()
        navigationController?.navigationBar.tintColor = Appearance.accent
    }

    /// Die Liste – für Unterklassen, die sie anfassen wollen.
    var liste: UITableView { tableView }
}

// MARK: - Die Zellen

/// Die Zelle für alle Zeilen mit Text.
///
/// ## Warum eine eigene Art
///
/// `UITableViewCell` kennt zwei Stile, und nur einer davon hat überhaupt ein
/// Feld für einen zweiten Satz: `.default` hat keins. Mit dem Standardstil
/// erschiene also **kein** Untertitel – die Zeile wäre da, aber halb, und das
/// sieht man erst auf dem Gerät.
///
/// Der Stil wird deshalb hier einmal festgelegt, statt ihn in jedem Bildschirm
/// zu wiederholen – aber die **Felder** ersetzt sie durch eigene, siehe
/// [aufbauen()].
final class SubtitleCell: UITableViewCell {
    static let reuseId = "SubtitleCell"

    /// Der Text links neben dem Symbol.
    private let beschriftung = UILabel()

    /// Die Erklärung darunter.
    private let erklaerung = UILabel()

    /// Das Symbol links.
    private let symbolView = UIImageView()

    /// Hält Symbol und Text in einer Zeile nebeneinander.
    private let zeile = UIStackView()

    /// Hält Symbol, Titel und Erklärung untereinander.
    private let spalte = UIStackView()

    /// Das Zubehör am rechten Rand – Schalter, Haken oder Pfeil.
    private let zubehoerBehaelter = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        aufbauen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    /// Baut das Layout auf.
    ///
    /// ## Warum nicht die eingebauten `textLabel`/`detailTextLabel`
    ///
    /// Weil deren Layout eine **feste** Höhe vorsieht. Beide Labels bekommen
    /// dort nur eine feste Zahl Zeilen, und der Rest wird abgeschnitten – bei
    /// einer deutschen Erklärung wie „Blendet das Synchronisations-Menü in
    /// der Navigationsleiste am unteren Rand ein oder aus" läuft der Text
    /// dabei über den Rand der Zeile und über das Symbol hinweg.
    ///
    /// Mit dem eigenen Stapel entscheidet die Zeilenhöhe der Inhalt, und der
    /// Text hat so viele Zeilen, wie er braucht.
    ///
    /// `setContentHuggingPriority` ist dabei nicht Kosmetik: Ohne die niedrige
    /// Priorität würde der Stapel die Zelle über seine eigene Höhe hinaus
    /// dehnen wollen, und `UITableView` würde die berechnete Höhe verwerfen.
    ///
    /// ## Warum das Zubehör **im** Stapel steht und nicht in `accessoryView`
    ///
    /// `accessoryView` legt das System **über** den Inhalt der Zelle, und es
    /// rechnet den Platz beim eigenen Layout nicht mit: Ein Schalter am rechten
    /// Rand läge dann **auf** dem Text, sobald der Text breit genug ist. Aus
    /// demselben Grund hätte es auch die Haken und Pfeile verschluckt – das
    /// System zeichnet sie nur neben dem eingebauten Aufbau.
    private func aufbauen() {
        // Die eingebauten Felder werden **entfernt**, nicht auf `nil` gesetzt.
        //
        // `textLabel`, `detailTextLabel` und `imageView` sind auf
        // `UITableViewCell` nur lesbar – `textLabel = nil` ist kein
        // „Feld ausschalten", sondern ein Schreibversuch auf ein
        // schreibgeschütztes Feld, und der Compiler weist ihn ab.
        //
        // Weglassen dürfte man sie trotzdem nicht: Die Zelle legt sie beim
        // Aufbau selbst an, sie sind also sehr wohl da. Leer, ja – aber sie
        // **sind** da, und sie halten den eingebauten Aufbau am Leben, den wir
        // gar nicht benutzen. Sie zu entfernen ist deshalb nicht Kosmetik,
        // sondern die Voraussetzung dafür, dass unser Stapel allein die Höhe
        // der Zeile bestimmt.
        //
        // `accessoryView` und `accessoryType` **darf** man setzen – die sind
        // schreibbar. Sie werden auf „keins" gesetzt, damit das System keinen
        // Platz für sie reserviert: Unser Zubehör steckt im Stapel.
        contentView.subviews.forEach { $0.removeFromSuperview() }
        accessoryView = nil
        accessoryType = .none

        beschriftung.font = .preferredFont(forTextStyle: .body)
        beschriftung.adjustsFontForContentSizeCategory = true
        // Ohne das bricht der Text bei grosser Systemschrift mitten im Wort ab.
        beschriftung.lineBreakMode = .byWordWrapping
        // `numberOfLines = 0` ist hier **nicht** Kosmetik, sondern der ganze
        // Unterschied zwischen einer Zeile und einem Text, der aus dem
        // Bildschirmrand herausläuft.
        //
        // `UILabel` hat von sich aus genau **eine** Zeile. Mit
        // `lineBreakMode = .byWordWrapping` und einer Zeile malt das System den
        // Text nicht um – es malt ihn einzeilig **über den Rand hinaus**, ohne
        // Restzeichen. Man sieht das an einer langen Überschrift eines
        // Schalters: Der Schalter am rechten Rand wird weggeschoben und steht
        // draussen.
        //
        // Mit `0` bricht der Text an den Kanten des Stapels um, und die Zeile
        // wird – siehe `heightForRowAt` – so hoch, wie er es braucht.
        beschriftung.numberOfLines = 0

        erklaerung.font = .preferredFont(forTextStyle: .footnote)
        erklaerung.adjustsFontForContentSizeCategory = true
        erklaerung.lineBreakMode = .byWordWrapping
        erklaerung.numberOfLines = 0
        // Die Erklärung wird eher gestaucht als der Titel – der Titel ist das,
        // woran man den Eintrag überhaupt erkennt.
        erklaerung.setContentCompressionResistancePriority(
            .defaultLow, for: .horizontal)

        symbolView.contentMode = .scaleAspectFit
        symbolView.setContentHuggingPriority(
            .required, for: .horizontal)
        symbolView.setContentCompressionResistancePriority(
            .required, for: .horizontal)

        zubehoerBehaelter.axis = .horizontal
        zubehoerBehaelter.alignment = .center
        zubehoerBehaelter.spacing = 6
        zubehoerBehaelter.translatesAutoresizingMaskIntoConstraints = false

        zeile.axis = .horizontal
        zeile.alignment = .center
        zeile.spacing = 12
        zeile.translatesAutoresizingMaskIntoConstraints = false

        spalte.axis = .vertical
        spalte.alignment = .fill
        spalte.spacing = 2
        spalte.translatesAutoresizingMaskIntoConstraints = false
        // Der Text weicht dem Zubehör aus, und zwar **entschieden**: Ein Stapel,
        // der auf seine volle Wortbreite besteht, drängt Schalter, Haken und
        // Menü-Knopf aus der Zeile. Wer hier nachgibt, bestimmt die Breite der
        // ganzen Zeile.
        spalte.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spalte.setContentCompressionResistancePriority(
            .defaultLow, for: .horizontal)

        zeile.addArrangedSubview(symbolView)
        spalte.addArrangedSubview(beschriftung)
        spalte.addArrangedSubview(erklaerung)
        zeile.addArrangedSubview(spalte)
        // Das Zubehör ist ein **angeordnetes Feld**, nicht `accessoryView`.
        //
        // `accessoryView` legt das System über den Inhalt und rechnet den Platz
        // beim eigenen Layout nicht mit: Ein Schalter am rechten Rand läge dann
        // auf dem Text, sobald der Text breit genug ist. Im Stapel ist es statt
        // dessen ein Teil der Zeile – und der Text weicht ihm aus.
        zeile.addArrangedSubview(zubehoerBehaelter)

        contentView.addSubview(zeile)
        NSLayoutConstraint.activate([
            // Symbole 17 Punkte – so breit, wie der Stapel es vorgibt, und
            // nicht mehr: Die iOS-Vorgabe ist 20, was hier zu viel Luft lässt.
            symbolView.widthAnchor.constraint(equalToConstant: 22),

            zeile.topAnchor.constraint(
                equalTo: contentView.topAnchor, constant: 11),
            zeile.leadingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            zeile.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            zeile.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -11),
        ])
    }

    /// Trägt Text und Symbol ein, wie die gerade geltende Helligkeit es will.
    func setzeInhalt(
        titel: String,
        untertitel: String?,
        symbol: String,
        istGefaehrlich: Bool = false
    ) {
        beschriftung.text = titel
        beschriftung.textColor = istGefaehrlich ? .systemRed : .label

        let hatErklaerung = !(untertitel ?? "").isEmpty
        erklaerung.text = untertitel
        erklaerung.textColor = .secondaryLabel
        // Ein leeres, aber sichtbares Feld würde einen Absatz mit leerer Höhe
        // offenlassen – der Stapel zählt jedes angeordnete Feld.
        erklaerung.isHidden = !hatErklaerung

        symbolView.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 16, weight: .regular))
        symbolView.tintColor = istGefaehrlich ? .systemRed : .secondaryLabel

        // Die ganze Zeile sagt VoiceOver, was sie zeigt.
        accessibilityLabel = [titel, untertitel].compactMap { $0 }.joined(separator: ", ")
    }

    /// Setzt das Zubehör am rechten Rand.
    ///
    /// `nil` heisst: nichts. Der alte Zubehör wird jedes Mal entfernt – die
    /// Zelle wird über die Wiederverwendung mehrfach benutzt, und ohne das
    /// Entfernen stünde das Zubehör der vorigen Zeile noch daneben.
    func setzeZubehoer(_ neu: UIView?) {
        zubehoerBehaelter.arrangedSubviews.forEach {
            zubehoerBehaelter.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        if let neu {
            zubehoerBehaelter.addArrangedSubview(neu)
        }
    }

    /// Der Haken eines gewählten Wertes oder der Pfeil, der weiterführt.
    ///
    /// Als **eigene Symbole** statt als `accessoryType`, weil das System diese
    /// nur neben dem eingebauten Layout zeichnet – neben dem eigenen Stapel
    /// erschienen sie gar nicht, und die Zeile täte so, als gäbe es dort
    /// nichts zu wählen.
    static func symbolFuer(_ art: Row.Accessory) -> UIImageView? {
        let name: String
        switch art {
        case .none: return nil
        case .disclosure: name = "chevron.right"
        case .checkmark: name = "checkmark"
        }
        let view = UIImageView(image: UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 14, weight: .semibold)))
        view.tintColor = .tertiaryLabel
        // Darf weder gestaucht noch zusammengedrückt werden: Sonst verschwindet
        // der Haken genau dann, wenn die Zeile einmal breit wird.
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(
            .required, for: .horizontal)
        return view
    }
}

// MARK: - Die Liste

extension ListScreen: UITableViewDataSource, UITableViewDelegate {
    /// Die Aktionen beim Wischen – von der Oberklasse **umsetzbar**.
    ///
    /// Siehe [swipeActions(at:)].
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        swipeActions(at: indexPath)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
        -> Int
    {
        sections[section].rows.count
    }

    func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row {
        case let .menuRow(titel, untertitel, symbol, optionen):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol)
            // Die ganze Zeile wird nicht mehr zur Schaltflaeche: Das Menue
            // haengt am Knopf rechts, und zwei Ziele auf einer Zeile wuerden
            // bedeuten, dass die Zeile auf die Rander reagiert und der Knopf in
            // der Mitte – iOS hat beides nicht, und wer es trotzdem baut, merkt
            // es erst, wenn beim Tippen daneben sich nichts tut.
            cell.selectionStyle = .none
            cell.setzeZubehoer(menueKnopf(titel: titel, optionen: optionen))
            return cell

        case let .toggleRow(titel, untertitel, symbol, wert, aktion):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol)
            cell.selectionStyle = .none

            let schalter = UISwitch()
            schalter.isOn = wert
            // Der Absender einer `UIAction` ist die **Aktion**, nicht der
            // Schalter – `s.isOn` gibt es also nicht. Den Schalter hält der
            // Wurf ohnehin fest.
            //
            // `schalter` wird **schwach** gefangen: Der Schalter hält die
            // Aktion, die Aktion würde den Schalter halten – ein Kreis, der die
            // Zelle am Leben hält, obwohl sie längst aus der Liste ist.
            schalter.addAction(
                UIAction { [weak schalter] _ in
                    guard let schalter else { return }
                    aktion(schalter.isOn)
                },
                for: .valueChanged)
            cell.setzeZubehoer(schalter)
            return cell

        case let .textRow(titel, untertitel, symbol):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol)
            cell.selectionStyle = .none
            cell.setzeZubehoer(nil)
            return cell

        case let .warning(titel, untertitel, symbol):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol,
                istGefaehrlich: true)
            cell.selectionStyle = .none
            cell.setzeZubehoer(nil)
            return cell

        case let .choice(titel, untertitel, symbol, zubehoer, gefaehrlich, _):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol,
                istGefaehrlich: gefaehrlich)
            // Haken und Pfeil als eigene Symbole im Stapel – siehe
            // [SubtitleCell.symbolFuer(_:)]. Mit `accessoryType` erschienen sie
            // neben dem eigenen Aufbau gar nicht.
            cell.setzeZubehoer(
                SubtitleCell.symbolFuer(zubehoer))
            return cell
        }
    }

    /// Holt eine Zelle und macht sie bereit.
    ///
    /// Rückgabe ist bewusst [SubtitleCell] und nicht `UITableViewCell`: Alle
    /// Zeilen mit Text brauchen `setzeInhalt` und `setzeZubehoer`, und beide
    /// gibt es nur hier. Mit `UITableViewCell` als Typ müsste jeder Aufrufer
    /// erst fragen, ob es zufällig doch eine `SubtitleCell` ist – und ein
    /// stillschweigendes „nein" ergäbe eine leere Zeile statt eines Fehlers.
    /// Der Knopf für ein Aufklappmenü, fertig eingerichtet.
    ///
    /// ## Warum das kein `UIAction`-Knopf ist
    ///
    /// Ein gewöhnlicher Knopf schickt bei jedem Druck dieselbe Meldung. Ein Knopf
    /// mit `showsMenuAsPrimaryAction` öffnet bei jedem Druck **das Menü** – das
    /// ist der ganze Unterschied, und ohne die Zeile passiert beim Antippen
    /// schlicht nichts.
    ///
    /// ## Warum das Menü bei jedem Aufbau neu entsteht
    ///
    /// Es merkt sich den gewählten Eintrag nicht. Das ist Absicht: Der Haken
    /// steht dort, wo der Bildschirm – und damit [AppStore] – gerade sagt, was
    /// gespeichert ist. Ein Menü, das sich den alten Stand gemerkt hätte, zeigte
    /// nach dem Umstellen einen Haken an zwei Einträgen.
    ///
    /// Der Knopf kommt als **Zubehör** in [SubtitleCell.zubehoerBehaelter]:
    /// Titel und Erklärung stehen links, der Wert rechts, und der Knopf bekommt
    /// dort den Platz, den ein Schalter auch bekäme.
    private func menueKnopf(
        titel: String, optionen: [MenuOption]
    ) -> UIButton {
        let gewählt = optionen.first { $0.isSelected } ?? optionen.first

        let knopf = UIButton(type: .system)
        knopf.configuration = .plain()
        knopf.showsMenuAsPrimaryAction = true
        knopf.contentHorizontalAlignment = .trailing
        // Der Wert wird eher gestaucht als die Beschriftung links – sonst stünde
        // am Ende ein abgeschnittener Wert neben einem vollständigen Titel.
        knopf.setContentHuggingPriority(.required, for: .horizontal)
        knopf.setContentCompressionResistancePriority(
            .required, for: .horizontal)

        knopf.configuration?.title = gewählt?.title
        // Der Doppelpfeil ist das Einzige, was ein Aufklappmenü von einem
        // gewöhnlichen Knopf unterscheidet. Ohne ihn sieht die Zeile aus wie ein
        // Schalter, der sich nicht bewegen laesst.
        knopf.configuration?.image = UIImage(
            systemName: "chevron.up.chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 12, weight: .semibold))
        knopf.configuration?.imagePlacement = .trailing
        knopf.configuration?.imagePadding = 6
        knopf.configuration?.baseForegroundColor = Appearance.accent
        knopf.configuration?.contentInsets = NSDirectionalEdgeInsets(
            top: 4, leading: 8, bottom: 4, trailing: 0)

        // Der Haken sitzt am **gewählten** Eintrag – so wie in jedem Menü von
        // iOS.
        let aktionen = optionen.map { option -> UIAction in
            UIAction(
                title: option.title,
                image: UIImage(systemName: option.symbol),
                state: option.isSelected ? .on : .off) { _ in
                    // Der Wert wird **gespeichert** – das Wissen darum liegt beim
                    // Aufrufer, nicht hier.
                    option.action()
                }
        }
        knopf.menu = UIMenu(title: "", children: aktionen)

        // Für VoiceOver: Der sichtbare Titel sagt nicht, was gewählt ist.
        knopf.accessibilityLabel = [titel, gewählt?.title]
            .compactMap { $0 }
            .joined(separator: ", ")
        return knopf
    }

    private func dequeue(_ indexPath: IndexPath) -> SubtitleCell {
        let cell = liste.dequeueReusableCell(
            withIdentifier: SubtitleCell.reuseId, for: indexPath) as! SubtitleCell
        // Ohne `.clear` läge die Standardhinterlegung der Zelle **über** der
        // gesetzten Farbe, und die Zeile bliebe grau, egal was man einstellt.
        cell.backgroundColor = Appearance.surface
        cell.selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = Appearance.surface.withAlphaComponent(0.6)
            return view
        }()
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case let .choice(_, _, _, _, _, aktion): aktion()
        // Beim Schalter erledigt die Kachel das selbst – die ganze Zeile
        // tippen zu lassen wäre eine zweite, schlechtere Stelle dafür.
        case .toggleRow, .menuRow, .textRow, .warning: break
        }
    }

    /// Dürfen die Zeilen verschoben werden?
    ///
    /// Siehe [reihenfolgeMoeglich]: Die Frage steht am Bildschirm, die Liste
    /// fragt sie hier nur ab.
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        reihenfolgeMoeglich
    }

    /// Eine Zeile wurde verschoben.
    ///
    /// Der Bildschirm baut daraufhin seine eigene Liste neu auf – siehe
    /// [zeileVerschoben(von:nach:)].
    func tableView(
        _ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        zeileVerschoben(von: sourceIndexPath, nach: destinationIndexPath)
    }

    /// Lässt eine Zeile beim Ziehen ganz nach oben oder nach unten.
    ///
    /// Ohne das bleiben die erste und die letzte Zeile an ihrem Platz und lassen
    /// sich mit keiner der beiden Gruppen tauschen – man könnte sie also nicht
    /// an den Anfang oder ans Ende der Liste stellen, was bei den Stundenzeiten
    /// genau das ist, was man tun will.
    func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        let anzahl = sections[sourceIndexPath.section].rows.count
        guard anzahl > 0 else { return proposedDestinationIndexPath }

        let letzteZeile = IndexPath(
            row: anzahl - 1, section: proposedDestinationIndexPath.section)
        if proposedDestinationIndexPath.row >= anzahl { return letzteZeile }
        if proposedDestinationIndexPath.row < 0 {
            return IndexPath(row: 0, section: proposedDestinationIndexPath.section)
        }
        return proposedDestinationIndexPath
    }

    func tableView(
        _ tableView: UITableView, titleForHeaderInSection section: Int
    ) -> String? {
        sections[section].header
    }

    func tableView(
        _ tableView: UITableView, titleForFooterInSection section: Int
    ) -> String? {
        sections[section].footer
    }

    /// Wie hoch eine Zeile wird.
    ///
    /// ## Warum die Liste ihre Höhe **selbst** bestimmt
    ///
    /// Vorher standen hier feste Werte – 72 Punkte für eine Zeile mit
    /// Erklärung. Das ist bei knappen Texten in Ordnung und bei ausführlichen
    /// ein Fehler: „Blendet das Synchronisations-Menü in der Navigationsleiste
    /// am unteren Rand ein oder aus" braucht auf dem Telefon drei Zeilen, und in
    /// 72 Punkte passen zwei. Was nicht passt, wird nicht abgeschnitten, sondern
    /// **überlagert** – der Text läuft dann über den Rand der Zeile und über das
    /// Symbol hinweg, und die nächste Zeile fängt ihn ab.
    ///
    /// Eine feste Höhe kann das nicht lösen, weil sie der Textlänge nicht
    /// folgen kann. Sie müsste gross genug für den längsten Text sein – und
    /// dann wären alle anderen Zeilen auf einem iPhone wie riesige Leerflächen.
    ///
    /// Deshalb misst **jede** Zeile sich selbst: [UITableView.automaticDimension]
    /// lässt die Liste den Inhalt fragen. Auch die Menüzeile [Row.menuRow]
    /// misst sich – dort sind es zwei Knöpfe, und deren Höhe folgt dem Text in
    /// ihnen, nicht einer Zahl im Quelltext.
    ///
    /// [UITableView.estimatedRowHeight] ist dabei nicht ein tuning, sondern
    /// nötig: Ohne Schätzwert weiss die Liste beim Scrollen nicht, wo die
    /// nächste Zeile kommt, und würde springen.
    func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        switch sections[indexPath.section].rows[indexPath.row] {
        case .menuRow, .toggleRow, .choice, .textRow, .warning:
            // Alle Zeilen messen sich selbst – siehe die Beschreibung oben.
            // Eine eigene Höhe je Art gibt es hier bewusst nicht mehr: Jede
            // feste Zahl ist für **irgendeine** Sprache oder Schriftgrösse zu
            // klein, und was nicht passt, wird nicht abgeschnitten, sondern
            // überlagert.
            return UITableView.automaticDimension
        }
    }
}