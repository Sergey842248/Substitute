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
| └ Anmeldedaten | Flutter |
| └ Plan-Einstellungen | Flutter |
| └ Lehrerkürzel | Flutter |
| └ Sichern & Wiederherstellen | Flutter |
| └ Entwickleroptionen | Flutter |
| └ Krankheitstracker | Flutter |

Die drei nativen Bildschirme sind **Einstellungen**: Sie lesen drei Werte und
schreiben drei Werte. Dafür eine ganze Dart-Isolate hochzufahren wäre Aufwand
ohne Gegenwert – und sie sehen dadurch aus wie die übrigen Apps auf dem Gerät.

Die Abschnitte mit Plan, Suche und Sync bleiben Flutter, weil dort die Arbeit
liegt: XML lesen, Pläne rechnen, synchronisieren, verschlüsseln.

### Was sich am Aufbau ändert

Das Flutter-**Dashboard** gibt es als Reiter nicht mehr; es wurde durch den
Werkzeugkasten ersetzt. Damit wäre die alte Flutter-Einstellungsseite nicht mehr
zu erreichen gewesen – und mit ihr fünf Einträge (Plan-Einstellungen,
Lehrerkürzel, Sicherung, Entwickleroptionen, Anmeldedaten).

Deshalb stehen diese fünf jetzt im Werkzeugkasten und öffnen eine
Flutter-Ansicht **über** der nativen Bildschirmreihe ([FlutterRoute]). Sie sind
damit nicht verschwunden, nur an einen anderen Ort.

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

* die Leiste und die drei Einstellungsbildschirme – sie folgen jetzt iOS statt
  Flutter,
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

Vier Dinge, die man leicht übersieht:

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

4. **Zeilenhöhen in nativen Listen nicht fest vorgeben.**
   Feste Werte sind für irgend eine Sprache zu klein, und was nicht passt, wird
   nicht abgeschnitten, sondern **überlagert**. Die Listen lassen ihre Höhe
   deshalb selbst messen (`UITableView.automaticDimension`) – und nehmen auch
   das Zubehör in den eigenen Stapel auf, weil `accessoryView` vom System über
   den Inhalt gelegt wird und den Platz für den Text nicht abzieht.