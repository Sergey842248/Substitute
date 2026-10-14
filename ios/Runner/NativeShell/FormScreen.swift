import UIKit

/// Die Zeilen eines **Formulars**.
///
/// ## Warum es neben [Row] noch eine zweite Art gibt
///
/// [Row] beschreibt eine Liste, in der jede Zeile dasselbe kann: zeigen, einen
/// Wert umschalten, irgendwohin gehen. Ein Formular ist anders: Hier stehen
/// Felder, in die man **schreibt**.
///
/// Der Unterschied ist nicht kosmetisch. Eine Schalterzeile liest ihren Wert aus
/// dem Speicher und schreibt ihn sofort zurück. Ein Eingabefeld hat keinen
/// gespeicherten Wert – es hat, was gerade getippt wurde, und das ist etwas
/// ganz anderes: ein halber Benutzername ist kein gespeicherter Benutzername.
///
/// Deshalb sind es zwei Arten und nicht eine, die beides kann.
enum FormRow {
    /// Ein Feld, in das man schreibt.
    ///
    /// Der Wert wandert bei **jedem** Tastendruck über `onChange` an den
    /// Bildschirm. Das sind mehr Meldungen, als der Preis verlangt – aber es ist
    /// die einzige Art, bei der der Bildschirm auch dann das Richtige zeigt,
    /// wenn er zwischendurch neu gebaut wird.
    case feld(
        titel: String,
        platzhalter: String,
        symbol: String,
        text: String,
        sicher: Bool,
        tastatur: UIKeyboardType,
        onChange: (String) -> Void)

    /// Ein Schalter, der einen Wert umstellt.
    case schalter(
        titel: String,
        untertitel: String?,
        symbol: String,
        wert: Bool,
        aktion: (Bool) -> Void)

    /// Eine Zeile, die weiterführt.
    case wahl(
        titel: String,
        untertitel: String?,
        symbol: String,
        aktion: () -> Void)

    /// Eine Zeile, die nur etwas sagt.
    case text(titel: String, untertitel: String?, symbol: String)

    /// Der grosse Knopf am Ende eines Formulars.
    ///
    /// Für das eine Ding, worum es auf dem Bildschirm geht. Er ist gefüllt und
    /// steht allein – das ist der ganze Unterschied zu einer gewöhnlichen Zeile.
    case knopf(titel: String, untertitel: String?, aktion: () -> Void)
}

/// Eine Gruppe von Formularzeilen.
///
/// Wie [Section] und aus demselben Grund: Überschrift oben, Fußnote unten, und
/// beides liest sich als Erklärung und nicht als Inhalt.
struct FormSection {
    let header: String?
    let footer: String?
    let rows: [FormRow]

    init(header: String? = nil, footer: String? = nil, rows: [FormRow]) {
        self.header = header
        self.footer = footer
        self.rows = rows
    }
}

/// Der Bildschirm, in dem ein **Formular** steht.
///
/// Er weiss, wie ein Feld, ein Schalter und ein Knopf aussehen – und nichts
/// darüber, was in ihnen steht. Das kommt von aussen, und zwar bei jedem
/// Aufbau neu: so kann eine Zeile gar nichts anderes anzeigen, als was der
/// Bildschirm ihr gerade gegeben hat.
///
/// ## Warum die Felder **nicht** wiederverwendet werden
///
/// `UITableView` gibt Zeilen zum Wiederverwenden frei, sobald sie weggescrollt
/// sind. Eine Zelle mit einem Eingabefeld herauszugeben hieße: Das Feld, in dem
/// man tippt, gehört plötzlich einer anderen Zeile, und der getippte Text
/// verschwindet – ohne dass irgendwo ein Fehler erschiene.
///
/// Deshalb wird für jede Feldzeile eine **neue** Zelle gebaut. Dafür steht der
/// Text nicht in der Zelle, sondern im Bildschirm: Er wird bei jedem Tastendruck
/// dorthin gemeldet, und der Bildschirm liefert ihn beim nächsten Aufbau zurück.
/// Was gespeichert wird, entscheidet der Bildschirm – nicht die Zelle.
/// Nicht `final`: [CredentialsScreen] erweitert sie um die vier Felder.
class FormScreen: UIViewController {
    private(set) var abschnitte: [FormSection] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var appearanceToken: UUID?

