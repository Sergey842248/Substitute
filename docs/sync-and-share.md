# Sync und Share

Die App hat zwei Funktionen, die Daten zwischen Geräten bewegen – und beide
arbeiten nach demselben Prinzip: **Die Daten werden auf dem Gerät
verschlüsselt. Der Server sieht nur unlesbares Zeug.**

| | Sync | Share |
|---|---|---|
| Zweck | eigene Geräte gleich halten | Kolleginnen und Kollegen etwas geben |
| Wer | nur du, mit deinem Code | jede Person, die deinen Nutzernamen kennt |
| Ablauf | automatisch bei jedem Lauf | einmalig, von dir ausgelöst |
| Auswahl | alles außer Einstellungen optional | du wählst Klassen und Personen |
| Empfänger wählt | – | wie importiert wird (Original / Pläne / Personen) |

---

## Sync

Beim Einschalten erzeugt die App einen **Code aus zehn echten englischen
Wörtern**:

```
blue sky river seven apple candle dolphin winter harbor prime
```

Kein UUID, kein Base64: Der Code ist vorlesbar, abtippsicher und merkbar. Aus
ihm leitet die App die Kennung der Sync-Kette ab – wer ihn kennt, findet die
Kette beim Server, wer ihn nicht kennt, findet nichts.

Ein zweites Gerät gibt denselben Code ein und ist damit dabei.

### Die Reihenfolge der Wörter ist egal

Dieselben zehn Wörter ergeben immer dieselbe Kette, in welcher Reihenfolge sie
eingegeben werden. Die App sortiert sie vor der Berechnung.

Das ist keine Kosmetik, sondern die Verhinderung eines stillen
Totalausfalls: Ohne Sortierung wäre „blue sky …" eine andere Kette als
„sky blue …". Beide Geräte meldeten Erfolg, beide zeigten „Letzter Sync", und
es wäre nichts angekommen — weil jedes in einer eigenen, leeren Kette stand.
Für den Nutzen sieht das exakt aus wie ein kaputter Sync, und die Meldung auf
dem Bildschirm widerspricht dem.

Die Entropie bleibt dabei rund 100 Bit. Zehn Wörter aus über 1000 ergeben
mindestens 10 Bit pro Wort; die Reihenfolge zu erraten bringt nichts, denn die
Menge aller Permutationen ist genau die Menge aller möglichen Phrasen.

### Der Sync läuft von selbst

| Wann | Was |
|---|---|
| Start der App | nach 20 Sekunden |
| Zurückkehren aus dem Hintergrund | sofort |
| danach | alle 5 Minuten, solange die App vorn ist |

Der erste Lauf wartet bewusst: Um dieselbe Zeit lädt die App ohnehin ihre
Vertretungspläne, und beides gleichzeitig auf dem Mobilfunknetz wäre doppelte
Last für einen Sync, der auch zwei Minuten später käme.

Ein Lauf findet **nicht** statt, wenn

* keine Kette eingerichtet ist (es wird nicht einmal der Server gefragt),
* bereits ein Lauf unterwegs ist – der Knopf und der Zeitgeber dürfen sich
  nie in die Quere kommen, sonst schreiben zwei Läufe dasselbe Gerät
  gegenseitig die Daten zurück,
* seit dem letzten Lauf weniger als zwei Minuten vergangen sind,
* gerade etwas schiefging. Dann wächst die Wartezeit (1, 2, 4, 8 … bis 30
  Minuten). Ohne das versucht die App im Flugmodus alle paar Sekunden
  denselben Fehler und macht die Leitung nur langsamer.

Im Demo-Account läuft nichts: Dort gibt es nichts zu übertragen.

### Woher die Daten kommen

Nach einem Lauf, der etwas **herübergebracht** hat, meldet sich der Koordinator
über einen Strom. Die Startseite hängt sich daran und baut sich neu auf.

Ohne diesen Schritt lädt zwar die Datei, die angezeigte Liste aber nicht – was
sich anfühlt, als sei nichts passiert. Genau das war einer der gemeldeten
Fehler: Die Daten waren da, nur nirgends sichtbar.

### Zwei Speicherformen, ein Leser

Die App legt ihre Bestandteile auf zwei Arten ab:

| Form | Schlüssel |
|---|---|
| `StringList` | `offlineVPData`, `classes`, `cachedRooms`, `previewHidden*` |
| JSON-Zeichenkette eines Arrays | `persons`, `classNames`, `sickTrack`, `lessontimes`, `teacherShorts`, `hiddenSubjectsByClass` |

Der Grund ist `setStringList`: Es nimmt nur `String` auf, und `persons`
enthält Objekte. Wer sie also als Liste speichern will, muss sie erst zu
Zeichenketten machen – und genau das tut `VPlanAPI` an anderer Stelle als
`String`, nicht als Liste.

