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

### Einstellungen mitnehmen oder nicht

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
