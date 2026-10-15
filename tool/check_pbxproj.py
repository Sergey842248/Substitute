"""Prueft ``Runner.xcodeproj/project.pbxproj`` auf die Fehler, mit denen Xcode
das Projekt als beschaedigt zurueckweist.

Auf dieser Maschine gibt es kein ``plutil`` und kein ``xcodebuild``; die Datei
ist auch kein JSON, sondern die alte NeXSTEP-Schreibweise. Deshalb wird sie hier
geparst - und zwar **als Graph**, genau so, wie Xcode sie liest.

## Warum das noetig ist

Der gemeldete Fehler war ``-[PBXFileReference buildPhase]: unrecognized
selector``. Der kommt daher, dass **eine** Kennung **zwei** Objekte beschrieben
hat: Xcode las die zweite Definition als PBXFileReference und versuchte, darauf
``buildPhase`` abzufragen - eine Methode, die nur eine Build-Phase hat.

Genau davor warnt dieses Skript, und es prueft gleich die drei anderen Wege,
auf denen dieselbe Datei kaputt sein kann:

* eine Build-Phase zeigt auf ein ``fileRef``, das es nicht gibt,
* ein ``PBXBuildFile`` steht in **keiner** Build-Phase - es waere im Projekt
  vorhanden, aber nie gebaut,
* eine Build-Phase zeigt auf eine Kennung, die gar nicht definiert ist.

Dazu kommt die Umkehrung, die man beim Suchen leicht vergisst: Eine Datei, die
im Ordner liegt, aber **nicht** in der Gruppe steht, wird nicht gebaut - und das
faellt erst zur Laufzeit auf, wenn eine Klasse fehlt.

Aufruf:  python3 tool/check_pbxproj.py
"""
import collections
import io
import os
import sys

PFAD = "ios/Runner.xcodeproj/project.pbxproj"
ORDNER = os.path.join("ios", "Runner", "NativeShell")

PHASEN = (
    "PBXSourcesBuildPhase",
    "PBXResourcesBuildPhase",
    "PBXFrameworksBuildPhase",
    "PBXCopyFilesBuildPhase",
)

TRENNZEICHEN = ' \t\n\r{}()=;,"'