Daraus folgt eine Falle, die **drei** Fehler verursacht hat, keiner davon mit
einer Fehlermeldung:

1. `prefs.getStringList` **wirft** einen `TypeError`, wenn unter dem Schlüssel
   ein String liegt. Es liefert nicht `null`. Ein `?? []` fängt das nicht ab –
   der Ausdruck wird gar nicht erreicht.
2. `SharedPreferences.getString` wirft ebenso, wenn dort ein Boolean liegt.
3. Wer den `TypeError` mit `try`/`catch` abfängt und dann `return` macht, hat
   zwar keinen Absturz mehr, aber auch **keine Daten mehr**. Der Sync läuft,
   meldet Erfolg und überträgt nur noch, was als Liste gespeichert war.

Deshalb gibt es genau einen Leser dafür,
`SyncDataReader.readLines` / `.readParts`, und die Regel lautet: **über
`SyncKeys.dataKeys` niemals `getStringList` aufrufen.** Beide Speicherformen
werden bedient, und beide nach denselben Regeln dekodiert.

`readLines` ist öffentlich, weil mehrere Stellen dieselbe Frage stellen – der
Sync, der Share-Import und die Personenauswahl beim Teilen. Jede Stelle, die
stattdessen `getStringList` aufruft, ist bei der Hälfte der Schlüssel ein
Absturz.

### Der Sync darf die Speicherform nicht ändern

Das ist die gefährlichste Regel im ganzen Feature, und sie ist einmal
gebrochen.

`VPlanAPI` liest ihre Bestandteile mit **typisierten** Gettern – `getString`
für die JSON-Schlüssel, `getStringList` für die übrigen. Und diese Getter
**werfen** einen `TypeError`, wenn unter dem Schlüssel der andere Typ steht;
sie liefern nicht `null`. Deshalb gilt für jeden Bestandteil genau eine Form,
und sie steht in `SyncKeys.dataKeyForms`:

| Form | Schlüssel |
|---|---|
| `StringList` | `classes`, `offlineVPData`, `cachedRooms` |
| String mit JSON-**Array** | `persons`, `classNames`, `sickTrack`, `lessontimes`, `teacherShorts`, `initializedClasses` |

Ein Sync, der `persons` als `StringList` zurückschreibt, macht die App
**dauerhaft unstartbar**: `loadDisplayCache` wirft, `main()` bricht ab,
`runApp` wird nie erreicht – und weil der Schlüssel weiterhin falsch dasteht,
endet *jeder* weitere Start an derselben Stelle. Es genügt ein einziger
Sync-Lauf.

Drei Regeln folgen daraus, alle drei werden von Tests festgehalten:

1. **Ein Sync schreibt nie um.** Er schreibt in der Form aus
   `SyncKeys.dataKeyForms`, nicht in der Form, die sich anbietet.
2. **Ein Sync liest verzeihend.** `SyncDataReader.readLines` nimmt beide Formen
   an.
3. **Beim Start wird repariert.** `StorageHealer.healAll` bringt einmal alle
   Bestandteile auf die erwartete Form. Ein Gerät, das eine frühere
   App-Version beschädigt hat, ist sonst für immer tot.

Und eine Form, die der Sync gar nicht erst anfassen darf: JSON-**Maps**.
`hiddenSubjectsByClass`, `previewHiddenClasses` und `previewHiddenPersons`
liegen als `{classId: true}`. Sie standen früher in `dataKeys` und sind jetzt
herausgenommen – `SyncPayload` stellt sich jeden Bestandteil als Liste vor,
und ein Sync hätte daraus eine `StringList` geschrieben, während `VPlanAPI`
sie mit `getString` liest. Dieselbe Falle, eine Ebene tiefer, und ausgelöst
beim Blenden einer Vorschau statt beim Start. Ausgeschlossene
Vorschau-Einstellungen sind ein kleiner Verlust; ein Absturz ist keiner.

### Alles wandert mit – außer Geheimnissen

Der Sync überträgt **jede** Einstellung, die die App kennt, und zwar ohne
Positivliste. Vorher gab es zwei handgepflegte Listen: zwölf Daten-Schlüssel
und noch einmal zehn Einstellungen. Eine solche Liste kann nicht vollständig
sein, und deshalb sind `languageCode`, `newsfeeds`, sämtliche Plan-Einstellungen
und die als Karte gespeicherten Angaben nie angekommen – stillschweigend, ohne
Fehler, ohne Logeintrag.

Entschieden wird nach dem Typ, nicht nach einer Liste:

| Art | Übertragung | Schlüssel |
|---|---|---|
| Array | einzeln, mit Lösch-Markierungen | Klassen, Personen, Pläne, Krankentracking, Kürzel, Zeiten, Räume |
| Karte | einzeln je Eintrag | `classNames`, `initializedClasses`, `hiddenSubjectsByClass`, `previewHidden*` |
| Schalter, Zahl, Text | als Ganzes, nach Änderungszeit | Sprache, Anzeigeoptionen, Planmodus, Material-Design … |

