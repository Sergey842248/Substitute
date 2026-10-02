# Das Icon

Zwei Quelldateien, alles andere wird daraus berechnet:

| Quelle                             | Wofür                                    |
|------------------------------------|------------------------------------------|
| `assets/icon/icon.svg`             | farbig, randlos — iOS, Web, Play Store, Android vor 26 |
| `assets/icon/icon_mono.svg`        | weiße Form auf durchsichtig — die Ebenen des adaptiven Icons |

Neu erzeugen:

```sh
python3 tool/generate_icons.py
```

Braucht `rsvg-convert` und ImageMagick. Das Skript schreibt alle Dateien an
die Orte, an denen die Frameworks sie erwarten — 19 iOS-Größen, 5
Android-Dichten mal 4 Dateien, Play Store, Web, und das Logo in der App.

## Das Zeichen

**Kalender mit zwei gegenläufigen Pfeilen.** Der Kalender, weil es um den
Stundenplan geht; die Pfeile, weil es um *Vertretung* geht — sie sind das
Zeichen, das auch in der App steht. Das alte Icon war ein Kalender mit sechs
Punkten darin, und die Punkte bedeuteten nichts.

Die Farbe ist die Akzentfarbe der App (`#b878f5` → `#6f37b4`), damit Icon und
App zusammengehören.

## Was die Systeme verlangen — und was daran kaputtgeht

Jede Plattform stellt eigene Regeln, und jede verletzt man leicht:

### Android: der sichere Bereich

Ab Android 26 ist das Icon **adaptiv**: Der Startbildschirm legt eine Ebene als
Hintergrund, eine als Vordergrund und schneidet dann beides auf eine Form
seiner Wahl zu — Kreis, Squircle, auf manchen Geräten ein Vollbild. Im
schlimmsten Fall ist das ein **Kreis von 72dp** Durchmesser, in einer Ebene von
108dp.

Entscheidend ist die **halbe Diagonale** der Zeichnung, nicht ihre Breite. Eine
Zeichnung, die 72dp breit ist, passt in ein Quadrat von 72dp und trotzdem nicht
in einen Kreis: Ihre Ecken liegen bei `√(36² + 28²) = 45,6dp` vom Mittelpunkt,
also 9,6dp zu weit draußen.

Genau das war der gemeldete Fehler — „die Ecken des Kalenders sind
abgeschnitten". Gerechnet für die erste Fassung:

| Größe                              | Wert      |
|------------------------------------|-----------|
| Zeichnung                          | 608 × 564 |
| halbe Diagonale                    | 415 von 1024 |
| umgerechnet                        | 43,7 dp  |
| erlaubt (Kreis 72dp)               | 36 dp     |
| **ragte heraus um**                | **7,7dp** |

#### Die Lösung: ein größerer `viewBox`

Android bekommt **dieselbe** Zeichnung, nur weiter gezoomt. Nicht die Zahlen in
der Quelle werden verändert, sondern der Ausschnitt: `viewBox="-161.7 -181.7
1347.4 1347.4"` zeigt dieselben Koordinaten um den Faktor 0,76 kleiner.

So gibt es **eine** Definition der Form, und der Faktor steht an genau einer
Stelle (`ANDROID_FAKTOR` im Generator). Mittel gehalten wird die Zeichnung
(512, 492), nicht die Fläche — ihr Mittelpunkt liegt wegen der Aufhängungen
ein Stück höher; zählte man auf die Fläche, sähe sie in der Maske zu tief.

0,76 ist nicht das größte zulässige Maß (0,82 wäre es), sondern eines mit Luft.
Der Kreis ist der schlimmste Fall: Eine abgeschnittene Ecke fällt sofort auf,
ein paar Pixel zu viel Abstand bemerkt niemand.

#### Geprüft wird gemessen, nicht gerechnet

`test/icon_android_safe_zone_test.dart` liest die **tatsächliche** erzeugte
Datei und prüft für jedes undurchsichtige Pixel, ob es im erlaubten Kreis
liegt. Nicht die Zahlen der Quelldatei: Die können stimmen und das Ergebnis
trotch falsch sein, wenn beim Erzeugen etwas danebengeht.

