# Die iOS-Oberfläche: native Schale und Flutter-Inhalt

Seit dieser Fassung ist die Navigationsleiste auf iOS **nativ**. Was früher
alles in Flutter war, wird jetzt von `UIKit` gebaut; der Inhalt der Abschnitte
liefert weiterhin Flutter.

## Warum die Leiste jetzt nativ ist

Flutter zeichnet eine Liste von Symbolen und nennt das Navigationsleiste. Sie
kennt aber keine Bildschirmgrenzen, kein „unten ist gerade der Daumen", keine
Ebenenübergänge und kein Material, das iOS selbst dafür vorsieht.

`UITabBarController` kann all das. Deshalb steht jetzt ein solcher im Fenster,
und die Abschnitte der App liegen als echte Ansichtssteuerer darin.

## Die Aufteilung

| Abschnitt | Wer baut ihn |
|---|---|
| Vertretungsplan | Flutter |
| Suche | Flutter |
| Sync & Teilen | Flutter |
| Werkzeuge („Mehr") | nativ (`UIKit`) |
| └ Aussehen | nativ |
| └ Sprache | nativ |
| └ Schulen | nativ |
| └ Anmeldedaten | nativ |
| └ Plan-Einstellungen | nativ |
| &nbsp;&nbsp;├ Stunden-Informationen | nativ |
| &nbsp;&nbsp;├ Vorschau | nativ |
| &nbsp;&nbsp;├ Standard-Planmodus | nativ |
| &nbsp;&nbsp;└ Stundenzeiten | nativ |
| └ Entwickleroptionen | nativ |
| └ Lehrerkürzel | nativnativ |
| └ Sichern & Wiederherstellen | nativnativ |
| └ Krankheitstracker | Flutter |

Fast alles im Werkzeugkasten ist damit **Einstellungen** in `UIKit`: DreizehnDreizehn
Bildschirme, die Speicherwerte lesen und schreiben. Dafür eine ganze
Dart-Isolate hochzufahren wäre Aufwand ohne Gegenwert – und sie sehen dadurch
aus wie die übrigen Apps auf dem Gerät.

Die Abschnitte mit Plan, Suche und Sync bleiben Flutter, weil dort die Arbeit
liegt: XML lesen, Pläne rechnen, synchronisieren, verschlüsseln.

### WasWas dasdas fürfür LehrerkürzelLehrerkürzel undund SicherungSicherung gekostet hatgekostet hat

BeideBeide sindsind erst nativ gewordenerst nativ geworden, nachdemnachdem klarklar war,war, **was****was** siesie wirklichwirklich brauchen.brauchen.
Das ist bei beiden nicht das, was der Name vermuten lässtDas ist bei beiden nicht das, was der Name vermuten lässt:

* **Lehrerkürzel** braucht tatsächlich den Vertretungsplan – aber nicht den
  ganzen. `TeacherShortsStore` holt `Klassen.xml` mit `URLSession` und liest
  daraus die `KKz`-Elemente. Es macht **nicht** das, was `VPlanAPI` macht:
  keine Plankonvertierung, kein Cache, kein Schreiben in den Planspeicher.
  Genau das wäre auch schädlich – der Plan-Reiter holt denselben Plan zur
  selben Zeit, und zwei gleichzeitige Schreibvorgänge in dieselbe Ablage sind
  genau die doppelte Arbeit, die diese Schale vermeiden soll.
* **Sichern & Wiederherstellen** braucht `file_picker` und `share_plus` – und
  die sind dünne Hüllen um `UIDocumentPickerViewController` und
  `UIActivityViewController`. Das Dateiformat selbst steht jetzt in
  `ConfigBackupStore` und ist **zeichengleich** mit `ConfigBackup.dart`.
* **Lehrerkürzel** braucht tatsächlich den Vertretungsplan – aber nicht den
  ganzen. `TeacherShortsStore` holt `Klassen.xml` mit `URLSession` und liest
  daraus die `KKz`-Elemente. Es macht **nicht** das, was `VPlanAPI` macht:
  keine Plankonvertierung, kein Cache, kein Schreiben in den Planspeicher.
  Genau das wäre auch schädlich – der Plan-Reiter holt denselben Plan zur
  selben Zeit, und zwei gleichzeitige Schreibvorgänge in dieselbe Ablage sind
  genau die doppelte Arbeit, die diese Schale vermeiden soll.
* **Sichern & Wiederherstellen** braucht `file_picker` und `share_plus` – und
  die sind dünne Hüllen um `UIDocumentPickerViewController` und
  `UIActivityViewController`. Das Dateiformat selbst steht jetzt in
  `ConfigBackupStore` und ist **zeichengleich** mit `ConfigBackup.dart`.

Der Krankheitstracker ist keine Einstellung, sondern eine eigene Aufgabe
(Unterschriften einsammeln); er steht in der Suche.

### Dieselbe Datei auf beiden Plattformen

Der Grund, warum das Dateiformat in **zwei** Sprachen existiert: Eine Datei, die
auf dem Handy erzeugt wurde, muss auf dem iPhone etwas wiederherstellen – und
umgekehrt. Deshalb ist die Regel (welche Schlüssel gesichert werden, wie
Zugangsdaten beim Ersetzen behandelt werden, wie Dateinamen aussehen) an **einer**
Stelle je Plattform festgeschrieben und nicht über eine Bildschirmdatei verteilt.

Ein Schlüssel, der in `ConfigBackupStore` ergänzt wird, muss in
`ConfigBackup.dart` ergänzt werden. Sonst landet er in einer Hälfte der
Sicherungen und in der anderen nicht – und das merkt niemand, bis jemand auf
einem Gerät einmal das eine und einmal das andere benutzt hat.

Der Krankheitstracker ist keine Einstellung, sondern eine eigene Aufgabe
(Unterschriften einsammeln); er steht in der Suche.

### Dieselbe Datei auf beiden Plattformen

Der Grund, warum das Dateiformat in **zwei** Sprachen existiert: Eine Datei, die
auf dem Handy erzeugt wurde, muss auf dem iPhone etwas wiederherstellen – und
umgekehrt. Deshalb ist die Regel (welche Schlüssel gesichert werden, wie
Zugangsdaten beim Ersetzen behandelt werden, wie Dateinamen aussehen) an **einer**
Stelle je Plattform festgeschrieben und nicht über eine Bildschirmdatei verteilt.

Ein Schlüssel, der in `ConfigBackupStore` ergänzt wird, muss in
`ConfigBackup.dart` ergänzt werden. Sonst landet er in einer Hälfte der
Sicherungen und in der anderen nicht – und das merkt niemand, bis jemand auf
einem Gerät einmal das eine und einmal das andere benutzt hat.

### Was sich am Aufbau ändert

Das Flutter-**Dashboard** gibt es als Reiter nicht mehr; es wurde durch den
Werkzeugkasten ersetzt. Damit wäre die alte Flutter-Einstellungsseite nicht mehr
zu erreichen gewesen – und mit ihr fünf Einträge (Plan-Einstellungen,
Lehrerkürzel, Sicherung, Entwickleroptionen, Anmeldedaten).

Deshalb stehen diese fünf jetzt im Werkzeugkasten,, undund inzwischeninzwischen sind **alle**alle
fünf** native Bildschirme. Sie sind  damit nicht verschwunden, nur an einen

anderen Ort – und aus einer Liste mit fünf gemischten Einträgen ist eine
geworden, in der jede Zeile dasselbe kann: tippen.

## Die Speicherwerte sind dieselben

Die native Seite hält **keinen** eigenen Stand. Sie schreibt in dieselben
`UserDefaults`, die Flutter benutzt, mit demselben `flutter.`-Vorsatz und
derselben Aufteilung nach Schulbereich (`AppStore.swift`).

Das ist der Grund, warum nach dem Umstieg keine Daten neu eingetragen werden
mussten und warum eine Einstellung nicht an zwei Orten auseinanderlaufen kann:
Es gibt nur eine Ablage.

Wenn die eine Seite etwas schreibt, sagt sie der anderen nur **„ich habe etwas
geschrieben"** – nicht, *was*. Die andere liest selbst nach. So kann es nicht
zwei verschiedene Werte für dieselbe Sache geben.

## Jeder Schriebvorgang sagt es beiden Seiten

`AppStore.didWrite()` steht hinter **jedem** Speichern eines nativen
Bildschirms. Es ist keine Kosmetik und keine Höflichkeit – ohne diesen einen
Aufruf ist die Einstellung nachweislich wirkungslos:

Dart liest aus dem **Cache** von `SharedPreferences`, und der Cache kennt nur,
was Dart **selbst** geschrieben hat. Ein Wert, den die native Seite setzt,
existiert für die Flutter-Seite erst, wenn der Cache neu gelesen wird. Tut er
das nicht, steht oben der alte Wert, der Plan rechnet mit dem alten Wert, und
nirgends erscheint ein Fehler. Man stellt etwas um und sieht keine Wirkung.

`didWrite()` erledigt beides: Es sagt den nativen Zuhörern Bescheid
(`settingsDidChange`) und hängt daran `appearanceChanged`, worüber Dart seine
Werte neu holt. Wer einen neuen Bildschirm baut und dort `UserDefaults` schreibt,
ruft es danach auf. Sonst ist der Bildschrm fertig gebaut und wirkungslos.

## Wie die Abschnitte ihre Rolle erfahren

Der Startaufruf jeder Flutter-Ansicht bekommt `--substitute-role=plan`
(davon: `search`, `sync`). Die Dart-Seite liest das in `main()`, **bevor** der
erste Frame gezeichnet wird, und richtet sich danach:

* Plan, Suche und Sync bauen **keine** eigene Navigationsleiste – die steht
  schon da.
* Nur die **Plan-Ansicht** holt im Hintergrund Pläne und startet den Sync.

## Warum nur eine Ansicht den Hintergrund macht

Unter der nativen Schale laufen drei Flutter-Ansichten, jede mit ihrem eigenen
Zustand im Speicher zu. Liefe der Hintergrundauftrag in allen, würde er dreimal
stattfinden: dreimal dieselben Anfragen an den VPlan, dreimal derselbe Sync
gegen denselben Server, dreimal dieselben Dateien geschrieben.

Die Ansichten könnten einander nicht abwehren – jede merkt sich nur, ob **sie**
gerade läuft. Deshalb macht nur eine den Auftrag (`NativeShell.runsBackgroundWork`).

Der Klick auf „Aktualisieren" ist nicht betroffen: Der wirkt in der Ansicht, in
der man ihn gedrückt hat.

## Was das für den Betrieb bedeutet

Der Startbildschirm bleibt derselbe, die Pläne bleiben dieselben, und die
Einstellungen sind dieselben. Neu sind:

* die Leiste und die dreizehndreizehn Einstellungsbildschirme – sie folgen jetzt iOS
  statt Flutter,
* der unterste Bildschirm heißt „Dashboard" und enthält Werkzeuge; Sync hat
  einen eigenen Reiter wie vorher,
* **iOS 15** ist die Mindestversion (vorher 13). Grund sind `UIButton.Configuration`
  und `UISwitch.addAction`, aus denen die neuen Bildschirme bestehen. Betroffen
  sind Geräte vor 2015.

## Ohne die Umstellung zurück

`UIMainStoryboardFile` ist aus `Info.plist` entfernt, weil jetzt das Fenster im
`AppDelegate` entsteht – zwei Stellen, die das Fenster liefern wollen, können
sich nicht beide durchsetzen.

`Main.storyboard` ist deshalb im Projekt **geblieben**, nicht gelöscht. Wer die
native Schale zurückhaben will, setzt die Zeile in `Info.plist` wieder ein –
sonst ist nichts zu tun.

## Die Leiste liegt auf dem Inhalt

Die Leiste schwebt nicht als eigene Schicht über dem Bildschirm, sondern liegt
**auf** dem Inhalt. Drei Angaben sorgen dafür:

* `isTranslucent = false` – eine deckende Leiste kann keinen Inhalt durchlassen,
* der Hintergrund in der Farbe des Inhaltsgrunds,
* `scrollEdgeAppearance = standardAppearance` – das ist die Variante, die das
  System beim Scrollen einsetzt, und sie ist die schwebende.

Damit sie dabei nicht den letzten Eintrag eines Bildschirms verdeckt, braucht
jeder Bildschirm unten einen zusätzlichen Bereich – und dessen Höhe ist
**gemessen**, nicht festgeschrieben (`meldeUeberdeckung()`).

Der Grund fürs Messen: `UITabBarController` verhält sich je iOS-Version
anders. Früher legte es die Leiste unter den Inhalt und kürzte den Bildschirm
darüber – es gab nichts zu überdecken. Neuere Systeme lassen sie darüber
schweben, und der Inhalt reicht bis zum unteren Rand. Eine Zahl im Dart-Code
wäre in der einen Version zu klein und in der anderen zu gross.

## Der Hell-Modus braucht einen Cache-Neulauf

Die native Seite schreibt direkt in `UserDefaults`. Dart liest aber aus dem
**Cache** von `SharedPreferences`, und der kennt nur, was Dart selbst
geschrieben hat.

Deshalb rufen `AppAppearance.reloadTheme` und `AppLanguage.reloadLanguage`
vor dem Lesen `prefs.reload()` auf. Ohne das liest Dart den alten Wert weiter –
und der Hell-Modus bleibt aus, während die Leiste hell wird.

Dasselbe gilt für **alle** anderen Werte, die jetzt native Bildschirme
schreiben – Stundenzeiten, Planmodi, Vorschau-Schalter, Anmeldedaten. Der Aufruf
`reload()` kommt dabei nicht an jeder Stelle einzeln hin: Er hängt an
`appearanceChanged`, und das kommt für **jedes** `didWrite()`. Die obige Zeile
ist deshalb der Sonderfall der Sonderfälle – der Grund, warum sie einmal extra
dasteht, obwohl der allgemeine Weg derselbe ist.

## Die Leiste zeigt nur Symbole

Unter den Symbolen steht **kein Text**. Der gewählte Reiter ist allein an der
Farbe zu erkennen (`tintColor`).

Ein **sichtbarer** Titel ist nicht dasselbe wie ein zugänglicher Name: Ohne
`accessibilityLabel` sagt VoiceOver nur „Button" – und die Leiste ist genau die
Stelle, über die man mit den Augen nichts erfährt. Der Name steht deshalb in
`accessibilityLabel`, auch wenn er nirgends zu sehen ist.

Früher lag hier je Reiter ein `selectedImage`. Mehrere davon – etwa
`magnifyingglass.circle.fill` – gibt es in SF Symbols **nicht**;
`UIImage(systemName:)` liefert dafür `nil`, und `nil` als ausgewähltes Bild
bedeutet, dass der Reiter im aktiven Zustand gar nichts anzeigt. Deshalb nur
noch die Auswahl über die Farbe.

## Ohne Zugangsdaten keine Leiste

Solange kein Benutzername hinterlegt ist, steht die Anmeldeseite über allem, und
die Leiste wird ausgeblendet. Sie taucht wieder auf, sobald
`AppStore.hasCredentials` stimmt.

Geprüft wird das **beim Wiedererwachen der App**, nicht nur bei einer Meldung:
Zugangsdaten werden in Flutter eingetragen, und `settingsChanged` melden nur das
Aussehen und die Sprache.

## Wichtig fürs Bearbeiten

Fünf Dinge, die man leicht übersieht:

1. **Jede neue Flutter-Maschine braucht ihre Programme.**
   `GeneratedPluginRegistrant.register(with:)` im `AppDelegate` gilt nur für die
   Maschine, die iOS von selbst anlegt. Jede hier von Hand erzeugte braucht
   `FlutterEngines.registerPlugins(on:)` – sonst fehlt ihr unter anderem
   `shared_preferences`, und damit jeder gespeicherte Wert.

2. **Eine Einstellung darf nicht auf ihr Ergebnis warten.**
   `NativeShell.notifySettingsChanged()` wird abgeschickt und **nicht**
   abgewartet. Wer darauf wartet, hängt das Umstellen einer Einstellung an
   einem Kanal, der auf Android und in den Tests gar nicht antwortet.

3. **Die Routennamen müssen auf beiden Seiten gleich sein.**
   Die native Seite baut die Route aus der Rolle – und die ist englisch:
   `/abschnitt/search`. Stand in Dart `/abschnitt/suche`, lief der Reiter ins
   Leere und blieb auf „loading...". Prüfbar über
   `test/native_shell_route_test.dart`.

4. **Zeilenhöhen in nativen Listen nicht fest vorgeben – und die Liste messen
   lassen, *wann* sie will.**
   Feste Werte sind für irgend eine Sprache zu klein, und was nicht passt, wird
   nicht abgeschnitten, sondern **überlagert**. Die Listen lassen ihre Höhe
   deshalb selbst messen (`UITableView.automaticDimension`) – und nehmen auch
   das Zubehör in den eigenen Stapel auf, weil `accessoryView` vom System über
   den Inhalt gelegt wird und den Platz für den Text nicht abzieht.

   Dazu drei Dinge, ohne die derselbe Fehler in anderer Gestalt wiederkommt –
   der gemeldete Fehler war: *Die Beschreibung der Optionen ist abgeschnitten,
   je nach Zeile sieht man nur die obere Hälfte oder nur den mittleren Teil.*

   * **`estimatedRowHeight` nicht auf `0` setzen.** `UITableView` setzt die
     Zeilen nach den Schätzwerten und holt die echten Höhen erst danach. Ohne
     Schätzwert legt die Liste Zeilen an, die noch gar nicht gemessen sind, und
     weil die Zelle ihren Inhalt abschneidet, fehlt der Text, der am weitesten
     unten steht. Richtig ist `UITableView.automaticDimension`: die Liste
     schätzt aus dem Inhalt der Zellen, die sie kennt.
   * **Die Umbruchbreite ist die Breite, gegen die gemessen wird.**
     `preferredMaxLayoutWidth` sagt einer mehrzeiligen `UILabel`, **wo** sie
     umbricht; ohne sie misst das Feld gegen eine unendliche Breite und meldet
     eine einzige Zeile. Diese Breite ist aber die der Spalte, und die hängt
     vom Zubehör ab (Schalter, Haken, Menü-Knopf, nichts). `SubtitleCell` fragt
     sie deshalb **im** `systemLayoutSizeFitting` ab – und zwar nach dem Messen
     noch einmal, weil erst danach der Stapel seine endgültige Breite
     durchgerechnet hat. Ein zweiter Durchgang allein reichte nicht: Er mass
     gegen die Breite **vor** dem Messen, also die der vorigen Zeile.
   * **Eine Zeile wird einmal gemessen und behält ihre Höhe.** Ändert sich die
     Breite danach – Drehen, grössere Systemschrift, anderer Knopf daneben –,
     passt der Text nicht mehr. `SubtitleCell.layoutSubviews` meldet die Breite
     deshalb auch während des Zeichnens und fordert über `performBatchUpdates`
     eine neue Messung an, wenn `sizeThatFits` mehr Höhe verlangt, als die Zeile
     hat. Die Bremse `nachmessungen` ist dabei Pflicht: Ohne sie wäre eine
     Zeile, die auch danach nicht passt, eine Endlosschleife aus Messen und
     Layouten.

   * **Der Platz rechts vom Text gehört zur Umbruchbreite – und darf nicht vom
     Zubehör abhängen.** Beim Umschalten einer Auswahl („Automatisch" auf
     „Latest") bekommt die bisher gewählte Zeile ihren Haken weg und die neue
     ihn dazu. Ohne festen Platz wäre die Textspalte der gewählten Zeile 16
     Punkte schmaler als die der übrigen, und eine Erklärung, die genau an der
     Umbruchgrenze lag, brauchte dort plötzlich eine Zeile mehr: Die gewählte
     Zeile sprang nach unten und **alle** Zeilen darunter mit. Deshalb bekommen
     Haken und Pfeil über `SubtitleCell.zubehoerBreite` denselben festen Platz,
     und eine Zeile ohne Auswahl über `SubtitleCell.platzhalter()` denselben
     leeren Platz. Nebenbei zwei Kleinigkeiten, die dazugehören: Der Haken darf
     seine Breite nicht von der Breite des SF Symbols erben (sonst wäre der
     Haken breiter als der Pfeil und die Spalte würde allein davon abhängen,
     welche Art Zubehör eine Zeile trägt), und ein `UIImageView` mit fester
     Breite braucht `contentMode = .scaleAspectFit` – sonst dehnt die
     Vorgabemode `scaleToFill` das Symbol und der Haken sitzt verzerrt da.

5. **Wer von `UserDefaults` schreibt, muss `SharedPreferences.reload()` sagen.**
   Dart liest aus einem Cache, und der kennt nur Darts eigene Schreibvorgänge.
   Jede native Änderung an einer Einstellung, die Dart anzeigt, braucht deshalb
   ein `reload()` auf der Dart-Seite – sonst bleibt der alte Wert stehen, ohne
   dass irgendwo ein Fehler erscheint. Auf der nativen Seite heisst das: nach
   jedem Schreiben `AppStore.didWrite()` aufrufen (siehe oben).

6. **Eingabefelder werden nicht wiederverwendet.**
   `UITableView` gibt Zeellen zum Wiederverwenden frei. Eine Zelle mit einem
   Eingabefeld herauszugeben hiesse: Das Feld, in dem man tippt, gehört plötzlich
   einer anderen Zeile, und der getippte Text verschwindet – ohne Fehler.
   Deshalb baut `FormScreen` für jede Feldzeile eine **neue** Zelle, und der Text
   liegt beim Bildschirm, nicht in der Zelle.

7. **Eine `UITableViewDelegate`-Methode lässt sich nicht überschreiben.**
   Die Delegate-Methoden stehen in einer Erweiterung auf `ListScreen`, und was
   dort steht, kann eine Unterklasse nicht mit `override` ersetzen – der
   Compiler sagt „does not override any method from its superclass", und die
   Aktion fällt still weg. Deshalb gibt es für jede nötige Methode einen Haken
   im Klassenrumpf (`swipeActions(at:)`, `zeileVerschoben(von:nach:)`,
   `reihenfolgeMoeglich`), den die Liste nur abfragt.

8. **Ein QR-Code gehört in ein weisses Feld.**
   Ein Scanner rechnet mit dunkel auf hell. Ein heller Code auf dunklem Grund
   liest sich bei vielen Kameras gar nicht. `QRCodeView` setzt den Code deshalb
   immer in einen weissen Rahmen – auch im dunklen Erscheinungsbild.