class Parser:
    """Ein kleiner Leser fuer die NeXSTEP-Schreibweise von Xcode."""

    def __init__(self, text):
        self.text = text
        self.pos = 0

    def fehler(self, was):
        zeile = self.text.count("\n", 0, self.pos) + 1
        raise ValueError("Zeile %d: %s" % (zeile, was))

    def ueberspringen(self):
        while self.pos < len(self.text) and self.text[self.pos] in " \t\n\r":
            self.pos += 1

    def kommentar(self):
        while self.pos < len(self.text) and self.text[self.pos] in " \t\n\r/*":
            if self.text.startswith("//", self.pos):
                while self.pos < len(self.text) and self.text[self.pos] != "\n":
                    self.pos += 1
            elif self.text.startswith("/*", self.pos):
                ende = self.text.find("*/", self.pos + 2)
                if ende < 0:
                    self.fehler("unvollstaendiger Kommentar")
                self.pos = ende + 2
            else:
                self.pos += 1

    def zeichenkette(self):
        self.pos += 1
        teile = []
        while True:
            if self.pos >= len(self.text):
                self.fehler("unvollstaendige Zeichenkette")
            zeichen = self.text[self.pos]
            if zeichen == "\\":
                teile.append(self.text[self.pos + 1])
                self.pos += 2
                continue
            if zeichen == '"':
                self.pos += 1
                return "".join(teile)
            teile.append(zeichen)
            self.pos += 1

    def wort(self):
        self.ueberspringen()
        self.kommentar()
        self.ueberspringen()
        if self.pos >= len(self.text):
            self.fehler("unerwartetes Ende")
        zeichen = self.text[self.pos]
        if zeichen in "{}()=;,":
            self.pos += 1
            return zeichen
        if zeichen == '"':
            return self.zeichenkette()
        anfang = self.pos
        while self.pos < len(self.text) and self.text[self.pos] not in TRENNZEICHEN:
            self.pos += 1
        if anfang == self.pos:
            self.fehler("leeres Wort an %r" % self.text[anfang:anfang + 20])
        return self.text[anfang:self.pos]

    def liste(self):
        """Liest eine Liste ``(a, b, c)`` - auch die leere.

        Die leere steht in dieser Datei als ``(`` und ``)`` auf **zwei** Zeilen
        (siehe ``PBXCopyFilesBuildPhase``). Sie ist deshalb kein Randfall: Wer
        nur den Fall "Klammer, Inhalt, Klammer" kennt, stolpert genau dort.
        """
        self.pos += 1
        eintraege = []
        while True:
            self.ueberspringen()
            self.kommentar()
            self.ueberspringen()
            if self.pos >= len(self.text):
                self.fehler("unvollstaendige Liste")
            if self.text[self.pos] == ")":
                self.pos += 1
                return eintraege
            eintraege.append(self.objekt())
            self.ueberspringen()
            self.kommentar()
            self.ueberspringen()
            if self.pos < len(self.text) and self.text[self.pos] == ",":
                self.pos += 1

    def objekt(self):
        self.ueberspringen()
        self.kommentar()
        self.ueberspringen()
        if self.pos >= len(self.text):
            self.fehler("unerwartetes Ende")
        if self.text[self.pos] == "(":
            return self.liste()
        if self.text[self.pos] != "{":
            return self.wort()
        self.pos += 1
        ergebnis = {}
        while True:
            self.ueberspringen()
            self.kommentar()
            self.ueberspringen()
            if self.pos >= len(self.text):
                self.fehler("unvollstaendiges Objekt")
            if self.text[self.pos] == "}":
                self.pos += 1
                return ergebnis
            schluessel = self.wort()
            self.ueberspringen()
            self.kommentar()
            self.ueberspringen()
            if self.pos >= len(self.text) or self.text[self.pos] != "=":
                self.fehler("erwartet '=' nach %r" % schluessel)
            self.pos += 1
            ergebnis[schluessel] = self.objekt()
            self.ueberspringen()
            self.kommentar()
            self.ueberspringen()
            if self.pos < len(self.text) and self.text[self.pos] == ";":
                self.pos += 1


def kennungVon(eintrag):
    """Die Kennung aus einem Verweis - mit Klammern oder ohne.

    Xcode schreibt dasselbe in zwei Formen: ``{97C146FC ...}`` und
    ``97C146FC ...``. Wer nur eine davon kennt, zaehlt die Verweise der einen
    Sorte nicht und meldet daraufhin falsch "steht in keiner Build-Phase".
    """
    if isinstance(eintrag, dict):
        return eintrag.get("value")
    return eintrag


