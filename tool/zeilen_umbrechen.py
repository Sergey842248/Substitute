"""Laesst lange Texte in einer Zeile umbrechen – wieder.

## Was hier passiert ist

Der erste Versuch dieser Aenderung wurde beim Zuruecksetzen von
`ListScreen.swift` weggeworfen: Um die Kachelwahl durch ein Aufklappmenue zu
ersetzen, wurde die Datei auf den Stand von `HEAD` zurueckgesetzt – und damit
auch die Zeilen, die den Umbruch eingebracht hatten. Die Kachelwahl kam zurueck,
der Umbruch nicht.

## Warum es ohne das nicht geht

`UILabel` hat von sich aus genau **eine** Zeile. Mit
`lineBreakMode = .byWordWrapping` und einer Zeile malt das System den Text nicht
um: Es malt ihn einzeilig **ueber den Rand hinaus**, ohne Restzeichen. Eine lange
Umschalt-Ueberschrift schiebt dabei den Schalter aus der Zeile und dann aus dem
Bild.

Mit `numberOfLines = 0` bricht der Text an den Kanten des Stapels um, und die
Zeile der Liste wird so hoch, wie der Text es braucht.

Damit das nicht nur am rechten Rand klappt, weicht der Textstapel nun
**entschieden** nach: Er gibt dem Zubehoer (Schalter, Haken, Menue-Knopf) Platz,
statt selbst Platz zu verlangen.

Aufruf:

    python3 tool/zeilen_umbrechen.py
"""
import io
import os
import sys

PFAD = os.path.join("ios", "Runner", "NativeShell", "ListScreen.swift")


def lies():
    return io.open(PFAD, encoding="utf-8").read()


def ersetze(text, alt, neu, was):
    if alt not in text:
        raise SystemExit("Anker nicht gefunden: " + was)
    if text.count(alt) != 1:
        raise SystemExit("Anker nicht eindeutig: " + was)
    return text.replace(alt, neu, 1)


def main():
    text = lies()

    if "numberOfLines = 0" in text:
        print("ListScreen.swift: Umbruch ist bereits drin.")
        return 0

    text = ersetze(text, """        beschriftung.font = .preferredFont(forTextStyle: .body)
        beschriftung.adjustsFontForContentSizeCategory = true
        // Ohne das bricht der Text bei grosser Systemschrift mitten im Wort ab.
        beschriftung.lineBreakMode = .byWordWrapping

        erklaerung.font = .preferredFont(forTextStyle: .footnote)
        erklaerung.adjustsFontForContentSizeCategory = true
        erklaerung.lineBreakMode = .byWordWrapping
        // Die Erklärung wird eher gestaucht als der Titel – der Titel ist das,
        // woran man den Eintrag überhaupt erkennt.
        erklaerung.setContentCompressionResistancePriority(
            .defaultLow, for: .horizontal)""",
"""        beschriftung.font = .preferredFont(forTextStyle: .body)
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
            .defaultLow, for: .horizontal)""", "Beschriftung und Erklaerung")

    text = ersetze(text, """        spalte.axis = .vertical
        spalte.alignment = .fill
        spalte.spacing = 2
        spalte.translatesAutoresizingMaskIntoConstraints = false""",
"""        spalte.axis = .vertical
        spalte.alignment = .fill
        spalte.spacing = 2
        spalte.translatesAutoresizingMaskIntoConstraints = false
        // Der Text weicht dem Zubehör aus, und zwar **entschieden**: Ein Stapel,
        // der auf seine volle Wortbreite besteht, drängt Schalter, Haken und
        // Menü-Knopf aus der Zeile. Wer hier nachgibt, bestimmt die Breite der
        // ganzen Zeile.
        spalte.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spalte.setContentCompressionResistancePriority(
            .defaultLow, for: .horizontal)""", "Textstapel")

    io.open(PFAD, "w", encoding="utf-8").write(text)
    print("ListScreen.swift: Umbruch wieder drin.")
    return 0


if __name__ == "__main__":
    sys.exit(main())