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

    /// Ein Wechsel **zwischen** Werten, wie bei hell und dunkel.
    ///
    /// Als nebeneinanderliegende Auswahlflächen gebaut und nicht als Schalter:
    /// Es sind gleichwertige Möglichkeiten, und ein Schalter müsste durch
    /// seinen Zustand sagen, was beim Umstellen passiert. Die Flächen zeigen
    /// beide, und die gewählte ist gefüllt.
    case segmentRow(
        title: String,
        subtitle: String?,
        symbol: String,
        options: [SegmentOption])

    /// Eine Zeile, die nichts tut, sondern nur einen Text zeigt.
    case textRow(title: String, subtitle: String?, symbol: String)

    /// Eine Zeile, die schon auf sich selbst aufmerksam macht.
    ///
    /// Bei einem Fehler, einer Warnung oder einem leeren Zustand: Nur diese
    /// eine Zeile wird rot, nicht der ganze Bildschirm.
    case warning(title: String, subtitle: String?, symbol: String)

    /// Eine Zeile, die eine **Sache aus den Daten** darstellt.
    ///
    /// ## Warum ein eigener Fall und nicht [.choice] mit zwei Feldern mehr
    ///
    /// [.choice] beschreibt, wie eine Zeile **aussieht** und was beim Tippen
    /// passiert. Sie weiß nichts darüber, **was** sie darstellt – und für die
    /// Bildschirme, die ihre Zeilen aus Dart bekommen, ist genau das die
    /// entscheidende Angabe.
    ///
    /// Es gab zwei Wege, das zu lösen, und beide sind hier verworfen:
    ///
    /// * Die Art aus dem **Symbol** ableiten – ein `person.crop.square` bedeutet
    ///   „Person". Damit hinge die Art an einer Dekoration: Wer das Symbol
    ///   ändert, weil es ihm zu breit vorkommt, hat aus einer Liste stillschweigend
    ///   eine Liste anderer Dinge gemacht, ohne dass irgendwo ein Fehler steht.
    /// * Die Art in einer **zweiten Liste** neben der ersten führen, indexgleich.
    ///   Dann müssen zwei Listen über dieselben Zeilen laufen und beide
    ///   gleichzeitig wachsen. Fällt eine zurück, ist die Zuordnung still falsch –
    ///   und ein Tipp auf die falsche Zeile löscht die falsche Sache.
    ///
    /// Deshalb steht die Angabe **in der Zeile**: [kennung] und [art] sind Teil
    /// dessen, was sie darstellt, und können nicht von ihm abweichen.
    case thing(
        title: String,
        subtitle: String?,
        symbol: String,
        // Die Kennung der Sache, so wie die Daten sie nennen. Kein Anzeigename –
        // der kann sich ändern, die Kennung nicht, und beim Löschen wird nach ihr
        // gesucht.
        kennung: String,
        art: ThingArt,
        action: () -> Void)

    /// Was für eine Sache eine [.thing]-Zeile darstellt.
    ///
    /// Eine eigene kleine Art und kein `String`: Sie wird an **drei** Stellen
    /// gebraucht – Symbol, Farbe und die Frage, ob sich die Zeile löschen lässt –
    /// und die müssen immer übereinstimmen. Bei einem `String` müsste jede Stelle
    /// selbst raten, und eine davon irrt sich.
    enum ThingArt {
        /// Eine Klasse – eine ganze Klasse von Schülern.
        ///
        /// Geht auf, wenn der Plan dieser Klasse geöffnet wird.
        case klasse

        /// Eine einzelne Person, die zu einer Klasse gehört.
        ///
        /// Geht auf, wenn der Plan **dieser Person** geöffnet wird – und das ist
        /// ein anderer Plan als der der Klasse, in der sie steht.
        case person
    }

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

    /// Eine Auswahl zwischen zwei oder mehr Möglichkeiten.
    static func segment(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        options: [SegmentOption]
    ) -> Row {
        .segmentRow(
            title: title, subtitle: subtitle, symbol: symbol,
            options: options)
    }

    /// Ein Text, der nur dasteht.
    static func text(title: String, subtitle: String? = nil, symbol: String)
        -> Row
    {
        .textRow(title: title, subtitle: subtitle, symbol: symbol)
    }

    /// Eine Zeile für eine Sache aus den Daten – siehe [Row.thing].
    ///
    /// Der Bequemlichkeitsweg, damit die Bildschirme, die ihre Zeilen aus Dart
    /// bekommen, nicht jedes Mal die Fallunterscheidung ausschreiben müssen.
    static func thing(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        kennung: String,
        art: ThingArt,
        action: @escaping () -> Void
    ) -> Row {
        .thing(
            title: title, subtitle: subtitle, symbol: symbol,
            kennung: kennung, art: art, action: action)
    }
}

/// Ein Angebot in einer [Row.segment]-Zeile.
struct SegmentOption {
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

    /// Die Anmeldung bei [ScreenBridge] – siehe [datenQuelle].
    private var datenToken: UUID?

