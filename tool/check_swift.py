"""Prueft die Swift-Dateien der nativen Schale auf Syntaxschaden.

Ohne Swift-Werkzeug auf dieser Maschine bleibt nur strukturelle Pruefung:
Klammern muessen sich aufloesen, und Kommentare/Zeichenketten duerfen nicht
mitzaehlen. Zusaetzlich wird nach den Mustern gesucht, die bei einem
abgebrochenen Schreibvorgang zurueckbleiben - etwa zwei schliessende Klammern
auf einer Zeile, die nicht zusammengehoeren.

Verglichen wird mit dem Stand in Git. Was dort schon so stand, wird nicht
gemeldet: Dieser Bildschirm soll **neue** Schaeden finden, nicht alte.

Aufruf:  python3 tool/check_swift.py
"""
import io
import os
import re
import subprocess
import sys

ORDNER = "ios/Runner/NativeShell"
PFAD = os.path.join(ORDNER, "%s")

# Muster, die bei einem abgebrochenen Schreibvorgang zurueckbleiben.
# Geprueft wird nur **echter Code** - Kommentare und Zeichenketten nicht.
SCHADEN = [
    ("zwei schliessende Klammern mit Abstand", re.compile(r"\}\s{2,}[}\)\]]")),
    ("drei schliessende Klammern", re.compile(r"\}\s*\)\s*\)")),
    ("[weak self] im Rumpf einer Funktion",
     re.compile(r"\{\s*\[weak self\]\s+(let|var|return|guard|if|for|while|self\.)")),
    ("Backtick nach Zuweisung", re.compile(r"=\s{2,}`")),
    # Mit Leerzeichen dazwischen: `0...23` ist ein Bereich und kein Schaden.
    ("dreifacher Punkt", re.compile(r"\.\s+\.\s+\.")),
    ("Kommentar mitten im Ausdruck", re.compile(r"\{\s*//")),
    ("Wort doppelt mit Grossbuchstaben", re.compile(r"\b([a-z]+[A-Z][a-zA-Z]*)\1\b")),
    ("Argument-Beschriftung mit Unterstrich", re.compile(r"\(\s*_[A-Z]\w*\s+\w+\s*:")),
]

# Ein Bezeichner, der aus zwei bzw. drei gleichen Haelften besteht. Beides kommt
# vor, je nachdem, wie oft dieselbe Ersetzung gegriffen hat - deshalb beide Muster.
DOPPELT = re.compile(r"\b([A-Za-z_]\w{2,}?)\1\b")
DREIFACH = re.compile(r"\b([A-Za-z_]\w{2,}?)\1\1\b")

# Woerter, bei denen eine Wiederholung **normal** ist: `nennen` ist ein Wort,
# `ffffff` ein Farbwert, `did`/`had` englische Verben. Ohne diese Liste meldet
# das Skript bei jedem Lauf dasselbe, und man hoert auf, ihm zu glauben.
NICHT_VERDAECHTIG = {
    "nenn", "nen", "ffffff", "ffff", "did", "had", "that", "them", "Int", "aa",
    "ab", "ad", "an", "at", "ba", "da", "id", "in", "is", "it", "so", "to", "up",
}

# `L` heisst nicht `l`, und `AppStore` ist nicht `appStore`: Beide Typen werden
# haeufig genug falsch geschrieben, dass ein Tippfehler hier nicht auffaellt.
TYPEN_MIT_MEMBERN = (
    "AppStore", "Appearance", "AppearanceObserver", "ConfigBackupStore",
    "TeacherShortsStore", "KursParser", "L", "Meldung", "NativeShellBridge",
)


def maske(text):
    """Ersetzt Kommentare und Zeichenketten durch Leerzeichen.

    Alles, was danach noch uebrig ist, ist echter Code - und nur darauf sind
    die Muster sinnvoll anwendbar.
    """
    aus = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            aus.append('"')
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    aus.append("  ")
                    i += 2
                    continue
                aus.append('"')
                if text[i] == '"':
                    i += 1
                    break
                if text[i] == "\n":
                    aus.append("\n")
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                aus.append(" ")
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            aus.append("  ")
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                aus.append("\n" if text[i] == "\n" else " ")
                i += 1
            aus.append("  ")
            i += 2
            continue
        aus.append(c)
        i += 1
    return "".join(aus)


PAARE = {"}": "{", ")": "(", "]": "["}