    init(title: String, largeTitle: Bool = true) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
        navigationItem.largeTitleDisplayMode = largeTitle ? .always : .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    // -------------------------------------------------- von den Unterklassen

    /// Die Abschnitte dieses Bildschirms.
    func makeSections() -> [FormSection] { [] }

    /// Baut das Formular neu auf.
    ///
    /// [neuLaden] liest [makeSections] erneut. Das ist wichtig, weil sich der
    /// Speicher ändern kann, während der Bildschirm im Hintergrund liegt – und
    /// weil manche Bildschirme den Inhalt eines Feldes von **ausserhalb** setzen,
    /// etwa nachdem ein QR-Code gelesen wurde.
    ///
    /// Ist [animiert] gesetzt, wird die Änderung zwischen zwei
    /// Formularzuständen überblendet. Das ist besonders bei einem Schalter
    /// wichtig, der weitere Felder ein- oder ausblendet: Die Änderung soll wie
    /// eine Folge der Schalterbewegung wirken, nicht wie ein harter Sprung.
    func neuLaden(animiert: Bool = false) {
        abschnitte = makeSections()
        guard isViewLoaded else { return }
        guard animiert, !UIAccessibility.isReduceMotionEnabled else {
            tableView.reloadData()
            return
        }

        UIView.transition(
            with: tableView,
            duration: 0.22,
            options: [.transitionCrossDissolve, .allowAnimatedContent]
        ) {
            self.tableView.reloadData()
        }
    }

    /// Führt die Änderung erst aus, nachdem die systemeigene Bewegung eines
    /// [UISwitch] sichtbar war. Einige Schalter bauen anschließend das gesamte
    /// Formular neu auf; ohne diese kurze Wartezeit würde der alte Schalter
    /// sofort entfernt und seine native iOS-Animation abgeschnitten.
    private func nachSchalterAnimation(
        _ schalter: UISwitch,
        aktion: @escaping (Bool) -> Void
    ) {
        let neuerWert = schalter.isOn
        guard !UIAccessibility.isReduceMotionEnabled else {
            aktion(neuerWert)
            return
        }

        // Während die Bewegung läuft, kann ein zweiter Tipp keinen veralteten
        // Zustand speichern. Die Dauer entspricht der kurzen, nativen
        // UISwitch-Transition und verzögert nur Umbauten des Formulars.
        schalter.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak schalter] in
            schalter?.isUserInteractionEnabled = true
            aktion(neuerWert)
        }
    }

    // --------------------------------------------------------------- Aufbau

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.background

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        // Die Zeilenhöhe folgt dem Text – siehe
        // `tableView(_:heightForRowAt:)`.
        tableView.estimatedRowHeight = 64
        tableView.rowHeight = UITableView.automaticDimension
        // Beim Scrollen muss die Tastatur weg: Sie bleibt sonst über den unteren
        // Zeilen stehen, und die sind genau die, die man beim Tippen auslöst.
        tableView.keyboardDismissMode = .onDrag
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.reuseId)
        tableView.register(KnopfCell.self, forCellReuseIdentifier: KnopfCell.reuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Wer die Helligkeit umstellt, muss es auch hier erfahren – sonst stünde
        // das Formular in der alten Farbe, während der Bildschirm daneben schon
        // den neuen zeigt.
        appearanceToken = AppearanceObserver.observe { [weak self] in
            self?.farbenSetzen()
        }

        // Ein Tippen neben den Feldern soll die Tastatur wegnehmen.
        let tippen = UITapGestureRecognizer(
            target: self, action: #selector(tastaturWeg))
        // `false`, damit der Durchgang bleibt: Ohne das würde das Tippen auf
        // eine **Zeile** verschluckt – und nichts auf dieser Seite reagiert auf
        // blosses Tippen.
        tippen.cancelsTouchesInView = false
        view.addGestureRecognizer(tippen)

        neuLaden()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        farbenSetzen()
        neuLaden()
    }

    deinit {
        if let token = appearanceToken {
            AppearanceObserver.removeObserver(token)
        }
    }

    @objc private func tastaturWeg() {
        view.endEditing(true)
    }

    private func farbenSetzen() {
        view.backgroundColor = Appearance.background
        tableView.reloadData()
        navigationController?.navigationBar.tintColor = Appearance.accent
    }

    /// Die Liste – für Unterklassen, die sie anfassen wollen.
    var liste: UITableView { tableView }
}