Der Schalter *Einstellungen mit übertragen* entscheidet nur noch, ob die letzten
beiden Gruppen mitgehen. Er bestimmt nicht mehr **welche** – das ist der Punkt.

Nicht übertragen werden, und nur das (`SyncKeys.neverSync`): Zugangsdaten, der
Sync-Zustand selbst, die Schulverwaltung, der Einstieg in die App, der
Kurzzeit-Cache der Pläne und eine Developer-Zeitüberschreibung.

Die Liste ist bewusst eine **Sperrliste**. Sie ist nur dann gefährlich, wenn
jemand etwas Neues hinzufügt, was nicht hineingehört – und dafür stehen dort die
eigentlichen Geheimnisse. Eine zu kleine Positivliste hätte dagegen ein
vergessenes Geheimnis bedeutet, und das ist der teurere Fehler.

### Die Änderungszeit gehört zum einzelnen Wert

Das war der Grund, warum **keine** Einstellung angekommen ist.

Früher stand im Paket **ein** Zeitstempel, gesetzt auf „jetzt" bei jedem Lauf –
ob sich etwas geändert hatte oder nicht. Damit behauptete jedes Gerät beim
letzten Sync das neueste zu sein. Bei Gleichstand gewann laut Regel das lokale
Gerät, also blieb überall der eigene Wert stehen. Die Oberfläche meldete dazu
zu Recht „Alles ist aktuell": Nichts war ja angekommen.

Jetzt führt der Sync **je Wert** eine Änderungszeit, und er erneuert sie nur
dann, wenn sich der Wert gegenüber dem zuletzt gesendeten tatsächlich geändert
hat. Der Vergleichsmaßstab liegt in `sync.settingsTimestamps`; der Sync fasst
dafür **keine einzige** Schreibstelle der App an – in `VPlanAPI`, `Plan` und den
Einstellungsseiten gibt es Dutzende davon.

Ein Wert, den ein Gerät zum **ersten Mal** sieht, bekommt den Anfang der
Zeitachse. Es weiß nicht, wann der Wert gesetzt wurde, und behauptet deshalb
nicht, der neueste zu sein. Der Preis: eine Änderung, die **vor** dem ersten
Sync gemacht wurde, ist nicht von einem Voreinstellungswert zu unterscheiden.
Nach dem ersten Lauf nicht mehr.

Bei gleichem Alter entscheidet der Wert, dessen kodierte Form alphabetisch
größer ist. Beliebig, aber auf **beiden** Geräten gleich – „bei Gleichstand
gewinnt das lokale Gerät" wäre nicht symmetrisch, und zwei Geräte würden den
Wert endlos hin- und herschieben, ohne zur Ruhe zu kommen.

### Ein Eintrag ist ein Objekt **oder** ein Name

Das war der Grund, warum die Klassen nie ankamen.

Die App legt ihre Bestandteile in zwei Formen ab, und der Unterschied steht
nirgends:

| Schlüssel | Zeile in der Liste |
|---|---|
| `persons`, `offlineVPData`, `sickTrack`, `teacherShorts`, `lessontimes` | JSON-Objekt |
| `classes`, `cachedRooms` | schlicht ein Name, etwa `8a` |

Beim Tippen auf „Klasse auswählen" passiert das hier:

```dart
_classes.add(className);                                  // '8a'
instance.setStringList(SchoolStorage.scopedKey(prefs, 'classes'), _classes);
```

Der Leser zerlegte aber **jede** Zeile mit `jsonDecode` und ließ nur Zeilen
durch, die ein Objekt ergaben. Bei `8a` scheitert `jsonDecode` — und damit ist
die Zeile kommentarlos weggefallen. Der Sync übertrug nie eine Klasse, meldete
aber Erfolg, und die Oberfläche zeigte dauerhaft „Alles ist aktuell". Genau das
ist gemeldet worden.

Drei Regeln daraus, alle drei mit Test:

1. Ein Eintrag ist ein `Object` – ein Objekt **oder** ein `String`. Nichts
   anderes wird zugelassen.
2. Gelesen wird verzeihend: Was `jsonDecode` als Objekt oder Zeichenkette
   ergibt, wird übernommen; was gar nicht JSON ist, bleibt der rohe Text. Eine
   Zahl wie `123` ist zwar gültiges JSON, war aber als Zeichenkette gespeichert
   — und muss `123` bleiben, nicht zur Zahl werden.
3. Geschrieben wird **genau so, wie es gelesen wurde**. Ein Objekt als JSON, ein
   Name als Name. Mit einem `jsonEncode` für beides stünde danach `"8a"` in der
   Liste, und die Auswahl zeigte die Anführungszeichen mit.

