"""Ersetzt die Kachelwahl durch ein Aufklappmenü (Erscheinungsbild).

Ein Durchgang, ein Ort: `Row.segmentRow` samt `SegmentOption` und `SegmentCell`
verschwindet, `Row.menuRow` samt `MenuOption` und `MenueCell` kommt dafür. Aufruf:

    python3 tool/make_theme_dropdown.py
"""
import io
import os
import sys

PFAD = os.path.join("ios", "Runner", "NativeShell", "ListScreen.swift")
KAPPE = chr(125)          # '}' - nicht als Klammer im Skript, sonst stoert es
OEFFN = chr(123)          # '{'


def lies():
    return io.open(PFAD, encoding="utf-8").read()


def schreibe(text):
    io.open(PFAD, "w", encoding="utf-8").write(text)


def ersetze(text, alt, neu, was):
    if alt not in text:
        raise SystemExit("Anker nicht gefunden: " + was)
    if text.count(alt) != 1:
        raise SystemExit("Anker nicht eindeutig: " + was)
    return text.replace(alt, neu, 1)


def zeilenbereich(text, klassenzeile, ende_marker=None):
    """Index der erste Zeile vor der Klasse und der schliessenden Klammer."""
    zeilen = text.split("\n")
    try:
        kl = next(i for i, l in enumerate(zeilen)
                  if l.startswith(klassenzeile))
    except StopIteration:
        raise SystemExit("Klasse nicht gefunden: " + klassenzeile)

    start = kl
    while start - 1 >= 0 and zeilen[start - 1].strip().startswith("///"):
        start -= 1

    for i in range(1, 600):
        j = kl + i
        if j >= len(zeilen):
            break
        # Die Klammer am Zeilenende, direkt gefolgt von einer eingerueckten.
        if zeilen[j] == KAPPE and zeilen[j - 1].strip() == KAPPE:
            return zeilen, start, j
    raise SystemExit("Ende der Klasse nicht gefunden: " + klassenzeile)


NEUE_ZELLE = '''/// Die Zelle für [Row.menuRow] – eine Wahl aus mehreren Werten.
///
/// ## Wie hier ein Menü entsteht
///
/// Nicht von Hand, sondern über `UIMenu`: Das ist die **Menüleiste** von iOS, und
/// sie bringt mit, was ein eigenes Aufklappmenü sonst nachbauen müsste – die
/// Anordnung, die Trennlinien, das Anheben, das Schliessen und das Verschwinden,
/// sobald man irgendwo anders hin-tippt.
///
/// `showsMenuAsPrimaryAction = true` ist dabei das Entscheidende: Damit wird der
/// Knopf **nicht** zum `UIAction`-Empfänger, sondern öffnet bei jedem Tippen das
/// Menü. Ohne die Zeile gaebe es beim ersten Tippen gar nichts.
///
/// ## Warum links der Titel und rechts der Wert
///
/// So steht es in allen Listen von iOS, die eine Auswahl anbieten: Der Wert ist
/// das, woran man merkt, was gerade gilt – und er steht dort, wo das Auge danach
/// sucht. Die Erklaerung darunter bleibt fuer das **Warum** frei.
final class MenueCell: UITableViewCell {
    static let reuseId = "MenueCell"

    private let knopf = UIButton(type: .system)

    /// Wird nach einer Wahl aufgerufen, damit der Bildschirm seine Zeilen neu
    /// baut und der Wert an der richtigen Stelle steht.
    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        aufbauen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    private func aufbauen() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        accessoryView = nil
        accessoryType = .none
        backgroundColor = Appearance.surface
        selectionStyle = .none

        knopf.configuration = .plain()
        // Ohne diese Zeile waere der Knopf ein gewoehnlicher Empfaenger fuer
        // `touchUpInside` – und es passierte gar nichts. Mit ihr ist das Menue
        // das, was ein Druck ausloest.
        knopf.showsMenuAsPrimaryAction = true
        knopf.contentHorizontalAlignment = .trailing
        knopf.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(knopf)
        NSLayoutConstraint.activate([
            knopf.topAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.topAnchor),
            knopf.bottomAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            knopf.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            knopf.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor),
        ])
    }

    /// Baut Titel, Erklaerung und das Menue selbst auf.
    ///
    /// Der **Wert** steht im Knopf, und der ist der gewaehlte:
    /// `options.first(where: { $0.isSelected })`.
    func setzeMenue(
        title: String, subtitle: String?, options: [MenuOption]
    ) {
        // Der eingebaute Aufbau traegt Titel und Erklaerung. Er wird hier **nicht**
        // entfernt – anders als in [SubtitleCell] – weil der Knopf danebensteht
        // und beide in dieselbe Zelle gehoeren.
        textLabel?.text = title
        textLabel?.font = .preferredFont(forTextStyle: .body)
        textLabel?.adjustsFontForContentSizeCategory = true
        textLabel?.numberOfLines = 0

        detailTextLabel?.text = subtitle
        detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        detailTextLabel?.adjustsFontForContentSizeCategory = true
        detailTextLabel?.textColor = .secondaryLabel
        detailTextLabel?.numberOfLines = 0
        // Ein leeres, aber sichtbares Feld liesse einen Absatz mit leerer Hoehe
        // offen.
        detailTextLabel?.isHidden = ((subtitle ?? "").isEmpty)

        let gewaehlt = options.first { $0.isSelected } ?? options.first

        knopf.configuration?.title = gewaehlt?.title
        // Der Doppelpfeil ist das Einzige, was ein Aufklappmenue von einem
        // gewoehnlichen Knopf unterscheidet. Ohne ihn sieht die Zeile aus wie ein
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

        // Der Haken sitzt am **gewaehlten** Eintrag – so wie in jedem Menue von
        // iOS. Das Menue wird bei jedem Aufbau neu gebaut, deshalb wandert der
        // Haken von selbst mit.
        let aktionen = options.map { option -> UIAction in
            UIAction(
                title: option.title,
                image: UIImage(systemName: option.symbol),
                state: option.isSelected ? .on : .off) { [weak self] _ in
                    // Der Wert wird **gespeichert** – das Wissen darum liegt beim
                    // Aufrufer, nicht hier.
                    option.action()
                    self?.onTap?()
                }
        }
        knopf.menu = UIMenu(title: "", children: aktionen)

        accessibilityLabel = [title, gewaehlt?.title]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }
}'''