// MARK: - Die Zellen

/// Die Zelle mit einem Eingabefeld.
///
/// ## Der Aufbau
///
/// Symbol, Eingabe und – als **kleine** Zeile darüber – der Name des Feldes.
/// Die Überschrift steht über der Eingabe und nicht daneben: Bei einer
/// Schulnummer wäre sie daneben eingeengt, bei einem Passwort gar nicht mehr
/// unterzubringen.
///
/// Der Text wird von [setzeAussehen(titel:platzhalter:symbol:sicher:tastatur:)]
/// **nicht** gesetzt, sondern von [setzeText(_:)]. Das sind zwei Aufrufe, weil
/// beides verschiedene Augenblicke sind: Das Aussehen gehört zum Aufbau der
/// Zeile, der Text zum Stand des Bildschirms.
final class FeldCell: UITableViewCell {
    /// Das Feld selbst.
    let eingabe = UITextField()

    private let beschriftung = UILabel()
    private let symbolView = UIImageView()

    /// Wird bei **jedem** Tastendruck aufgerufen – siehe [FormRow.feld].
    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        aufbauen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    private func aufbauen() {
        // Siehe [SubtitleCell.aufbauen()]: Die eingebauten Felder werden
        // entfernt, damit nur der eigene Aufbau die Höhe der Zeile bestimmt.
        contentView.subviews.forEach { $0.removeFromSuperview() }
        accessoryView = nil
        accessoryType = .none

        beschriftung.font = .preferredFont(forTextStyle: .caption1)
        beschriftung.adjustsFontForContentSizeCategory = true
        beschriftung.textColor = .secondaryLabel
        beschriftung.lineBreakMode = .byWordWrapping
        beschriftung.numberOfLines = 0

        // ## Ohne diese eine Zeile passiert hier das Schlimmste
        //
        // `beschriftung` ist das **einzige** Feld dieser Zelle, das nicht im
        // Stapel steckt – es hängt direkt am `contentView`. Und ein
        // programmatisch erzeugtes `UILabel` hat `translatesAutoresizingMaskInto-
        // Constraints = true`: Es wird **nicht** über Auto Layout gelegt.
        //
        // Merkt man sich das nicht, passiert Folgendes: Die Vorgaben für oben
        // und unten werden ignoriert, die Zelle bekommt von der Beschriftung
        // keine Höhe mehr – und die Zeile fällt auf die Höhe ihres Inhalts
        // zusammen. Bei vier Feldern heisst das: alle vier übereinander, und
        // das erste, was man antippt, ist keines von ihnen.
        //
        // Der Stapel (`zeile`) nimmt `symbolView` und `eingabe` auf, und für
        // beide hebt `addArrangedSubview` den Rahmen-Automatismus von selbst
        // auf. Die Beschriftung kommt **nicht** in den Stapel, deshalb ist die
        // eine Zeile hier ihre Pflicht.
        beschriftung.translatesAutoresizingMaskIntoConstraints = false

        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = .secondaryLabel
        symbolView.setContentHuggingPriority(.required, for: .horizontal)
        symbolView.setContentCompressionResistancePriority(
            .required, for: .horizontal)

        eingabe.font = .preferredFont(forTextStyle: .body)
        eingabe.adjustsFontForContentSizeCategory = true
        eingabe.borderStyle = .none
        eingabe.adjustsFontSizeToFitWidth = true
        eingabe.minimumFontSize = 15
        eingabe.translatesAutoresizingMaskIntoConstraints = false
        eingabe.addTarget(self, action: #selector(geaendert), for: .editingChanged)

        let zeile = UIStackView(arrangedSubviews: [symbolView, eingabe])
        zeile.axis = .horizontal
        zeile.spacing = 12
        zeile.alignment = .center
        zeile.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(zeile)
        contentView.addSubview(beschriftung)
        NSLayoutConstraint.activate([
            symbolView.widthAnchor.constraint(equalToConstant: 22),
            zeile.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            zeile.leadingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            zeile.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            beschriftung.topAnchor.constraint(equalTo: zeile.bottomAnchor, constant: 2),
            beschriftung.leadingAnchor.constraint(equalTo: zeile.leadingAnchor),
            beschriftung.trailingAnchor.constraint(equalTo: zeile.trailingAnchor),
            beschriftung.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -11),
        ])
    }