Die Identität eines einfachen Namens ist **er selbst**. Zwei Geräte, die beide
die Klasse `8a` haben, meinen dasselbe — und nach dem Merge steht sie genau
einmal in der Liste. Ohne diese Regel wäre jeder Name auf beiden Geräten ein
eigener Eintrag, und die Liste enthielte jede Klasse doppelt.

### Wo die Funktionen liegen

Sync, Share und „Shares finden" liegen als **dritter Eintrag in der
Navigationsleiste** – zwischen „Suche" und „Dashboard". Die Seite hat **keine
eigene Kopfzeile**, genau wie der `Dashboard`-Tab.

Zwei Entscheidungen, beide ausprobiert:

* **Nicht in den Einstellungen.** Dort lagen sie tief in einer Liste, zwischen
  Sprache, Sicherung und Entwickleroptionen. Das trifft besonders die
  Funktionen, für die man die App braucht: Wer ein zweites Gerät koppeln will,
  tippt nicht zuerst auf „Einstellungen".
* **Als dritter statt als vierter Eintrag.** Das `Dashboard` ist der Bildschirm
  mit Einstellungen und Werkzeugen, und ein Bildschirm, den man beim Tippen
  mitnimmt, gehört nicht an den rechten Rand. Von links nach rechts liest sich
  die Leiste damit wie ein Weg: Pläne ansehen, suchen, mit anderen teilen,
  Werkzeuge.

Ohne eigene Kopfzeile, weil ein Tab bereits unter der Kopfzeile der App liegt:
Eine zweite brächte 10 % der Bildschirmhöhe für eine Zeile, direkt unter einer
20 % hohen Leiste. Genau deshalb hat der Tab **keinen** Header – dieselbe
Entscheidung, die der `Dashboard`-Tab schon vorher getroffen hat.

#### Der Eintrag lässt sich ausblenden

Wer die drei Funktionen nicht braucht, schaltet den Eintrag unter
**Einstellungen → Aussehen** ab. Dann hat die Leiste wieder drei Einträge.

Ausgeschaltet wird nur der **Eintrag**. Die Funktionen selbst bleiben
erreichbar, sonst wären sie weg – und wer sie wieder braucht, hat genau einen
Schalter dafür.

Die Einstellung wirkt an einem Bildschirm, der beim Ändern gar nicht im
Vordergrund ist: Die Leiste gehört zum Startbildschirm, die Einstellungsseite
ist eine eigene Seite. Ohne gemeinsame Quelle (`AppAppearance`) wüsste beim
Zurückkehren niemand, dass sich etwas geändert hat, und man käme auf die alte
Leiste zurück, ohne dass sich etwas bewegt hätte.

#### Hell und dunkel

Der Standard ist **dunkel**, weil die App vorher nur so aussah.

Hell ist **keine Umkehrung** von dunkel. Die beiden Farbwelten sind unabhängig
voneinander festgelegt (`main.dart`), weil eine Umkehrung genau das ergibt, was
man in der App sieht – und was nicht stimmt:

| Rolle            | Dunkel                     | Hell                          |
|------------------|----------------------------|-------------------------------|
| Hintergrund      | `neutral2.shade900`        | `neutral2.shade50`            |
| Flächen (Karten) | ein wenig dunkler         | **weiß**                      |
| Linien           | fast schwarz               | `neutral2.shade300`           |
| Text und Symbole | `focusColor` = weiß        | `focusColor` = fast Schwarz   |
| Akzent           | `accent1.shade200` (hell)  | `accent1.shade600` (dunkel)   |

Zwei Entscheidungen sind dabei nicht selbstverständlich und werden gern
umgedreht:

* **Der Grund ist nicht weiß, die Karten sind es.** Umgekehrt heißen die
  Karten nicht – ein weißes Quadrat auf weißem Grund ist eine unsichtbare
  Fläche. Ein sehr helles Grau als Grund gibt den weißen Karten ihren Rand,
  ohne selbst aufzufallen.
* **Der Akzent wird im Hellen dunkler, nicht heller.** Ebenso die Linien: Sie
  mussten dort *dunkler* werden. Ein heller Akzent, der auf dunklem Grund gut
  steht, verschwindet auf Weiß.

Geprüft wird das nicht am Aussehen, sondern an Zahlen: Der Test
`test/appearance_test.dart` misst für jede Rolle den Kontrast zum Grund und
verlangt die Werte, die WCAG für Text (4,5) und für Symbole (3) nennt. Der
alte Light-Modus fiel bei drei davon durch – grauer Grund, weiße Trennlinien,
unlesbares Fehlerrot.

#### Der Platz unter dem Inhalt

Der Inhaltsbereich in `main.dart` reserviert den Platz für die
Navigationsleiste **einmal für alle Bildschirme**. Vorher hat sich jeder
Bildschirm selbst beholfen, mit festen Prozentwerten – und der Startbildschirm
eben nicht.

