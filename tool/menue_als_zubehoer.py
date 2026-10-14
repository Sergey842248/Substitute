"""Ersetzt `MenueCell` durch einen Menue-Knopf als Zubehoer von [SubtitleCell].

Ein Aufklappmenue braucht keine eigene Zelle: [SubtitleCell] kann in
`zubehoerBehaelter` beliebiges Zubehoer aufnehmen – ein Schalter ebenso wie einen
Knopf mit `UIMenu`. Damit faellt der ganze zweite Aufbau weg, und die Zeile
erbt das Umbrechen, das [SubtitleCell.aufbauen] inzwischen richtig macht.

Aufruf:

    python3 tool/menue_als_zubehoer.py
"""
import io
import os
import sys

PFAD = os.path.join("ios", "Runner", "NativeShell", "ListScreen.swift")
KAPPE = chr(125)


def lies():
    return io.open(PFAD, encoding="utf-8").read()


def ersetze(text, alt, neu, was):
    if alt not in text:
        raise SystemExit("Anker nicht gefunden: " + was)
    if text.count(alt) != 1:
        raise SystemExit("Anker nicht eindeutig: " + was)
    return text.replace(alt, neu, 1)


def entferne_klasse(text, klassenzeile):
    """Entfernt eine ganze Klasse samt ihres Kommentarblocks."""
    zeilen = text.split("\n")
    try:
        kl = next(i for i, l in enumerate(zeilen) if l.startswith(klassenzeile))
    except StopIteration:
        raise SystemExit("Klasse nicht gefunden: " + klassenzeile)

    start = kl
    while start - 1 >= 0 and zeilen[start - 1].strip().startswith("///"):
        start -= 1

    for i in range(1, 800):
        j = kl + i
        if j >= len(zeilen):
            break
        if zeilen[j] == KAPPE and zeilen[j - 1].strip() == KAPPE:
            # Auch die Leerzeile danach mitnehmen.
            ende = j + 1
            if ende + 1 < len(zeilen) and zeilen[ende + 1].strip() == "":
                ende += 1
            del zeilen[start:ende + 1]
            return "\n".join(zeilen)
    raise SystemExit("Ende der Klasse nicht gefunden: " + klassenzeile)


KNOPF = '''    /// Der Knopf für ein Aufklappmenü, fertig eingerichtet.
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
        let gewaehlt = optionen.first { $0.isSelected } ?? optionen.first

        let knopf = UIButton(type: .system)
        knopf.configuration = .plain()
        knopf.showsMenuAsPrimaryAction = true
        knopf.contentHorizontalAlignment = .trailing
        // Der Wert wird eher gestaucht als die Beschriftung links – sonst stünde
        // am Ende ein abgeschnittener Wert neben einem vollständigen Titel.
        knopf.setContentHuggingPriority(.required, for: .horizontal)
        knopf.setContentCompressionResistancePriority(
            .required, for: .horizontal)

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

        // Fuer VoiceOver: Der sichtbare Titel sagt nicht, was gewaehlt ist.
        knopf.accessibilityLabel = [titel, gewaehlt?.title]
            .compactMap { $0 }
            .joined(separator: ", ")
        return knopf
    }

'''


def main():
    text = lies()

    # 1. Die eigene Zelle wieder entfernen.
    text = entferne_klasse(text, "final class MenueCell")

    # 2. Die Hilfsmethode an den Anfang der Erweiterung setzen, in der auch die
    #    anderen Wege fuer Zellen stehen.
    anker = "    private func dequeue(_ indexPath: IndexPath) -> SubtitleCell {"
    if anker not in text:
        raise SystemExit("dequeue nicht gefunden")
    text = text.replace(anker, KNOPF + anker, 1)

    # 3. Die Anmeldung der Zelle wieder raus.
    text = ersetze(text,
                  "        tableView.register(MenueCell.self, forCellReuseIdentifier: MenueCell.reuseId)\n",
                  "", "Registrierung")

    # 4. Die Zeile im Datenlieferanten: jetzt SubtitleCell plus Knopf.
    text = ersetze(text, """        case let .menuRow(titel, untertitel, symbol, optionen):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MenueCell.reuseId, for: indexPath) as! MenueCell
            cell.setzeMenue(
                title: titel, subtitle: untertitel, options: optionen)
            // Der Bildschirm baut seine Zeilen neu, sobald ein Wert gefallen ist –
            // erst dann wandert der Haken im Menü mit.
            cell.onTap = { [weak self] in self?.neuLaden() }
            return cell""",
"""        case let .menuRow(titel, untertitel, symbol, optionen):
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
            return cell""", "menuRow in cellForRowAt")

    io.open(PFAD, "w", encoding="utf-8").write(text)

    rest = lies()
    for alt in ("MenueCell", "setzeMenue"):
        if alt in rest:
            raise SystemExit("Noch vorhanden: " + alt)
    print("ListScreen.swift: Aufklappmenue als Zubehoer von SubtitleCell.")
    return 0


if __name__ == "__main__":
    sys.exit(main())