    /// Trägt Symbol, Überschrift und Tastaturart ein.
    func setzeAussehen(
        titel: String, platzhalter: String, symbol: String,
        sicher: Bool, tastatur: UIKeyboardType
    ) {
        beschriftung.text = titel
        eingabe.placeholder = platzhalter
        eingabe.isSecureTextEntry = sicher
        eingabe.keyboardType = tastatur
        // Ohne das schlug iOS bei Schulnummer **und** Benutzername nach: Es
        // merkt sich, was man getippt hat, und bietet es beim nächsten Mal an –
        // bei einer Schulnummer ist das jedes Mal falsch.
        eingabe.autocorrectionType = .no
        eingabe.spellCheckingType = .no
        eingabe.autocapitalizationType = .none
        eingabe.textContentType = .none
        symbolView.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 16, weight: .regular))
        backgroundColor = Appearance.surface
        selectionStyle = .none
        accessibilityLabel = titel
    }

    /// Setzt den Text, ohne eine Meldung auszulösen.
    ///
    /// Ohne das würde [setzeText(_:)] einen Tastendruck vortäuschen, und der
    /// Bildschirm würde melden, der Nutzer habe etwas getippt – was er gerade
    /// nicht getan hat.
    func setzeText(_ text: String) {
        if eingabe.text != text { eingabe.text = text }
    }

    @objc private func geaendert() {
        onChange?(eingabe.text ?? "")
    }
}

/// Die Zelle des grossen Knopfes.
final class KnopfCell: UITableViewCell {
    static let reuseId = "KnopfCell"

    private let knopf = UIButton(type: .system)

    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        aufbauen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    private func aufbauen() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        backgroundColor = .clear
        selectionStyle = .none

        knopf.configuration = .filled()
        knopf.configuration?.cornerStyle = .medium
        knopf.configuration?.titleAlignment = .center
        knopf.translatesAutoresizingMaskIntoConstraints = false
        knopf.addAction(
            UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)