def befunde(text):
    """Alle Schaeden in `text` als Menge aus (Zeile, Beschreibung)."""
    code = maske(text)
    gefunden = set()
    stapel = []
    zeile = 1

    for pos, c in enumerate(code):
        if c == "\n":
            zeile += 1
            continue
        if c == "#":
            # Alles nach einer Raute am Zeilenanfang ist Kommentar - auch wenn
            # es nicht `//` ist. (Nur Sicherheitsnetz; die Raute kommt in
            # Swift-Dateien nicht vor.)
            continue
        if c in "{([":
            stapel.append((c, zeile))
        elif c in "})]":
            if not stapel:
                gefunden.add((zeile, "unerwartetes '%s'" % c))
            else:
                offen, offenZeile = stapel.pop()
                if offen != PAARE[c]:
                    gefunden.add(
                        (zeile, "'%s' schliesst '%s' aus Zeile %d"
                         % (c, offen, offenZeile)))
    for offen, offenZeile in stapel:
        gefunden.add((offenZeile, "'%s' wird nie geschlossen" % offen))

    for nummer, roh in enumerate(code.split("\n"), 1):
        for name, muster in SCHADEN:
            if muster.search(roh):
                gefunden.add((nummer, "Muster '%s'" % name))

    gefunden |= addsubview_befunde(text)
    gefunden |= bezeichner_befunde(text)
    return gefunden


def bezeichner_befunde(text):
    """Bezeichner, die es nicht gibt, und Bezeichner mit verdoppelten Haelften.

    ## Warum das hier und nicht im Compiler

    Der gemeldete Absturz war `self.zeigezeigezeige(...)`: derselbe Aufruf an
    **drei** Stellen, weil dieselbe Ersetzung dreimal angewendet wurde. Ein
    Compiler sagt dazu klar, was fehlt - aber nur jemand, der den Text liest,
    sieht, dass es **drei** sind und nicht einer.

    Beide Muster sind hier billig und ohne Fremdwerkzeuge lauffaehig, und sie
    fangen die Fehlerklasse, die beim Bearbeiten durch Ersetzen entsteht:
    ein Bezeichner, der zwar aehnlich aussieht, aber nicht mehr aufloesbar ist.
    """
    gefunden = set()
    zeilen = text.split("\n")

    # 1) Bezeichner, die aus mehreren gleichen Haelften bestehen.
    #
    # Zwei Haelften (`zeigezeige`, `vollstaendigvollstaendig`) und drei
    # (`zeigezeigezeige`) kommen beide vor - je nachdem, wie oft dieselbe
    # Ersetzung gegriffen hat. Deshalb **beide** Faelle, und nicht nur einer.
    for nummer, roh in enumerate(zeilen, 1):
        s = roh.strip()
        if s.startswith("//"):
            continue
        for muster in (DOPPELT, DREIFACH):
            for m in muster.finditer(roh):
                if m.group(1) in NICHT_VERDAECHTIG:
                    continue
                gefunden.add((nummer, "Bezeichner %r ist mehrfach hintereinander "
                                       "geschrieben" % m.group(0)))
                break
            else:
                continue
            break

    # 2) `self.<name>` und `<Typ>.<name>` muessen etwas finden, das es gibt.
    bekannt = _deklarationen()
    for nummer, roh in enumerate(zeilen, 1):
        s = roh.strip()
        if s.startswith("//"):
            continue
        for m in re.finditer(r"\bself\.(\w+)", roh):
            name = m.group(1)
            if name not in bekannt["eigen"] and name not in bekannt["global"]:
                gefunden.add((nummer, "self.%s gibt es nicht" % name))
        for m in re.finditer(r"\b(%s)\.(\w+)" % "|".join(TYPEN_MIT_MEMBERN), roh):
            typ, name = m.group(1), m.group(2)
            if typ == "L":
                if name not in bekannt["l"]:
                    gefunden.add((nummer, "L.%s gibt es nicht" % name))
            elif name not in bekannt["eigen"] and name not in bekannt["global"]:
                # **Jeder** der genannten Typen, nicht nur die ersten vier: Eine
                # Liste, die `AppStore` und `Appearance` kennt, aber
                # `ConfigBackupStore` uebersieht, meldet einen Tippfehler in
                # `baueExport` nicht - und genau dort stand einer.
                gefunden.add((nummer, "%s.%s gibt es nicht" % (typ, name)))
    return gefunden