def pruefe(objects, roh):
    befunde = []
    zeilen = roh.split("\n")

    # 1) Jede Kennung darf **ein** Objekt beschreiben. Genau daran ist der
    #    gemeldete Fehler gescheitert: Xcode las die zweite Definition als
    #    PBXFileReference und rief ``buildPhase`` darauf auf.
    #
    #    Ein Dictionary kann doppelte Kennungen gar nicht darstellen - es gewinnt
    #    einfach die letzte. Deshalb wird hier **zusaetzlich** in den Zeilen
    #    gezaehlt, statt es dem Parser zu ueberlassen.
    for kennung in objects:
        anzahl = sum(1 for z in zeilen if z.startswith("\t\t" + kennung + " "))
        if anzahl > 1:
            befunde.append(
                "Kennung %s beschreibt %d Objekte - Xcode liest das als "
                "unlesbare Datei" % (kennung, anzahl))

    # 2) Jedes ``fileRef`` muss existieren und eine Datei beschreiben.
    #
    #    Neben ``PBXFileReference`` zaehlt ``PBXVariantGroup``: Das ist der zweite
    #    erlaubte Typ, und er steht in dieser Datei an den beiden Storyboards
    #    (``Main``, ``LaunchScreen``) - beide mit mehreren Sprachfassungen.
    #    Wer nur nach ``PBXFileReference`` sucht, meldet deshalb bei jedem Lauf
    #    zwei Befunde, die es nicht gibt.
    erlaubt = ("PBXFileReference", "PBXVariantGroup")
    for kennung, objekt in objects.items():
        if objekt.get("isa") != "PBXBuildFile":
            continue
        ref = objekt.get("fileRef")
        if ref not in objects:
            befunde.append("%s zeigt auf fileRef %s, das es nicht gibt" % (kennung, ref))
        elif objects[ref].get("isa") not in erlaubt:
            befunde.append(
                "%s zeigt als fileRef auf %s, das ein %s ist"
                % (kennung, ref, objects[ref].get("isa")))

    # 3) Jeder PBXBuildFile muss in **einer** Build-Phase stehen.
    in_phase = collections.Counter()
    for objekt in objects.values():
        if objekt.get("isa") in PHASEN:
            for eintrag in objekt.get("files", []):
                in_phase[kennungVon(eintrag)] += 1

    buildfiles = set(k for k, o in objects.items() if o.get("isa") == "PBXBuildFile")
    for kennung in sorted(buildfiles - set(in_phase)):
        befunde.append("%s steht in keiner Build-Phase - gebaut wuerde es nie" % kennung)
    for kennung, anzahl in sorted(in_phase.items()):
        if anzahl > 1:
            befunde.append("%s steht in %d Build-Phasen" % (kennung, anzahl))
        elif kennung not in objects:
            befunde.append("Build-Phase zeigt auf %s, das es nicht gibt" % kennung)

    # 4) Die NativeShell-Gruppe muss vollstaendig sein.
    gruppe = None
    for objekt in objects.values():
        if objekt.get("isa") == "PBXGroup" and objekt.get("path") == "NativeShell":
            gruppe = objekt
    if gruppe is None:
        befunde.append("Die Gruppe NativeShell fehlt")
        return befunde
    if not os.path.isdir(ORDNER):
        befunde.append("Der Ordner %s fehlt" % ORDNER)
        return befunde

    aufgefuehrt = set()
    for eintrag in gruppe.get("children", []):
        kennung = kennungVon(eintrag)
        if kennung in objects and "path" in objects[kennung]:
            aufgefuehrt.add(objects[kennung]["path"])

    for name in sorted(os.listdir(ORDNER)):
        if name.endswith(".swift") and name not in aufgefuehrt:
            befunde.append("%s liegt im Ordner, steht aber nicht in der Gruppe" % name)
    for name in sorted(aufgefuehrt):
        if not os.path.isfile(os.path.join(ORDNER, name)):
            befunde.append("%s steht in der Gruppe, liegt aber nicht im Ordner" % name)

    return befunde


def main():
    if not os.path.isfile(PFAD):
        print("Keine Datei %s - bitte aus dem Projektwurzelverzeichnis starten." % PFAD)
        return 2

    roh = io.open(PFAD, encoding="utf-8").read()
    # Der erste Kommentar (`// !$*UTF8*$!`) steht ausserhalb des Wurzeldiktats.
    try:
        objects = Parser(roh).objekt().get("objects")
        befunde = pruefe(objects, roh)
    except ValueError as fehler:
        print("project.pbxproj ist nicht lesbar: %s" % fehler)
        return 1

    if befunde:
        for befund in befunde:
            print("   %s" % befund)
        print("\n%d Befund(e)." % len(befunde))
        return 1
    print("%d Objekte, keine Befunde." % len(objects))
    return 0


if __name__ == "__main__":
    sys.exit(main())