        contentView.addSubview(knopf)
        NSLayoutConstraint.activate([
            knopf.topAnchor.constraint(
                equalTo: contentView.topAnchor, constant: 12),
            knopf.leadingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            knopf.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            knopf.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func setzeInhalt(titel: String, untertitel: String?) {
        knopf.configuration?.title = titel
        knopf.configuration?.baseBackgroundColor = Appearance.accent
        knopf.configuration?.baseForegroundColor = .white
        // Für VoiceOver: Der Knopf zeigt nur einen Titel, und der Titel allein
        // sagt nicht, was passiert.
        knopf.accessibilityLabel =
            [titel, untertitel].compactMap { $0 }.joined(separator: ", ")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }
}

// MARK: - Die Liste

extension FormScreen: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { abschnitte.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        abschnitte[section].rows.count
    }

    func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let zeile = abschnitte[indexPath.section].rows[indexPath.row]

        switch zeile {
        case let .feld(titel, platzhalter, symbol, text, sicher, tastatur, onChange):
            // Bewusst **nicht** wiederverwendet – siehe die Beschreibung von
            // [FormScreen].
            let cell = FeldCell(style: .default, reuseIdentifier: nil)
            cell.setzeAussehen(
                titel: titel, platzhalter: platzhalter, symbol: symbol,
                sicher: sicher, tastatur: tastatur)
            cell.setzeText(text)
            cell.onChange = onChange
            return cell

        case let .schalter(titel, untertitel, symbol, wert, aktion):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(titel: titel, untertitel: untertitel, symbol: symbol)
            cell.selectionStyle = .none
            let schalter = UISwitch()
            schalter.isOn = wert
            // Schwach gefangen: Der Schalter hält die Aktion, die Aktion würde den
            // Schalter halten – ein Kreis, der die Zelle am Leben hält, obwohl
            // sie längst aus der Liste ist.
            schalter.addAction(
                UIAction { [weak self, weak schalter] _ in
                    guard let self, let schalter else { return }
                    self.nachSchalterAnimation(schalter, aktion: aktion)
                }, for: .valueChanged)
            cell.setzeZubehoer(schalter)
            return cell

        case let .wahl(titel, untertitel, symbol, _):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(titel: titel, untertitel: untertitel, symbol: symbol)
            cell.setzeZubehoer(SubtitleCell.symbolFuer(.disclosure))
            return cell

        case let .text(titel, untertitel, symbol):
            let cell = dequeue(indexPath)
            cell.setzeInhalt(titel: titel, untertitel: untertitel, symbol: symbol)
            cell.selectionStyle = .none
            cell.setzeZubehoer(nil)
            return cell

        case let .knopf(titel, untertitel, aktion):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: KnopfCell.reuseId, for: indexPath) as! KnopfCell
            cell.setzeInhalt(titel: titel, untertitel: untertitel)
            cell.onTap = aktion
            return cell
        }
    }

    private func dequeue(_ indexPath: IndexPath) -> SubtitleCell {
        let cell = liste.dequeueReusableCell(
            withIdentifier: SubtitleCell.reuseId, for: indexPath) as! SubtitleCell
        // Ohne `.clear` läge die Standardhinterlegung **über** der gesetzten
        // Farbe, und die Zeile bliebe grau, egal was eingestellt ist.
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
        switch abschnitte[indexPath.section].rows[indexPath.row] {
        case let .wahl(_, _, _, aktion):
            aktion()
        case let .knopf(_, _, aktion):
            aktion()
        // Ein Feld zieht die Tastatur hoch, ein Schalter schaltet um: Das
        // erledigt die Zeile selbst, und die ganze Zeile tippen zu lassen wäre
        // eine zweite, schlechtere Stelle dafür.
        case .feld, .schalter, .text: break
        }
    }

    func tableView(
        _ tableView: UITableView, titleForHeaderInSection section: Int
    ) -> String? { abschnitte[section].header }

    func tableView(
        _ tableView: UITableView, titleForFooterInSection section: Int
    ) -> String? { abschnitte[section].footer }

    /// Wie hoch eine Zeile wird.
    ///
    /// Jede Zeile misst sich selbst, und aus demselben Grund wie in [ListScreen]:
    /// Eine feste Höhe wäre für irgendeine Sprache oder Schriftgrösse zu klein,
    /// und was nicht passt, wird nicht abgeschnitten, sondern **überlagert**.
    func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        UITableView.automaticDimension
    }
}