Gemessen wurde 38,1dp für die alte Fassung — etwas weniger als die gerechneten
43,7dp, weil die Ecken des Kalenders ja abgerundet sind und die äußerste
Eckpunktlage gar nicht vorkommt.

Der Test prüft auch das **Gegenteil**: Die Zeichnung muss den Kreis zu mindestens
80 % ausfüllen. Ein Icon, das auf die Hälfte schrumpft, ist unbeschnitten und
trotzdem nicht wiederzuerkennen.

#### Auch die alten Icons werden zugeschnitten

Auch vor Android 26 schneiden viele Startbildschirme das Icon auf einen Kreis
zu — der gemeldete Fehler betraf beide Fälle. Deshalb bekommen die alten Icons
dieselbe kleinere Zeichnung. Ihr Hintergrund wird dabei **nicht** aus dem SVG
genommen, sondern als Verlauf darüber gelegt: Sonst wäre die Zeichnung
mitverkleinert worden und am Rand bliebe ein durchsichtiger Streifen, auf dem
Startbildschirm ein heller Rand um das ganze Icon.

### Android: die Monochrom-Ebene

`<monochrome>` in `mipmap-anydpi-v26/ic_launcher.xml` ist die ganze
Unterstützung der **Icons mit Farbschema** (Android 13 und neuer). Das System
nimmt *nur* diese Ebene, färbt sie in die Farbe des Themes und legt sie über den
Hintergrund. Fehlt das Element, bleibt das alte bunte Icon stehen, egal was
der Nutzer eingestellt hat.

Deshalb ist die Monochrom-Ebene **eine einzige Form**: Kalender mit
ausgesparten Pfeilen, sonst nichts. Mehrere gleich helle Flächen nebeneinander
verschmelzen zu einem Fleck — der Unterschied zwischen Zeichnung und
Aussparung bleibt nur erhalten, wenn die Aussparung schlicht **fehlt**.

### Vor Android 26: die Rundung selbst

Bei den alten Icons schneidet nichts zu. Deshalb bekommen sie eine eigene
Form: eine abgerundete Fläche und ein Kreis. Bei einem adaptiven Icon wäre
eine bereits gerundete Kante eine doppelte.

### iOS: kein Alphakanal, keine Rundung

Apple weist Dateien mit Transparenz zurück. Unter **Liquid Glass** ist das
Bild ohnehin eine Fläche, die das System umbricht — eine eigene Rundung im Bild
wäre der schlimmste Fall: zwei Kanten übereinander.

Darum sind alle iOS-Dateien randlos quadratisch, randlos bis in die Ecken, ohne
Alphakanal. Dazu kommen zwei Ausprägungen, die das System ab iOS 18 kennt:
eine für dunkle Anzeige und eine für den Tintenmodus. Beide in 1024 genügen —
das System verkleinert sie selbst.

> Beim Nachtragen dieser beiden Einträge ist einmal etwas gründlich
> schiefgegangen: Der Eintrag für das **helle** Icon bekam den Dateinamen der
> dunklen Fassung. Damit war das helle Icon nirgends mehr referenziert, und auf
> jedem Gerät mit heller Anzeige stünde das dunkle. Der Eintrag für „normal"
> darf deshalb nie verändert werden — es sind **drei** Einträge für eine Datei.

## Das Logo in der App

`assets/img/logo.png` ist dieselbe Form, aber auf den Inhalt zurechtgeschnitten
und **dunkel**. Dunkel, weil es an zwei Stellen steht, die Verschiedenes
brauchen:

* In der Kopfzeile mit `color: focusColor` — dort wird das Bild eingefärbt und
  nimmt die Textfarbe der App an; die Farbe der Quelldatei ist gleichgültig.
* In einem **QR-Code auf weißem Grund** — dort muss es dunkel sein, sonst wäre
  das Logo im Code weiß auf weiß.

