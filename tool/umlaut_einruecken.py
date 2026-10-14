"""Ersetzt die ASCII-Umschreibungen in den neuen Kommentaren durch echte Umlaute.

Der Grund: In `ListScreen.swift` und `AppearanceScreen.swift` steht derselbe
Satz an manchen Stellen mit `ue`/`ae`/`oe` und an anderen mit `ü`/`ä`/`ö`. Das
sieht nach zwei verschiedenen Autoren aus – und nach einem Maschinenabdruck.

Aufruf:

    python3 tool/umlaut_einruecken.py
"""
import io
import os
import sys

ORDNER = os.path.join("ios", "Runner", "NativeShell")
DATEIEN = ["ListScreen.swift", "AppearanceScreen.swift", "MoreScreen.swift"]

# Nur ganze Woerter, damit nichts zerlegt wird, was zufaellig gleich aussieht.
ERSETZT = [
    ("Aufklappmenue", "Aufklappmenü"),
    ("gewoehnlichen", "gewöhnlichen"),
    ("gewaehlten", "gewählten"),
    ("gewaehlt", "gewählt"),
    ("Menue von", "Menü von"),
    ("Fuer VoiceOver", "Für VoiceOver"),
    ("Erschaen", "Erschein"),
]


def main():
    geaendert = 0
    for name in DATEIEN:
        pfad = os.path.join(ORDNER, name)
        text = io.open(pfad, encoding="utf-8").read()
        vorher = text
        for alt, neu in ERSETZT:
            text = text.replace(alt, neu)
        if text != vorher:
            io.open(pfad, "w", encoding="utf-8").write(text)
            geaendert += 1
            print("  " + name + " angepasst")
    if not geaendert:
        print("  nichts zu tun")
    return 0


if __name__ == "__main__":
    sys.exit(main())