def main():
    text = lies()

    # 1. Der Fall im Enum.
    text = ersetze(text, """    /// Ein Wechsel **zwischen** Werten, wie bei hell und dunkel.
    ///
    /// Als nebeneinanderliegende Auswahlflächen gebaut und nicht als Schalter:
    /// Es sind gleichwertige Möglichkeiten, und ein Schalter müsste durch
    /// seinen Zustand sagen, was beim Umstellen passiert. Die Flächen zeigen
    /// beide, und die gewählte ist gefüllt.
    case segmentRow(
        title: String,
        subtitle: String?,
        symbol: String,
        options: [SegmentOption])""",
"""    /// Eine Wahl aus mehreren Werten – als **Aufklappmenü**.
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
        options: [MenuOption])""", "segmentRow im Enum")

    # 2. Die Angebotsart.
    text = ersetze(text, """/// Ein Angebot in einer [Row.segment]-Zeile.
struct SegmentOption {""",
"""/// Ein Angebot in einer [Row.menuRow]-Zeile.
///
/// `isSelected` wird bei jedem Aufbau neu gesetzt – die Zelle merkt sich
/// nichts, sondern zeigt das, was der Bildschirm ihr gerade gegeben hat. So
/// kann die Zeile gar nichts anderes anzeigen, als gespeichert ist.
struct MenuOption {""", "SegmentOption")

    # 3. Die bequeme Form.
    text = ersetze(text, """    /// Eine Auswahl zwischen zwei oder mehr Möglichkeiten.
    static func segment(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        options: [SegmentOption]
    ) -> Row {
        .segmentRow(
            title: title, subtitle: subtitle, symbol: symbol,
            options: options)
    }""",
"""    /// Eine Auswahl aus zwei oder mehr Möglichkeiten – als Aufklappmenü.
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
    }""", "Row.segment")

    # 4. Die Zelle ersetzen.
    zeilen, start, ende = zeilenbereich(text, "final class SegmentCell")
    zeilen[start:ende + 1] = NEUE_ZELLE.split("\n")
    text = "\n".join(zeilen)

    # 5. Anmeldung der Zelle.
    text = ersetze(text,
                  "        tableView.register(SegmentCell.self, forCellReuseIdentifier: SegmentCell.reuseId)",
                  "        tableView.register(MenueCell.self, forCellReuseIdentifier: MenueCell.reuseId)",
                  "Registrierung")

    # 6. Die Zelle im Datenlieferanten.
    text = ersetze(text, """        case let .segmentRow(_, _, _, options):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SegmentCell.reuseId, for: indexPath) as! SegmentCell
            cell.configure(options: options, accent: Appearance.accent)
            return cell""",
"""        case let .menuRow(titel, untertitel, symbol, optionen):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MenueCell.reuseId, for: indexPath) as! MenueCell
            cell.setzeMenue(
                title: titel, subtitle: untertitel, options: optionen)
            // Der Bildschirm baut seine Zeilen neu, sobald ein Wert gefallen ist –
            // erst dann wandert der Haken im Menü mit.
            cell.onTap = { [weak self] in self?.neuLaden() }
            return cell""", "segmentRow in cellForRowAt")

    # 7. Die beiden Stellen, an denen alle uebrigen Faelle genannt werden.
    text = ersetze(text, "        case .toggleRow, .segmentRow, .textRow, .warning: break",
                  "        case .toggleRow, .menuRow, .textRow, .warning: break",
                  "didSelectRowAt")
    text = ersetze(text, "        case .segmentRow, .toggleRow, .choice, .textRow, .warning:",
                  "        case .menuRow, .toggleRow, .choice, .textRow, .warning:",
                  "heightForRowAt")
    text = ersetze(text,
                  "    /// lässt die Liste den Inhalt fragen. Auch die Kachelzeile [Row.segmentRow]",
                  "    /// lässt die Liste den Inhalt fragen. Auch die Menüzeile [Row.menuRow]",
                  "Bildschirmspitze")

    schreibe(text)

    # Gegenprobe: Es darf nichts mehr übrig sein.
    rest = lies()
    for alt in ("SegmentCell", "SegmentOption", "segmentRow", "Row.segment"):
        if alt in rest:
            raise SystemExit("Noch vorhanden: " + alt)
    print("ListScreen.swift: Aufklappmenue statt Kacheln.")
    return 0


if __name__ == "__main__":
    sys.exit(main())