Zwei Fehler steckten darin, und der zweite war der, den man bemerkt:

**Erstens** fehlte der Platz. Zwischen dem letzten Eintrag und dem Leistenoberrand
gab es keinen Abstand, also half auch Scrollen nichts – die letzte Karte war nur
während der Bewegung sichtbar und dann wieder weg.

**Zweitens** gab es zwei Bereiche, in denen man scrollen konnte: Der
Startbildschirm scrollt, und die Liste der Klassenpläne darin hatte eine eigene
Höhe und ihr eigenes Scrollen. Welcher sich bewegte, entschied der Finger – und
man zieht naturgemäß an den Karten, weil man die Karten sehen will. Die Liste
wuchs dabei über den Bildschirm hinaus und ihrer Rand federte zurück.

Die Planliste ist deshalb kein eigener Bereich mehr: `shrinkWrap` lässt sie so
hoch werden wie ihre Karten, `NeverScrollableScrollPhysics` nimmt ihr das
Scrollen. Scrollt wird nur noch der Bildschirm. Die Animationen beim Hinzufügen
und Löschen bleiben – dafür ist `AnimatedList` zuständig.

### Klassen sind immer sortiert

`06.2` steht **vor** `11`, und `8a` **vor** `10`. Kein reiner
Zeichenkettenvergleich kann das: dort käme `10` vor `8a`, weil `'1'` kleiner
ist als `'8'`. Verglichen wird deshalb **natürlich** – Ziffernfolgen als Zahlen,
alles andere ohne Rücksicht auf Groß- und Kleinschreibung
(`ClassNames.compare`).

Das ist eine bewusste Abkehr von einer mitgewandten Reihenfolge. Die hätte zwei
Mängel gehabt: Zwei Geräte müssten sich auf eine Reihenfolge einigen, die
niemand verlangt hat, und eine unpassende bliebe erhalten, bis jemand sie von
Hand ändert – die Liste enthielte dann `11, 06.2, 8a`.

Sortiert wird an **zwei** Stellen, die dieselbe Funktion benutzen:

* beim Anlegen und Entfernen einer Klasse in `VPlan`, und beim Lesen der Liste –
  damit ist auch eine App, die schon läuft, richtig, ohne dass jemand erst eine
  Klasse hinzufügen muss;
* beim Schreiben des Sync (`SyncMerge.canonicalOrder`).

Die zweite Stelle ist keine Zierde: Ein Gerät, das **allein** in der Kette ist,
führt überhaupt keinen Merge durch – es hat nichts zum Zusammenführen. Eine
Sortierung nur im Merge ließe die Liste dort für immer unsortiert, und es sind
nicht nur die Anzeige, sondern auch Krankentracking, Auswertung und Teilen, die
sie roh lesen. Deshalb schreibt `SyncEngine.run` auch dann zurück, wenn sich
nichts geändert hat, aber eine Liste in der falschen Ordnung dasteht.

### Auch die schon vorhandenen Listen

Das Update, in dem die Sortierung eingeführt wurde, erreicht die Listen nicht,
die **vorher** geschrieben wurden. Sie folgen der Reihenfolge des Anlegens –
wer `11` vor `06.2` angelegt hatte, hatte danach `11, 06.2` – und daran ändert
das Sortieren beim Anlegen nichts mehr. Am Anlegen und Entfernen zu sortieren
reicht also nicht: Wer die App updated und nicht synchronisiert, behält die alte
Reihenfolge.

Deshalb läuft beim Start ein Durchgang (`ListOrderRepair`), und zwar über
**alle** Schulen, nicht nur über die gerade aktive. Und er läuft bei jedem Start,
nicht einmalig: Er prüft vor dem Schreiben und tut bei bereits richtigen Listen
nichts. Ein Versionsmerkmal wäre nur eine zusätzliche Stelle, an der etwas falsch
sein kann, und würde die App daran hindern, sich selbst zu heilen, wenn später
ein Fehler eingebaut wird, der wieder etwas verschiebt.

Repariert werden die **Klassen** (nach der menschlichen Lesart) und die
**Pläne** (nach Datum) – der Plancache ist über das Datum geschlüsselt, und die
App sucht darin nach Datum.

Zwei Schulen bleiben dabei üblicherweise unbeachtet, und beide sind abgedeckt:

* **Die Listen sind nicht nur eine Anzeige.** Krankentracking, Auswertung und
  das Teilen lesen dieselbe Liste roh. Eine unsortierte Liste fällt dort sofort
  auf.
* **Verwaiste Schulen.** Eine Schule, deren Profil gelöscht wurde, deren Daten
  aber noch da sind, steht nicht mehr in der Profilliste. Aus der Profilliste
  allein würde sie nicht gefunden – ihre Klassen blieben unsortiert und tauchten
  beim Umschalten wieder auf. Deshalb werden die Schulen auch aus den
  gespeicherten Schlüsseln gesammelt.