def _deklarationen():
    """Alle Namen, die es irgendwo im Runner-Ziel geben kann.

    Gesammelt wird bewusst ueber **alle** Swift-Dateien des Ziels und nicht
    nur ueber die gepruefte: Eine Unterklasse darf jeden Namen benutzen, den
    ihre Oberklasse hat - und die steht in einer anderen Datei.
    """
    if _deklarationen.cache is not None:
        return _deklarationen.cache

    global_ = set()
    l_namen = set()
    eigen = set()

    if not os.path.isdir(ORDNER):
        _deklarationen.cache = {"global": global_, "l": l_namen, "eigen": eigen}
        return _deklarationen.cache

    for name in sorted(os.listdir(ORDNER)):
        if not name.endswith(".swift"):
            continue
        z = io.open(PFAD % name, encoding="utf-8").read()

        global_ |= set(re.findall(
            r"^\s*(?:@[\w()., ]+\s+)?(?:public |internal |private |fileprivate |"
            r"open |final |static |class |override |mutating |lazy )*"
            r"(?:class|struct|enum|protocol|actor|typealias)\s+(\w+)", z, re.M))
        global_ |= set(re.findall(
            r"^\s*(?:@[\w()., ]+\s+)?(?:public |internal |private |fileprivate |"
            r"open |final |static |class |override |mutating |lazy )*"
            r"(?:func|var|let)\s+(\w+)", z, re.M))
        # Enum-Faelle und -Methoden zaehlen fuer `L.` mit.
        global_ |= set(re.findall(r"^\s*case\s+([A-Za-z]\w*)", z, re.M))
        l_namen |= set(re.findall(r"^\s*static\s+(?:var|let|func)\s+(\w+)", z, re.M))
        # Alles, was irgendwo deklariert ist, ist fuer `self.` verwendbar.
        eigen |= set(re.findall(r"\b(?:var|let|func)\s+(\w+)", z))

    _deklarationen.cache = {"global": global_, "l": l_namen, "eigen": eigen}
    return _deklarationen.cache


_deklarationen.cache = None


def addsubview_befunde(text):
    """Views, die per `addSubview` ohne Auto Layout eingesetzt werden.

    ## Warum das ein Fehler ist

    Ein programmatisch erzeugtes `UIView` hat von sich aus
    `translatesAutoresizingMaskIntoConstraints = true`. Dann legt es der Rahmen
    fest, und die Vorgaben zwischen ihm und seinen Geschwistern werden ignoriert.

    Der Schaden sieht nicht nach einer falschen Groesse aus, sondern nach gar
    keinem Layout: Die Zeile bekommt ihre Hoehe von niemandem mehr, faellt auf den
    Inhalt zusammen - und mehrere solche Zeilen liegen **uebereinander**.

    ## Warum Stapel ausgenommen sind

    `addArrangedSubview` schaltet die Vorgabe selbst ab - dort ist nichts zu tun.
    Wer eine Ansicht **zuerst** in den Stapel und **danach** per `addSubview`
    einhaengt, wird nicht gemeldet; dafuer gibt es zu viele Wege, und ein
    Fehlalarm waere schlimmer als eine verschwundene Warnung.
    """
    gefunden = set()
    zeilen = text.split("\n")

    im_stapel = set()
    for roh in zeilen:
        for name in re.findall(r"addArrangedSubview\(\s*([A-Za-z_]\w*)", roh):
            im_stapel.add(name)

    muster = re.compile(r"\.addSubview\(\s*([A-Za-z_]\w*)\s*\)")
    for nummer, roh in enumerate(zeilen, 1):
        for name in muster.findall(roh):
            if name in im_stapel:
                continue
            if re.search(
                    re.escape(name) + r"\.translatesAutoresizingMaskIntoConstraints",
                    text):
                continue
            gefunden.add(
                (nummer,
                 "'%s' per addSubview ohne translatesAutoresizingMaskIntoConstraints"
                 % name))
    return gefunden


def stand_in_git(name):
    """Der Inhalt von HEAD, oder None bei einer neuen Datei."""
    try:
        ergebnis = subprocess.run(
            ["git", "show", "HEAD:" + PFAD % name],
            capture_output=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    if ergebnis.returncode != 0:
        return None
    return ergebnis.stdout.decode("utf-8", "replace")


def main():
    if not os.path.isdir(ORDNER):
        print("Kein Ordner %s - bitte aus dem Projektwurzelverzeichnis starten."
              % ORDNER)
        return 2

    dateien = sorted(f for f in os.listdir(ORDNER) if f.endswith(".swift"))
    sauber = 0
    for name in dateien:
        neu = befunde(io.open(PFAD % name, encoding="utf-8").read())
        alt = stand_in_git(name)
        alt_befunde = befunde(alt) if alt is not None else set()
        # Was schon in HEAD so stand, zaehlt nicht als neuer Schaden.
        neu = {b for b in neu
               if not any(b[0] == a[0] for a in alt_befunde)}
        if neu:
            print("%s" % name)
            for nummer, was in sorted(neu):
                print("   Zeile %4d  %s" % (nummer, was))
            print("")
        else:
            sauber += 1

    print("%d von %d Dateien ohne neuen Befund." % (sauber, len(dateien)))
    return 0 if sauber == len(dateien) else 1


if __name__ == "__main__":
    sys.exit(main())