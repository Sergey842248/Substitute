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

        neuLaden()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        farbenSetzen()
        // Beim Zurückkommen kann sich der Speicher geändert haben.
        neuLaden()
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
/// zu wiederholen.
final class SubtitleCell: UITableViewCell {
    static let reuseId = "SubtitleCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        // `super.init` bekommt `.subtitle` – **nicht** den `style`, der
        // hereinkommt. Der ist bei der Wiederverwendung der des zuletzt
        // benutzten Bildschirms und wäre hier der falsche.
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        textLabel?.numberOfLines = 0
        detailTextLabel?.numberOfLines = 0
        // Der Abstand zwischen beiden Zeilen ist in iOS enger, als die
        // Vorgabe macht – und die Vorgabe sieht hier nach zwei getrennten
        // Angaben aus, nicht nach einem Titel mit Erklärung darunter.
        detailTextLabel?.numberOfLines = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    /// Trägt Text und Symbol ein, wie die gerade geltende Helligkeit es will.
    func setzeInhalt(
        titel: String,
        untertitel: String?,
        symbol: String,
        istGefaehrlich: Bool = false
    ) {
        textLabel?.text = titel
        detailTextLabel?.text = untertitel
        detailTextLabel?.isHidden = (untertitel ?? "").isEmpty
        imageView?.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 16, weight: .regular))
        textLabel?.textColor = istGefaehrlich ? .systemRed : .label
        detailTextLabel?.textColor = .secondaryLabel
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
            (cell as? SubtitleCell)?.setzeInhalt(
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
            cell.accessoryView = schalter
            return cell

        case let .textRow(titel, untertitel, symbol):
            let cell = dequeue(indexPath)
            (cell as? SubtitleCell)?.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol)
            cell.selectionStyle = .none
            cell.accessoryView = nil
            cell.accessoryType = .none
            return cell

        case let .warning(titel, untertitel, symbol):
            let cell = dequeue(indexPath)
            (cell as? SubtitleCell)?.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol,
                istGefaehrlich: true)
            cell.selectionStyle = .none
            cell.accessoryView = nil
            cell.accessoryType = .none
            return cell

        case let .choice(titel, untertitel, symbol, zubehoer, gefaehrlich, _):
            let cell = dequeue(indexPath)
            (cell as? SubtitleCell)?.setzeInhalt(
                titel: titel, untertitel: untertitel, symbol: symbol,
                istGefaehrlich: gefaehrlich)
            cell.accessoryView = nil
            cell.accessoryType = {
                switch zubehoer {
                case .none: return .none
                case .disclosure: return .disclosureIndicator
                case .checkmark: return .checkmark
                }
            }()
            return cell
        }
    }

    private func dequeue(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = liste.dequeueReusableCell(
            withIdentifier: SubtitleCell.reuseId, for: indexPath)
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
    /// Feste Werte je Art und **kein** Raten aus der Textlänge: Die Höhe ist
    /// einmal festgelegt, damit eine zweizeilige Erklärung in jeder Sprache
    /// gleich hoch steht und beim Tippen nicht springt.
    func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        switch sections[indexPath.section].rows[indexPath.row] {
        case .segmentRow: return 66
        case .toggleRow, .choice: return 72
        case .textRow, .warning: return 52
        }
    }
}