Die Form wird dabei nicht verändert: `classes` bleibt eine `StringList`. Sie als
JSON-Zeichenkette zu schreiben wäre der direkte Weg in den Absturz beim Start,
siehe oben.

**Die Reihenfolge der Personen** ist der Gegenfall: Sie ist benutzersichtbar,
und jemand kann sie von Hand gestellt haben. Sie wandert deshalb mit – wer sie
zuletzt geändert hat, gibt sie vor; neue Personen werden an der Stelle
eingefügt, an der sie auf der Herkunftsseite standen. Bei gleichem Alter
entscheidet der größere Identitätszug, denn „bei Gleichstand gewinnt die
lokale Seite" wäre nicht symmetrisch und die Geräte würden sich endlos
umdrehen.

### Woran man erkennt, was los ist

In den Einstellungen stehen drei Kacheln, die die drei Fragen beantworten, an
denen ein Sync scheitern kann, **ohne** dass irgendwo ein Fehler steht:

| Kachel | Beantwortet |
|---|---|
| *Automatisch synchronisiert* | Läuft das ohne mich, und wann war der letzte automatische Lauf? |
| *… Einträge werden übertragen* | Sind überhaupt Daten vorhanden? Bei einer frischen App: null. |
| *… Geräte in dieser Kette* | Gibt es überhaupt jemanden, von dem etwas kommen könnte? |

Die dritte ist die wichtigste. Nach einem Sync mit **einem einzigen** Gerät
sieht alles erfolgreich aus, und es fließt trotzdem nichts – weil es niemanden
gibt, von dem etwas kommen könnte. Ein einzelnes Feld „Letzter Sync" kann das
nicht von einem funktionierenden Sync mit drei Geräten unterscheiden.

Im Unterschied dazu meldet der Knopf in den Einstellungen ausdrücklich
„Deine Daten wurden übertragen, aber noch kein anderes Gerät ist diesem Sync
beigetreten", statt nur „Alles ist aktuell" zu sagen.

### Einstellungen mitnehmen oder nicht

Sprache, Anzeigeoptionen, Planmodus und Material-Design wandern mit, wenn der
Schalter eingeschaltet ist. Wer auf dem Tablet Deutsch und auf dem Handy
Englisch liest, schaltet ihn für dieses Gerät aus – dann bleibt die Sprache
dort, wie sie ist, und alle anderen Einstellungen ebenfalls.

Klassen, Personen, Kurse und die gespeicherten Pläne werden **immer**
synchronisiert. Die **Einstellungen** sind ein Schalter: Ausgeschaltet
bleiben sie auf jedem Gerät für sich. Wer auf dem Tablet lieber auf Deutsch
liest, kann das so einrichten, ohne dass die Pläne getrennt bleiben.

Das **Schulpasswort** wird nie übertragen. Auch nicht im Share.

### Wie die Daten gleich bleiben

Der Server speichert pro Gerät einen eigenen Snapshot. Beim Sync holt ein
Gerät die Snapshots aller anderen und führt sie zusammen – **eintragsweise**:

| | Ergebnis |
|---|---|
| Eintrag nur hier | behalten |
| Eintrag nur dort | übernehmen |
| Eintrag in beiden | der zuletzt geänderte gewinnt |
| gelöscht | bleibt gelöscht |

Damit gibt es keinen "Hauptgerät": Eine Person, die du am Handy löschst,
verschwindet auch am Tablet. Umgekehrt gilt dasselbe. Und weil die
Zusammenführung symmetrisch ist, spielt es keine Rolle, welches Gerät zuerst
synchronisiert.

Gelöschtes bekommt eine **Lösch-Markierung** mit. Ohne sie würde ein
gelöschter Eintrag beim nächsten Sync von einem Gerät zurückkommen, das ihn
noch hatte.

### Die Kette wieder verlassen

Wer die Kette verlässt, verliert **nichts**. Pläne, Personen und
Einstellungen bleiben auf dem Gerät; nur der Abgleich mit den anderen hört
auf. Der Server löscht dazu ausschließlich den eigenen Snapshot.

### Geräteliste

