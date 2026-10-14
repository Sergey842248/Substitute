"""Kuerzt den Namen und die Beschreibung der Sync-Detail-Zeile.

## Warum kuerzen und nicht nur umbrechen

Der Umbruch allein bringt die Zeile in zwei oder drei Zeilen Text auf einem
Bildschirm, auf dem eigentlich eine Zeile gehoert. Bei einer **Einstellung**, die
man unter Entwickleroptionen nur einmal anfasst, ist das zu viel Aufwand fuer den
Nutzer und zu viel Bildschirm fuer den Inhalt.

Kurz ist es ausserdem genauer: Der lange Satz versprach drei Dinge, die an drei
verschiedenen Stellen der Sync-Seite stehen. Der kurze nennt, worum es geht, und
der Fussnote bleibt der Ort fuer das Detail.

Aufruf:

    python3 tool/sync_text_kuerzen.py
"""
import io
import os
import sys

PFAD = os.path.join("ios", "Runner", "NativeShell", "L.swift")


def main():
    text = io.open(PFAD, encoding="utf-8").read()

    alt = '''    static var showSyncDetails: String {
        pick(
            "Zusätzliche Sync-Angaben zeigen",
            "Show additional sync options and information")
    }

    static var showSyncDetailsSubtitle: String {
        pick(
            "Zeigt der Sync-Seite Serverstatus, automatischen Abgleich und die Zahl der übertragenen Einträge",
            "Adds server status, automatic sync and the number of transferred entries to the sync page")
    }'''
    neu = '''    /// Der Name der Zeile – bewusst kurz.
    ///
    /// „Zusätzliche Sync-Angaben zeigen" war eine Anweisung im Titel eines
    /// Schalters. Ein Schalter **ist** die Anweisung; im Titel wiederholt sie
    /// sie sich nur. Der Name sagt, **was** eingestellt wird, und der Schalter
    /// daneben sagt, dass es ein- und ausgeschaltet wird.
    static var showSyncDetails: String {
        pick("Sync-Details", "Sync details")
    }

    /// Die Erklärung darunter – das Detail, das im Namen keinen Platz hat.
    ///
    /// Kurz genug, um neben einem Schalter auf **einer** Zeile zu stehen.
    static var showSyncDetailsSubtitle: String {
        pick(
            "Serverstatus, automatischer Abgleich und übertragene Einträge",
            "Server status, automatic sync and transferred entries")
    }'''

    if alt not in text:
        raise SystemExit("Anker nicht gefunden")
    if text.count(alt) != 1:
        raise SystemExit("Anker nicht eindeutig")

    io.open(PFAD, "w", encoding="utf-8").write(text.replace(alt, neu, 1))
    print("L.swift: Sync-Detail-Zeile gekuerzt.")
    return 0


if __name__ == "__main__":
    sys.exit(main())