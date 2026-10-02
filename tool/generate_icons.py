#!/usr/bin/env python3
"""Erzeugt alle Icon-Dateien der App aus zwei Quell-SVGs.

Warum ein Skript statt einer Anleitung
--------------------------------------

Ein Icon ist an vielen Orten gleichzeitig, in vielen Groessen und in
mehreren Formaten: Android alt (zwei Formen), Android ab 26 (drei Ebenen),
iOS (19 Groessen), Play Store, Web. Wer das von Hand pflegt, bekommt es an
den Orten nicht gleichzeitig auseinander – und merkt es erst, wenn ein Gerät
etwas anderes zeigt als der Bildschirm neben dem Telefon.

Deshalb liegen hier **zwei** Quellen, und alles andere wird daraus berechnet:

* ``assets/icon/icon.svg``      – farbig, randlos (iOS, Web, Play Store, Android alt)
* ``assets/icon/icon_mono.svg`` – weisse Form auf durchsichtig (Android-Ebenen)

Verwendet werden ``rsvg-convert`` und ImageMagick.

Aufrufen::

    python3 tool/generate_icons.py
"""

import io
import json
import os
import subprocess
import sys

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(WURZEL, 'assets', 'icon', 'icon.svg')
MONO = os.path.join(WURZEL, 'assets', 'icon', 'icon_mono.svg')
ANDROID = os.path.join(WURZEL, 'android', 'app', 'src', 'main')
IOS = os.path.join(WURZEL, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
WEB = os.path.join(WURZEL, 'web', 'icons')

# Die Android-Dichten: mdpi = 1x, xxhdpi = 4x.
DICHTEN = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

# Die beiden Farben des Verlaufs, als Words und als ARGB fuer die
# Vektorzeichnung von Android.
VERLAUF_OBEN = '#b878f5'
VERLAUF_UNTEN = '#6f37b4'


# Wie weit die Zeichnung fuer Android zuruecktreten muss.
#
# Android schneidet das adaptive Icon auf eine Form seiner Wahl zu, im
# schlimmsten Fall einen Kreis von **72dp** Durchmesser – das sind 33 % des
# Randes einer 108dp-Ebene. Die Zeichnung muss also in einen Kreis von 72dp
# passen, nicht nur in ein Quadrat.
#
# An den Ecken gemessen: Die Zeichnung ist 608 breit und 564 hoch, ihre halbe
# Diagonale liegt bei 415 von 1024 – das sind 43,7dp. Die Maske laesst 36dp zu,
# also **ragten die Ecken 7,7dp heraus** und wurden abgeschnitten.
#
# 0,76 ist nicht das groesste zulaessige Mass (0,82 waere es), sondern eines
# mit Luft: Der Kreis ist der schlimmste Fall, eine abgeschnittene Ecke faellt
# sofort auf, ein paar Pixel zu viel Abstand bemerkt niemand.
ANDROID_FAKTOR = 0.76


def android_viewbox():
    """Der ``viewBox``, mit dem dieselbe Zeichnung in den Kreis passt.

    Der Trick: **nicht** die Zeichnung veraendern, sondern den Ausschnitt. Ein
    groesserer ``viewBox`` zeigt dieselben Koordinaten kleiner – die Zahlen in
    der Quelle bleiben dieselben, es gibt nur eine einzige Definition der Form.

    Mittig gehalten wird die **Zeichnung** (512, 492), nicht die Flaeche: Ihr
    Mittelpunkt liegt wegen der Aufhaengungen ein Stueck hoeher. Zaehlte man
    auf die Flaeche, saehe die Zeichnung in der Maske etwas zu tief.
    """
    window = 1024 / ANDROID_FAKTOR
    return (f'{512 - window / 2:.1f} {492 - window / 2:.1f} '
            f'{window:.1f} {window:.1f}')


def android_ebene(quelle, ziel):
    """Legt eine Kopie der Zeichnung an, die in die Maske passt.

    Kein zweiter Abwasch derselben Zahlen: Es wird nur die erste Zeile
    ersetzt, in der der ``viewBox`` steht.
    """
    text = io.open(quelle, encoding='utf-8').read()
    alt = 'viewBox="0 0 1024 1024"'
    assert alt in text, f'{quelle}: viewBox nicht gefunden'
    text = text.replace(alt, f'viewBox="{android_viewbox()}"', 1)
    with open(ziel, 'w') as f:
        f.write(text)
    return ziel


def rsvg(quelle, groesse, ziel, randlos=False):
    """Rendert ein SVG in genau der geforderten Groesse.

    ``randlos`` heisst: **Kein** Alphakanal. Das brauchen die Dateien, die
    ohne Transparency gebraucht werden – Apple weist ein Icon mit Transparenz
    zurueck, und unter „Liquid Glass" waere ein durchsichtiger Rand eine
    sichtbare Kante.

    Wichtig ist, was hier **nicht** steht: kein Ergaenzen eines Alphakanals
    ueber ``-evaluate set 100%``. Das macht jede Pixel undurchsichtig – auch
    die, die durchsichtig sein sollen. Die Ebenen des adaptiven Icons waren
    dadurch ein schwarzes Quadrat mit weissem Zeichen darauf, statt eines
    Zeichens auf durchsichtigem Grund. Der Alphakanal wird hier deshalb nur
    dort angefasst, wo er nicht gebraucht wird: entfernt.
    """
    subprocess.run(
        ['rsvg-convert', '-w', str(groesse), '-h', str(groesse),
         quelle, '-o', ziel],
        check=True)
    if randlos:
        subprocess.run(
            ['magick', ziel, '-alpha', 'off', ziel],
            check=True)


def maskieren(pfad, radius_anteil, rund):
    """Schneidet die Icon-Ecke auf eine Fläche mit abgerundeten Ecken zu.

    Nur fuer die **alten** Android-Icons. Ab Android 26 schneidet der
    Startbildschirm selbst zu (adaptive icons); dort waere eine bereits
    abgerundete Kante eine doppelte. Die iOS-Dateien bleiben bewusst
    quadratisch und randlos – dort schneidet das System ebenfalls zu, und bei
    „Liquid Glass" ist eine eigene Rundung der schlimmste Fall: zwei Kanten
    uebereinander.
    """
    gross = int(subprocess.run(
        ['magick', 'identify', '-format', '%w', pfad],
        check=True, capture_output=True, text=True).stdout.strip())
    r = int(gross * radius_anteil)
    if rund:
        form = f'circle {gross / 2},{gross / 2} {gross / 2},0'
    else:
        form = f'roundrectangle 0,0,{gross - 1},{gross - 1},{r},{r}'
    maske = f'{pfad}.mask.png'
    subprocess.run(
        ['magick', '-size', f'{gross}x{gross}', 'xc:none',
         '-fill', 'white', '-draw', form, maske],
        check=True)
    subprocess.run(
        ['magick', pfad, maske, '-alpha', 'off',
         '-compose', 'CopyOpacity', '-composite', pfad],
        check=True)
    os.remove(maske)


def webp(pfad):
    """Macht aus einer PNG eine verlustfreie WebP – wie es im Projekt schon war."""
    subprocess.run(
        ['magick', pfad, '-define', 'webp:lossless=true', pfad],
        check=True)


def android():
    print('Android')

    # Die kleinere Fassung der Zeichnung – einmal erzeugt und dann fuer alle
    # Android-Dateien benutzt.
    ebene = android_ebene(MONO, os.path.join(WURZEL, 'assets', 'icon',
                                             '_android_ebene.svg'))

    for dichte, faktor in DICHTEN.items():
        ziel = os.path.join(ANDROID, 'res', f'mipmap-{dichte}')
        os.makedirs(ziel, exist_ok=True)

        # --- Die alten Icons: eine abgerundete Flaeche und ein Kreis. -------
        #
        # Auch sie bekommen die **kleinere** Zeichnung, obwohl der
        # Startbildschirm sie nicht zuschneidet: Viele Startbildschirme
        # schneiden auch alte Icons auf einen Kreis zu, und dann ragten die
        # Ecken des Kalenders genauso heraus wie im adaptiven Icon.
        #
        # Der Hintergrund wird hier nicht aus dem SVG geholt, sondern als
        # Verlauf erzeugt: So nimmt die Zeichnung **nur** den Platz ein, den
        # sie braucht, und der Verlauf laeuft ueber die volle Flaeche. Beim
        # SVG waere die Zeichnung mitverkleinert worden, und am Rand bliebe ein
        # durchsichtiger Streifen – auf dem Startbildschirm ein heller Rand um
        # das ganze Icon.
        for name, anteil, rund in (('ic_launcher', 0.18, False),
                                   ('ic_launcher_round', 0.5, True)):
            gross = int(48 * faktor)
            ziel_png = os.path.join(ziel, name + '.png')
            zeichnung = ziel_png + '.zeichnung.png'
            rsvg(ebene, gross, zeichnung)
            subprocess.run(
                ['magick', '-size', f'{gross}x{gross}',
                 f'gradient:{VERLAUF_OBEN}-{VERLAUF_UNTEN}',
                 zeichnung, '-compose', 'over', '-composite', ziel_png],
                check=True)
            os.remove(zeichnung)
            maskieren(ziel_png, anteil, rund)
            webp(ziel_png)
            os.replace(ziel_png, ziel_png[:-4] + '.webp')

        # --- Die Ebenen des adaptiven Icons. -------------------------------
        # Vorder- und Monochrom-Ebene sind dieselbe weisse Form auf
        # durchsichtigem Grund. Der Unterschied liegt nicht im Bild, sondern
        # darin, dass das System die eine einfärbt und die andere zuschneidet.
        for name in ('ic_launcher_foreground', 'ic_launcher_monochrome'):
            gross = int(108 * faktor)
            ziel_png = os.path.join(ziel, name + '.png')
            rsvg(ebene, gross, ziel_png)  # durchsichtig, bleibt so
            webp(ziel_png)
            os.replace(ziel_png, ziel_png[:-4] + '.webp')

    os.remove(ebene)

    # --- Die Hintergrundebene als Vektor. --------------------------------
    # Sie war eine leere Datei: Eine Gruppe mit `android:scaleX="0"` zeichnet
    # nichts, das adaptive Icon hatte also gar keinen Hintergrund. Der
    # Vektor ist hier die richtige Form, weil er bei jeder Dichte scharf
    # bleibt und den Verlauf ohne eine Bilddatei je Dichte mitbringt.
    hintergrund = os.path.join(ANDROID, 'res', 'drawable', 'ic_launcher_background.xml')
    mit = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Der Grund des adaptiven Icons: derselbe Verlauf wie in
     assets/icon/icon.svg. Als Vektor, damit er bei jeder Dichte scharf ist
     und keine Datei je Bildschirmdichte noetig ist.

     Frueher stand hier eine Gruppe mit android:scaleX="0" – sie zeichnete
     nichts, und das Icon hatte ueberhaupt keinen Hintergrund. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
  <path android:pathData="M0,0h108v108h-108z">
    <aapt:attr name="android:fillColor">
      <gradient
          android:type="linear"
          android:startX="0"
          android:startY="0"
          android:endX="0"
          android:endY="108">
        <item android:offset="0" android:color="#FF{oben}"/>
        <item android:offset="1" android:color="#FF{unten}"/>
      </gradient>
    </aapt:attr>
  </path>
</vector>
'''.format(oben=VERLAUF_OBEN[1:].upper(), unten=VERLAUF_UNTEN[1:].upper())
    # Das `#` vor dem Farbwert ist Pflicht – ohne ihn meldet der Ressourcen-
    # Linker des Android-Projekts "incompatible with attribute color", und
    # zwar erst beim Bauen des APKs. Deshalb wird hier nachgesehen.
    with open(hintergrund, 'w') as f:
        f.write(mit)

    # --- Die zwei XML-Dateien mit der Monochrom-Ebene. --------------------
    # `<monochrome>` ist die ganze Unterstuetzung der Icons mit Farbschema
    # (Android 13 und neuer): Das System nimmt **nur** diese Ebene, faerbt sie
    # in die Farbe des Themes und legt sie ueber den Hintergrund. Ohne das
    # Element bleibt das alte bunte Icon stehen.
    for name in ('ic_launcher', 'ic_launcher_round'):
        pfad = os.path.join(ANDROID, 'res', 'mipmap-anydpi-v26', name + '.xml')
        inhalt = ('<?xml version="1.0" encoding="utf-8"?>\n'
                  '<!-- Die Monochrom-Ebene fuer Icons mit Farbschema. Ohne sie\n'
                  '     nimmt das System das volle Farbicon, auch wenn der Nutzer\n'
                  '     sein Farbschema gewaehlt hat. -->\n'
                  '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                  '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
                  '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                  '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
                  '</adaptive-icon>\n')
        with open(pfad, 'w') as f:
            f.write(inhalt)

    # --- Play Store: 512, quadratisch, ohne Rand. -------------------------
    play = os.path.join(ANDROID, 'ic_launcher-playstore.png')
    rsvg(ICON, 512, play, randlos=True)


def ios():
    print('iOS')
    with open(os.path.join(IOS, 'Contents.json')) as f:
        inhalt = json.load(f)

    # Ueber eine **Kopie** iterieren: Unten werden zwei weitere Eintraege
    # angehaengt (dunkel und getoent). Ueber die Liste selbst zu laufen hiesse,
    # dass man die eigenen Eintraege mitverarbeitet – und zwar endlos.
    for eintrag in list(inhalt['images']):
        datei = eintrag.get('filename')
        if not datei:
            continue
        groesse = int(float(eintrag['size'].split('x')[0]) *
                      int(eintrag['scale'].rstrip('x')))
        # Ohne Alphakanal: Apple weist Dateien mit Transparenz zurueck, und
        # unter „Liquid Glass" wird das Bild ohnehin als eine Fläche
        # behandelt – ein durchsichtiger Rand waere eine sichtbare Kante.
        rsvg(ICON, groesse, os.path.join(IOS, datei), randlos=True)

        # Zusaetzlich die beiden Auspraegungen, die das System ab iOS 18
        # kennt: eine fuer dunkle Anzeige und eine fuer den Tintenmodus. Beide
        # genuegen in 1024 – das System verkleinert sie selbst. Sie sind
        # wichtig fuer die Anpassung an die Umgebung, auf der das System von
        # Apple gar nicht ohne Icon auskommt.
        if groesse == 1024:
            dunkel = eintrag['filename'].replace('.png', '-dark.png')
            rsvg(ICON, 1024, os.path.join(IOS, dunkel), randlos=True)
            subprocess.run(
                ['magick', os.path.join(IOS, dunkel),
                 '-modulate', '78,105,100', os.path.join(IOS, dunkel)],
                check=True)
            getoent = eintrag['filename'].replace('.png', '-tinted.png')
            subprocess.run(
                ['magick', os.path.join(IOS, eintrag['filename']),
                 '-colorspace', 'Gray', os.path.join(IOS, getoent)],
                check=True)
            subprocess.run(
                ['magick', os.path.join(IOS, getoent),
                 '-alpha', 'off', '-background', '#1e1f25', '-flatten',
                 '-alpha', 'off', os.path.join(IOS, getoent)],
                check=True)
            # Der helle Eintrag **bleibt unverändert** und behält seinen
            # Dateinamen: Er ist der, den das System ohne jede Einstellung
            # nimmt. Hätte man ihm den Dateinamen der dunklen Fassung gegeben,
            # wäre das helle Icon nirgends mehr referenziert – auf den Geräten
            # mit heller Anzeige stünde dann die dunkle.
            dunkel_eintrag = dict(eintrag)
            dunkel_eintrag['appearances'] = [
                {'appearance': 'luminosity', 'value': 'dark'}]
            dunkel_eintrag['filename'] = dunkel
            inhalt['images'].append(dunkel_eintrag)

            getoent_eintrag = dict(eintrag)
            getoent_eintrag['appearances'] = [
                {'appearance': 'luminosity', 'value': 'tinted'}]
            getoent_eintrag['filename'] = getoent
            inhalt['images'].append(getoent_eintrag)

    with open(os.path.join(IOS, 'Contents.json'), 'w') as f:
        json.dump(inhalt, f, indent=2)
        f.write('\n')


def logo_in_der_app():
    """``assets/img/logo.png`` – dieselbe Form, aber fuer die App selbst.

    Dort wird das Bild an zwei Stellen benutzt, und die wollen **Verschiedenes**:

    * In der Kopfzeile mit ``color: focusColor`` – dort wird das Bild
      eingefaert und nimmt die Textfarbe der App an. Die Farbe der Quelldatei
      ist gleichgueltig.
    * In einem QR-Code auf weissem Grund – dort muss es **dunkel** sein, sonst
      waere das Logo im Code weiss auf weiss und man koennte es nicht
      scannen.

    Deshalb wird es dunkel erzeugt: Dann stimmt der QR-Code, und die Kopfzeile
    faerbt es ohnehin um.

    ``-trim`` schneidet den leeren Rand weg. Ohne das waere das Zeichen auf der
    Kopfleiste nur halb so gross wie das alte, denn es sitzt in derselben
    quadratischenFlaeche mit Rand – ein Rand, den es dort gar nicht gibt.
    """
    print('Logo in der App')
    ziel = os.path.join(WURZEL, 'assets', 'img', 'logo.png')
    roh = ziel + '.roh.png'
    rsvg(MONO, 1024, roh)
    # **Nur** die Farbkanaele einfärben. `-alpha off` waere falsch: Das loescht
    # die Durchsichtigkeit, der Grund wird schwarz, und `-trim` schneidet dann
    # ein 1x1-Bild heraus. Die Form muss ihre Durchsichtigkeit behalten – das
    # macht erst die Farbe dunkel, nicht das ganze Bild.
    subprocess.run(
        ['magick', roh, '-channel', 'RGB', '-fill', '#2b2b30',
         '-colorize', '100%', '+channel', '-trim', '+repage', ziel],
        check=True)
    os.remove(roh)


def web():
    print('Web')
    os.makedirs(WEB, exist_ok=True)
    # Die PWA-Icons. `maskable` heisst: Der Inhalt muss in der Mitte stehen,
    # weil der Browser an den Raendern zuschneiden kann. Die Zeichnung der
    # App liegt bei 61 % – das reicht.
    for name, groesse in (('Icon-192.png', 192), ('Icon-512.png', 512)):
        rsvg(ICON, groesse, os.path.join(WEB, name), randlos=True)
    for name, groesse in (('Icon-maskable-192.png', 192),
                          ('Icon-maskable-512.png', 512)):
        rsvg(ICON, groesse, os.path.join(WEB, name), randlos=True)


if __name__ == '__main__':
    for pfad in (ICON, MONO):
        if not os.path.exists(pfad):
            sys.exit(f'Fehlt: {pfad}')
    android()
    ios()
    web()
    logo_in_der_app()
    print('Fertig.')