Unter *Einstellungen → Sync → Geräte* steht, welche Geräte in der Kette sind –
mit Namen, die das Gerät selbst meldet („Samsung SM‑A536B"), und dem
Zeitpunkt des letzten erfolgreichen Syncs.

---

## Share

Ein Share ist eine bewusste Übergabe: **du** wählst aus, was andere sehen,
und **die andere Person** wählt, wie es bei ihr ankommt.

### Was reingeht

* einzelne **Klassen**,
* einzelne **Personen** (die Klasse einer Person kommt automatisch mit, sonst
  wären ihre Kurse nicht einzuordnen),
* die **gespeicherten Vertretungspläne** – auch die aus der Vergangenheit,
  wenn du das willst,
* optional die **Einstellungen**.

Du kannst beliebig viele Shares anlegen: mit verschiedenen Klassen, für
verschiedene Gruppen, mit verschiedenen Passwörtern.

### Dein Nutzername

Beim ersten Share erzeugt die App einen **Nutzernamen aus zehn englischen
Wörtern**. Den gibst du weiter – im Raum, per Nachricht, wie es passt. Der
Nutzername ist das, wonach im Suchmenü gesucht wird, und der Anzeigename
(„Frau Müller") ist das, was dort steht.

Der Anzeigename wird geprüft: anstößige, geschmacklose oder menschenfeindliche
Namen werden abgelehnt – **in jeder Schreibweise**. `Arschloch`, `F@@k` und
`a-r-s-c-h-l-o-c-h` werden alle erkannt, `Bass`, `Klassenzimmer` und
`Müller-Schmidt` nicht.

### Suchen oder eingeben

Es gibt zwei Wege:

* **Im Suchmenü** siehst du alle Personen deiner **eigenen Schulnummer**,
  die ihre Shares als *suchbar* markiert haben. Wer seinen Share nicht
  markiert, erscheint dort nicht. Aus einer anderen Schule kommt nichts
  herein – deshalb ist das Suchmenü erst nach der Anmeldung mit Schulnummer
  und Zugangsdaten nutzbar.
* **Nutzername eingeben**: Wer die zehn Wörter kennt, kommt auch ohne
  Suchmenü direkt zu den Shares.

### Wie viele Shares

Klickt man eine Person an, werden **zuerst alle ihre Shares** aufgelistet.
Erst wenn einer davon gewählt ist, sieht man, was drin ist, und wählt die
Importart.

### Drei Importarten

| | Was passiert |
|---|---|
| **Original** | Genau so übernehmen, wie die Person es angelegt hat. `Hans` bleibt eine Person, `7c` bleibt eine Klasse, die Kurse bleiben die Kurse. |
| **Pläne** | Jede Person wird zu einem Plan: eine Klasse mit ihrem Namen und je ein Plan-Eintrag pro Kurs. |
| **Personen** | Aus allem werden Namen: aus jeder Person, jeder Klasse und jedem Plan. |

Der Unterschied lohnt sich, wenn die fremde Klassenstruktur nichts taugt:
`7c` existiert bei dir nicht, und die Kurse `7c` gehören niemandem – die
Person schon.

Ein Import **überschreibt nichts**. Vorhandene Klassen und Personen bleiben;
nur die Kürzel werden entkollidiert, damit eine importierte Klasse `7c` nicht
deine eigene `7c` ersetzt.

### Global und passwortgeschützt

Ein Share kann **global** sein: Dann kann ihn jede Lehrkraft öffnen, die den
Nutzernamen kennt – auch aus einer anderen Schule. Im Suchmenü fremder
Schulen erscheint er trotzdem nicht; global heißt nicht überall sichtbar.

Ein Share kann ein **Passwort** haben, ebenfalls zehn Wörter. Dann gilt:

| | ohne Passwort | mit Passwort |
|---|---|---|
| Nutzername allein | öffnet | öffnet **nicht** |
| Schulzugangsdaten | öffnen | öffnen **nicht** |
| Passwort | – | öffnet |

Genau darum gibt es das Passwort: Ohne es könnte jede Person, die die
Schulzugangsdaten hat, den Account der Kollegin aufspüren.

### Im Demo-Account

Im Demo-Account (`123456` / `user` / `password`) gibt es keine geteilten
Daten, weil es keine echten Nutzer gibt. Dort steht im Suchmenü schlicht
„Es hat noch niemand etwas geteilt" – und die ganzen Funktionen zum Teilen
sind nicht erreichbar. Ein Demo-Datensatz in einer echten Suchliste wäre
irreführend, deshalb wird er gar nicht erst angelegt.

---

## Wie die Verschlüsselung funktioniert

```
Gerät A                        Server                        Gerät B
   │                             │                              │
   │  AES-256-CBC + HMAC         │                              │
   ├──── Hülle (unlesbar) ───────►│                              │
   │                             │──── Hülle (unlesbar) ───────►│
   │                             │                  entschlüsselt│
   │  entschlüsselt + zusammenführen                        │
```

* **AES-256-CBC** für den Inhalt, **HMAC-SHA-256** darüber
  („Encrypt-then-MAC"). Ein verändertes Byte fällt beim MAC auf, bevor
  überhaupt entschlüsselt wird.
* **PBKDF2-HMAC-SHA256** mit 120 000 Runden leitet den Schlüssel ab. Der
  Salz hängt vom Verwendungszweck ab, damit dieselbe Passphrase in einem
  Sync und in einem Share nie denselben Schlüssel ergibt.
* **Kein Krypto-Paket.** AES, SHA-256, HMAC und PBKDF2 liegen als reines Dart
  bei und sind gegen die offiziellen FIPS-197-, FIPS-180- und RFC-4231-Vektoren
  geprüft (`test/crypto_test.dart`).

### Drei Wege hinein

Damit ein Share mit dem Nutzernamen, mit einem Passwort **und** mit den
Schulzugangsdaten zu öffnen ist, enthält er **mehrere Hülln** desselben
Inhalts – jede mit einem anderen Schlüssel. Der Server speichert sie
nebeneinander, ohne eine zu öffnen.

| Hülle | Schlüssel aus |
|---|---|
| `byUsername` | dem Nutzernamen |
| `byPassword` | Nutzername + Passwort |
| `bySchool` | Nutzername + Passwort der Schule |

Bei einem passwortgeschützten Share fehlen `byUsername` und `bySchool` – sonst
wäre das Passwort umsonst.

### Was der Server sieht

| | in Klartext | verschlüsselt |
|---|---|---|
| Sync-Kette | Gerätename, Zeitstempel | alles andere |
| Share | Nutzername, Schulnummer, Anzeigename, „suchbar", „global" | Pläne, Personen, Kurse, Einstellungen |
| Verzeichnis | Anzeigename, Anzahl der Shares | alles Inhaltliche |

Für das Suchmenü muss der Server die Anzeigenamen lesen können – sonst könnte
er niemanden finden. Deshalb sind das die einzigen Klartextangaben. Wer die
Absender wirklich sind, weiß nur, wer den Anzeigenamen gewählt hat.

**Folge für den Betreiber:** Daten auf dem Server können gesichert, aber
**nicht wiederhergestellt** werden. Sie sind nur für die Geräte lesbar, die
den passenden Schlüssel haben.

---

## Der Server

Zwei Implementierungen derselben Schnittstelle. Welche läuft, entscheidet
allein die Adresse in `lib/services/sync/SyncCredentials.dart` – erkennbar an
`.supabase.co`.

### Edge Functions auf Supabase (der aktuelle Stand)

Quelltext: [`supabase/functions`](../supabase/functions) · Schema:
[`docs/server-supabase/schema.sql`](server-supabase/schema.sql) ·
Statusseite fragt `GET /functions/v1/health` und zeigt **nur** „Server is
running" oder „Server is stopped".

Vier Functions (`health`, `chain-snapshots`, `shares`, `directory`) auf
PostgREST, ohne eigenen Prozess und ohne Server-Administration. Die
Drosselung liegt in der Datenbank (`bump_rate_limit`), weil jede Function in
einer kurzlebigen Umgebung läuft: Ein Zähler im Modulspeicher wäre beim
nächsten Aufruf weg und würde nichts messen.

Die Tabellen sind für `anon` und `authenticated` gesperrt (RLS, deny-all);
erreichbar sind sie nur über `service_role` aus den Functions heraus.

**Die Schnittstelle prüft keine Kennung.** `verify_jwt = false` heißt, dass
das Gateway auch keinen `apikey`-Header verlangt – wer die Adresse kennt,
kann alles aufrufen. Das ist hier gewollt: Der Server ist blind, und der
Publishable Key stünde ohnehin im APK. Das eigentliche Geheimnis ist der
zehnwörtige Code, die Bremse gegen Masseabfragen die Drosselung.

**Ein Formatvertrag, der schon einmal geschnitten hat:** Anfragen tragen
`snake_case` (Spaltennamen), Antworten `camelCase` (Domänenmodell der App).
Beide Seiten sind jetzt vereinheitlicht; siehe
[`supabase/README.md`](../supabase/README.md).

### Eigenständiger Dart-Server (Alternative)

Quelltext: [`docs/server`](server/) · läuft auf Ubuntu, Port 8384.

Er ist ein einzelner Prozess ohne Abhängigkeiten, mit JSON-Dateien als
Speicher und atomarem Schreiben. Drosselung, Obergrenzen und eine zweite
Namensprüfung sind eingebaut – die Schnittstelle ist auch ohne die App
aufrufbar, deshalb verlässt sich der Server auf nichts, was die App geprüft
hat.

Details, Endpunkte und Installation: [`docs/server/README.md`](server/README.md).

---

## Was der Server *nicht* kann

* Er kann die Daten nicht lesen.
* Er kann Daten nicht wiederherstellen.
* Er kann nicht erkennen, ob eine Passphrase die richtige ist – der Client
  merkt es erst am fehlgeschlagenen Entschlüsseln.

Fällt der Server aus, ist die App unverändert benutzbar. Sync und Shares sind
Zusatzfunktionen; ein fehlgeschlagener Lauf meldet es und lässt die lokalen
Daten unangetastet.
