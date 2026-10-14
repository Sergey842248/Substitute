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

| Abschnitt | Wer **zeichnet** ihn | Wo die Arbeit liegt |
|---|---|---|
| Vertretungsplan (Übersicht) | nativ (`UIKit`) | Dart |
| └ Plan einer Klasse, Tag/Woche | Flutter | Dart |
| └ Klasse/Person hinzufügen | Flutter | Dart |
| Suche | Flutter | Dart |
| Sync & Teilen (die drei Wege) | nativ (`UIKit`) | Dart |
| └ die Bildschirme dahinter | Flutter | Dart |
| Werkzeuge („Mehr") | nativ (`UIKit`) | – |
| └ Aussehen, Sprache, Schulen | nativ (`UIKit`) | – |
| └ die übrigen Werkzeuge | Flutter | Dart |

Die zweite Spalte ist die **Darstellung**, die dritte die **Logik**. Sie fallen
seit dem Umbau auseinander: Sechs Bildschirme werden von `UIKit` gezeichnet, und
der Stoff für sie kommt trotzdem aus Dart.

## Warum die Darstellung nach iOS zieht und die Logik nicht

Der Stoff liegt in Dart, und er bleibt dort: XML lesen, Pläne rechnen,
synchronisieren, verschlüsseln. Eine zweite Fassung in Swift wäre ein **zweiter
Ort, an dem dieselbe Sache passiert** – und damit genau die Falle, die
`AppStore.swift` auf der anderen Seite vermeidet.

Die **Darstellung** ist etwas anderes. Sie ist eine Liste von Zeilen mit
Gruppen, einem grossen Titel und einem Wischzeichen; dafür ist
`UITableView` gemacht, seit dreissig Jahren. In Flutter war dieselbe Liste ein
Container aus `ListItem` mit einem Knopf am Rand, der dieselbe Aktion ausführte
wie die Zeile selbst – zweimal derselbe Weg pro Eintrag, und nichts sagte,
welcher davon der eigentliche war.

Deshalb gilt die Regel, und sie ist einfach:

> **Zeilen und Bildschirmwechsel sind eine Frage der Oberfläche und gehören nach
> `UIKit`. Werte, Speicher und Netz sind eine Frage der Logik und bleiben in Dart.**

### Wo die Grenze genau liegt – und warum nicht dort, wo man sie zuerst zieht

Die naheliegende Grenze wäre gewesen: „Der Plan ist ein Reiter, also ganz
nativ." Dann stünde der **Plan einer Klasse** in einer Tabelle – mit dem
Wochenraster, den Stundenzeilen, dem Wechsel auf den nächsten Tag und dem
Ausblenden einzelner Kurse. Das ist kein Raster, das sich als Liste beschreiben
lässt, und eine Tabelle dafür wäre ein Rückschritt.

Also ist die Grenze bei der **Übersicht** gezogen: eine Liste von Klassen und
Personen. Das ist eine Liste. Der Plan dahinter ist ein eigener Bildschirm und
bleibt Flutter – mit eigener Leiste, eigenem Zustand und eigener Maschine.

Für „Sync & Teilen" gilt dasselbe in der anderen Richtung: Die Seite ist eine
Liste aus **drei** Zeilen, und alle drei tun dasselbe – einen Bildschirm in
Flutter öffnen. Das ist genau das, wofür sich ein nativer Bildschirm lohnt. Die
Arbeit dahinter (`ShareManager`, `SyncEngine`, `SyncKeys`) bleibt in Dart.

### Home braucht keinen Stoff von Dart

Home ist eine Seite mit Zeilen, die **schon wissen**, wohin sie führen, und einem
Blatt mit Version und Links. Die native Seite weiss beides selbst; es gibt
keinen Wert, den Dart ihr schicken könnte.

Deshalb steht Home in keiner der beiden Listen – nicht in der der gezeichneten
Bildschirme (es wird gezeichnet) und nicht in der der mit Stoff von Dart
(nicht). Ein dritter Fall im Kanal wäre einer, in den nichts geht.

### Was beim Hinzufügen passiert – und warum es den Umweg braucht

Eine Klasse hinzufügen heisst **tippen**: die Liste der Klassen aus dem VPlan
ansehen, eine wählen, ihr einen Namen geben. Dafür braucht es einen Bildschirm,
und Bildschirme kann nur die Seite öffnen, die einen hat.

Dasselbe beim Löschen – nur andersherum: Der Dialog ist **nativ**, mit dem Namen
der Sache und einem roten Knopf. Bestätigt wird er auf der Seite, die den
Bildschirm zeigt, und Dart bekommt danach nur noch den Befehl. Die Frage an den
Menschen stellt das System; die Antwort ist eine Tatsache, keine Frage mehr.

### Die Maschine, die rechnet, während niemand hinsieht

Beim Start holt **eine** Ansicht die Pläne und hängt sich an den Sync
(`NativeShell.runsBackgroundWork`). Vorher war das die Plan-Ansicht, weil sie
als einzige sichtbar war und nebenbei rechnen konnte.

Jetzt ist der Plan-Abschnitt nativ – dort gibt es keine Flutter-Ansicht mehr,
die rechnen könnte. Ohne eine eigene Maschine für diesen Zweck (`NativeScreenEngine`)
würde beim Start **gar nichts** passieren: keine Pläne, kein Sync, und die
Vorschauen stünden auf dem Stand von gestern.

Das ist der Fehler, der am schwersten zu finden ist, weil **alles funktioniert**:
Die Klassen stehen da, die Pläne sind da – nur eben alt. Die Maschine baut ihren
Bildschirm und schickt die Werte nach oben; was sie selbst malt, sieht niemand,
und genau das ist gewollt.

Insgesamt steht damit **eine** Maschine weniger im Speicher als vorher: statt
zwei sichtbarer Reiter-Maschinen eine rechnende ohne Bildschirm und je
aufgetapstem Plan eine eigene.

## Was die drei Bildschirme neu bekommen haben

* **Kopfzeile.** Sie kommt von `UINavigationController`, mit grossem Titel. Der
  Rahmen aus `main.dart` – ein Container über 20 % der Bildschirmhöhe, mit
  runden Ecken und dem Wort „Substitute“ – ist unter der nativen Schale weg. Er
  hing auf **jedem** Bildschirm und war das, woran man die App als Flutter-App
  erkannt hat, nicht an den Listen.
* **Zeilen mit einem Weg statt zwei.** Die ganze Zeile führt weiter, und rechts
  steht ein **Pfeil**, der genau das sagt. Vorher gab es die Zeile **und** einen
  Knopf am Rand, der dasselbe tat.
* **Wischen zum Löschen**, mit einem Dialog, der den **Namen** der Sache nennt.
  Wer „Klasse 8a“ liest, weiss, was er verliert; wer „Löschen“ neben einer Zeile
  sieht, die er nicht kennt, weiss es nicht.
* **Das Hinzufügen unten**, als eigener Weg und nicht als weiterer Eintrag. Oben
  würde man es für einen Eintrag halten.
* **Das Blatt mit den Angaben zur App** ist jetzt eine Seite mit Zeilen und
  einer Fussnote. Unterstrichene Links waren ein **Web**-Muster; auf iOS sind das
  Zeilen mit einem Pfeil daneben.

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

Der Startaufruf jeder Flutter-Ansicht bekommt `--substitute-role=…`:

* `plan` – die Maschine, aus der die nativen Bildschirme ihre Werte holen. Sie
  ist zugleich die, die im Hintergrund Pläne holt und den Sync startet.
* `search` – der Reiter „Suche“, der als einziger noch eine Flutter-Ansicht
  **als Inhalt** hat.
* `tool` – jeder Bildschirm, der aus einem nativen Bildschirm heraus geöffnet
  wird: der Plan einer Klasse, die drei Wege hinter „Sync & Teilen“, das
  Hinzufügen einer Klasse oder einer Person.

Die Dart-Seite liest das in `main()`, **bevor** der erste Frame gezeichnet wird,
und richtet sich danach:

* Alle bauen **keine** eigene Navigationsleiste – die steht schon da, oder
  `UIKit` hat sie für diesen Bildschirm ausdrücklich ausgeblendet.
* Nur die Ansicht mit der Rolle `plan` holt im Hintergrund Pläne und startet
  den Sync.

## Warum nur eine Ansicht den Hintergrund macht

Unter der nativen Schale laufen mehrere Flutter-Ansichten, jede mit ihrem eigenen
Zustand im Speicher zu – die Suche, die rechnende Maschine und jeder Bildschirm,
den man aus einem nativen Bildschirm geöffnet hat. Liefe der Hintergrundauftrag in
allen, würde er mehrfach stattfinden: mehrfach dieselben Anfragen an den VPlan,
mehrfach derselbe Sync gegen denselben Server, mehrfach dieselben Dateien
geschrieben.

Die Ansichten könnten einander nicht abwehren – jede merkt sich nur, ob **sie**
gerade läuft. Deshalb macht nur eine den Auftrag (`NativeShell.runsBackgroundWork`).

Der Klick auf „Aktualisieren" ist nicht betroffen: Der wirkt in der Ansicht, in
der man ihn gedrückt hat.

## Was das für den Betrieb bedeutet

Der Startbildschirm bleibt derselbe, die Pläne bleiben dieselben, und die
Einstellungen sind dieselben. Neu sind:

* die Leiste, die Kopfzeile über jedem Abschnitt und die Listen von **Home**,
  **Plan** und **Sync & Teilen** – sie folgen jetzt iOS statt Flutter,
* der Rahmen um jeden Abschnitt ist unter der nativen Schale weg; Android und
  im Web sehen ihn genau wie vorher,
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

4. **Zeilenhöhen in nativen Listen nicht fest vorgeben.**
   Feste Werte sind für irgend eine Sprache zu klein, und was nicht passt, wird
   nicht abgeschnitten, sondern **überlagert**. Die Listen lassen ihre Höhe
   deshalb selbst messen (`UITableView.automaticDimension`) – und nehmen auch
   das Zubehör in den eigenen Stapel auf, weil `accessoryView` vom System über
   den Inhalt gelegt wird und den Platz für den Text nicht abzieht.

5. **Wer von `UserDefaults` schreibt, muss `SharedPreferences.reload()` sagen.**
   Dart liest aus einem Cache, und der kennt nur Darts eigene Schreibvorgänge.
   Jede native Änderung an einer Einstellung, die Dart anzeigt, braucht deshalb
   ein `reload()` auf der Dart-Seite – sonst bleibt der alte Wert stehen, ohne
   dass irgendwo ein Fehler erscheint.

6. **Zeilen und Bildschirmwechsel kommen aus `ScreenBridge`, Stoff aus Dart.**
   Wird eine Zeile eines nativen Bildschirms neu, muss Dart sie schicken
   (`publish`) – die native Seite kennt die Liste nicht. Wird eine Zeile
   angezeigt, braucht sie `datenQuelle`, sonst zeichnet sie sich nur beim ersten
   Erscheinen und danach nie wieder.

7. **Eine Aktion ohne Zieltu ist kein Fehler, sondern bleibt liegen.**
   `ScreenBridge.action` wartet auf keine Antwort, und das ist Absicht: Was beim
   Tippen passiert, entscheidet Dart, und ein Ergebnis käme als zweite Quelle für
   denselben Fehler zurück. Wer hier ein `await` einbaut, hängt das Tippen an
   einen Kanal, der unter Android gar nicht antwortet.

8. **Die Kopfzeile verschwindet, sobald Flutter oben steht.**
   `NativeSectionHost` blendet sie aus, wenn die oberste Ansicht eine
   `FlutterViewController` ist – Flutter bringt dort seine eigene mit. Das ist
   im `UINavigationControllerDelegate` geregelt und nicht in `push`: man kann
   auch per Finger zurückgehen, und das ruft `popViewController` nicht auf.