    init(title: String, largeTitle: Bool = true) {
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

    /// Welcher Bildschirm aus [ScreenBridge] dieser Bildschirm zeichnet – oder
    /// `nil`.
    ///
    /// ## Warum das der Bildschirm selbst sagt
    ///
    /// Weil **er** es ist, der weiss, woher seine Zeilen kommen. Die
    /// Einstellungsseiten lesen aus dem Speicher und melden das hier – sie
    /// brauchen keinen Kanal, und für sie wäre eine Anmeldung nur Arbeit ohne
    /// Gegenwert.
    ///
    /// Der Bildschirm meldet sich damit selbst bei [ScreenBridge.horchZu], und
    /// das geschieht **an einer** Stelle weiter unten, nicht in jedem Bildschirm
    /// für sich: An fünf Stellen einzeln abzuschreiben wäre fünf Gelegenheiten,
    /// eine zu vergessen – und ein Bildschirm, der sich nicht angemeldet hat,
    /// sieht seine eigenen Zeilen kein zweites Mal, ohne dass irgendwo ein
    /// Fehler stünde.
    var datenQuelle: ScreenBridge.Screen? { nil }

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
        tableView.register(SegmentCell.self, forCellReuseIdentifier: SegmentCell.reuseId)
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

        // Hier – und nicht in jedem Bildschirm für sich – siehe [datenQuelle].
        if let quelle = datenQuelle {
            datenToken = ScreenBridge.horchZu(quelle) { [weak self] in
                self?.neuLaden()
            }
        }

        neuLaden()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        farbenSetzen()
        // Beim Zurückkommen kann sich der Speicher geändert haben – und beim
        // Bildschirm mit einer [datenQuelle] auch die Karte aus Dart.
        neuLaden()
    }

    deinit {
        if let token = appearanceToken {
            AppearanceObserver.removeObserver(token)
        }
        // Auch das Abmelden ist Pflicht, nicht Ordnung: `ScreenBridge` hält die
        // Anmeldung, bis sie von Hand zurückgenommen wird. Ohne das bliebe ein
        // Weg zu diesem Bildschirm offen, lange nachdem er weg ist – und die
        // Werte, die ankämen, würde niemand mehr zeichnen.
        if let datenToken, let quelle = datenQuelle {
            ScreenBridge.hoerAuf(quelle, token: datenToken)
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

        erklaerung.font = .preferredFont(forTextStyle: .footnote)
        erklaerung.adjustsFontForContentSizeCategory = true
        erklaerung.lineBreakMode = .byWordWrapping
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

/// Die Zelle für [Row.segment] – eine Wahl zwischen zwei oder mehr Kacheln.
final class SegmentCell: UITableViewCell {
    static let reuseId = "SegmentCell"

    private var stapel: UIStackView?

    /// Ruft der Bildschirm **auf**, wenn eine Kachel gedrückt wurde.
    ///
    /// Nötig, damit die Markierung mitwandert: Die Kachel meldet nur, dass sie
    /// gedrückt wurde, und erst der Bildschirm weiß, was jetzt gespeichert
    /// ist – und dass er seine Zeilen neu bauen muss.
    var onTap: (() -> Void)?

    func configure(options: [SegmentOption], accent: UIColor) {
        backgroundColor = Appearance.surface
        selectionStyle = .none

        // Der alte Aufbau muss weg: Die Zelle wird über die Wiederverwendung
        // mehrfach benutzt, und ohne das Entfernen stünden die Kacheln beim
        // Scrollen ineinander.
        stapel?.removeFromSuperview()
        stapel = nil

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        for option in options {
            let button = UIButton(type: .system)
            button.configuration = option.isSelected ? .filled() : .gray()
            button.configuration?.cornerStyle = .medium
            button.configuration?.baseBackgroundColor = option.isSelected
                ? accent
                : Appearance.surface
            button.configuration?.baseForegroundColor = option.isSelected
                ? .white
                : .label
            button.configuration?.title = option.title
            button.configuration?.image = UIImage(
                systemName: option.symbol,
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 13, weight: .medium))
            button.configuration?.imagePadding = 6
            // Bei grosser Systemschrift passt „Wochenansicht" nicht mehr in
            // eine Kachel. Ohne das bricht der Text **mitten im Wort** ab und
            // läuft über den Nachbarn; damit wird er am Ende abgeschnitten und
            // die Kachel bleibt lesbar.
            button.configuration?.titleLineBreakMode = .byTruncatingTail
            // Der Knopf muss sich anpassen, statt den Text zu quetschen.
            button.configuration?.titleAlignment = .center

            // Der Klick geht an den Aufrufer, nicht hier hin: Er muss den Wert
            // **speichern**, und das Wissen darum liegt dort.
            button.addAction(
                UIAction { [weak self] _ in option.action(); self?.onTap?() },
                for: .touchUpInside)

            stack.addArrangedSubview(button)
        }

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: contentView.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -10),
        ])
        stapel = stack
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stapel?.removeFromSuperview()
        stapel = nil
        onTap = nil
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
        case let .segmentRow(_, _, _, options):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SegmentCell.reuseId, for: indexPath) as! SegmentCell
            cell.configure(options: options, accent: Appearance.accent)
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

        case let .thing(titel, untertitel, symbol, _, _, _):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol)
            // Immer der **Pfeil**, nie der Haken: Eine [.thing]-Zeile ist keine
            // Wahl zwischen Möglichkeiten, sie ist ein Weg weiter – auch dann,
            // wenn daneben eine andere, gleichartige Zeile steht.
            cell.setzeZubehoer(SubtitleCell.symbolFuer(.disclosure))
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
        case let .thing(_, _, _, _, _, aktion): aktion()
        // Beim Schalter erledigt die Kachel das selbst – die ganze Zeile
        // tippen zu lassen wäre eine zweite, schlechtere Stelle dafür.
        case .toggleRow, .segmentRow, .textRow, .warning: break
        }
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
    /// lässt die Liste den Inhalt fragen. Auch die Kachelzeile [Row.segmentRow]
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
        case .segmentRow, .toggleRow, .choice, .thing, .textRow, .warning:
            // Alle Zeilen messen sich selbst – siehe die Beschreibung oben.
            // Eine eigene Höhe je Art gibt es hier bewusst nicht mehr: Jede
            // feste Zahl ist für **irgendeine** Sprache oder Schriftgrösse zu
            // klein, und was nicht passt, wird nicht abgeschnitten, sondern
            // überlagert.
            return UITableView.automaticDimension
        }
    }
}