`−trim` ist dabei Pflicht: Ohne den Schnitt bliebe auf der Kopfleiste nur die
Hälfte der bisherigen Größe übrig, denn das Bild sähe in einem quadratischen
Feld mit Rand.

#### Das Logo in der Kopfleiste

Das Bild wird mit **45 × 45** Punkten geladen und `BoxFit.contain` gesetzt.
Es sitzt in einem Feld von 45 × 45 – dem Fleck neben dem Wort „Substitute".

Mit einer Breite von 100 war es mehr als doppelt so breit wie sein Platz und
lief in die Kopfzeile hinein: „Das Logo oben links ist viel zu groß
dargestellt." `BoxFit.contain` lässt das nicht quadratische Logo (608 zu 564)
dabei unverzerrt in dem quadratischen Feld liegen.

`test/header_logo_test.dart` prüft beides: **nicht größer** als das Feld (sonst
läuft es heraus) und **nicht kleiner** als dessen Hälfte (sonst ist es weg). Die
zweite Forderung ist wichtig, weil die naheliegende Reaktion auf „zu groß" —
die Zahl auf 20 zu stellen — das Logo wegräumt statt es zu verkleinern.

### Das Logo im QR-Code

Der QR-Code im Anmeldefeld trägt die Zugangsdaten. Wird er zu dick, scannt ihn
niemand mehr.

Der Baustein bettet das Bild bei **25 % Kantenlänge** ein (`scale: 0.25` in
`pretty_qr_code`) und nutzt die Fehlerkorrektur **H**, die rund **30 %** der
Codefläche wiederherstellen kann. Das neue Logo ist gefüllt, das alte war eine
Kontur — die schwarze Fläche darin ist also gewachsen.

Deshalb wird das **gemessen** (`test/logo_qr_test.dart`), nicht geschätzt: Der
Test dekodiert das PNG, zählt die schwarzen Pixel und rechnet
`0,25² × Anteil`. Aktuell:

| Größe                                    | Wert        |
|------------------------------------------|-------------|
| schwarze Fläche im Logo                  | 72 %        |
| davon im QR verdeckt                     | **4,5 %**   |
| Fehlerkorrektur H verkraftet             | ~30 %       |

Eine Änderung am Logo, die diese Zahl über 30 % hebt, macht den Code
unzuverlässig — und der Test sagt es, bevor jemand mit dem Telefon vor der Tür
steht.

## Ein Fehler, der beim Bauen auffiel

Die Hintergrundebene des adaptiven Icons (`drawable/ic_launcher_background.xml`)
war eine Gruppe mit `android:scaleX="0"`. Sie zeichnete **nichts** — das Icon
hatte über keinen Hintergrund, und was man sah, war das Zeichen auf dem, was
der Startbildschirm dahinter zeigt.

Ein zweiter Fehler steckte im Generator: Er setzte den Alphakanal auf 100 %
fest, um ihn „vorhanden" zu machen. Damit wurde jede Pixel undurchsichtig —
auch die, die durchsichtig sein sollten. Die Ebenen waren schwarze Quadrate mit
weißem Zeichen statt eines Zeichens auf durchsichtigem Grund.

Und ein dritter kam vom Android-Build: In der Vektorzeichnung fehlte das `#`
vor dem Farbwert (`FFB878F5` statt `#FFB878F5`), und der Ressourcen-Linker
lehnte die Datei erst **beim Bauen des APKs** ab — nicht beim Lesen.

## Was man selbst prüfen sollte

Der Generator prüft nichts von dem, was nur das Gerät zeigt. Diese drei Dinge
bleiben Sache des Auges:

1. **Der Startbildschirm.** Ist die Form rund, eckig oder vollflächig
   zugeschnitten? Passt das Zeichen in den zugeschnittenen Bereich?
2. **Ein Gerät mit Farbschema** (Android 13+, oder „Im Tintenmodus färben"):
   Erscheint das Icon in der Themenfarbe, oder steht das bunte?
3. **Ein iPhone mit iOS 26:** Trägt das Glas die Kanten, oder sieht man meine
   eigene?