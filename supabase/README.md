# Edge Functions für den Sync- und Share-Server

Vier Functions, die dieselbe Schnittstelle anbieten wie
[`docs/server`](../server) – nur auf Supabase statt auf einem eigenen
Ubuntu-Server. Die App ändert sich dadurch nicht: Krypto und Merge laufen auf
dem Gerät, hier geht nur verschlüsselter Transport über die Leitung.

## Dateien

```
supabase/
├── config.toml                 Supabase-CLI und JWT-Regeln
├── deno.json                   Abhängigkeiten und Aufgaben
└── functions/
    ├── _shared/
    │   ├── http.ts             Antworten, Fehler, Prüfungen, Drosselung
    │   └── db.ts               PostgREST-Zugriff, Typen, Drosselzähler
    ├── health/                 Status für die Seite auf GitHub Pages
    ├── chain-snapshots/        GET/PUT/DELETE – Snapshots je Gerät
    ├── shares/                 GET/PUT/DELETE – Shares
    ├── directory/              GET – das Suchmenü
    ├── unit_test.ts            ohne Datenbank lauffähig (25 Tests)
    └── functions_test.ts       End-to-End über HTTP (31 Tests, ungelaufen)
```

`_shared` wird nicht deployt – der Unterstrich am Anfang ist Supabases
Konvention dafür.

## Ausrollen

```sh
supabase start                       # lokal, braucht Docker
supabase db reset                    # schema.sql ausführen

supabase functions deploy chain-snapshots
supabase functions deploy shares
supabase functions deploy directory
supabase functions deploy health
```

Der service_role-Key wird den Functions automatisch als Umgebungsvariable
gesetzt. Er darf **nicht** in die App, nicht ins Repo und nicht in ein Log.

### Der Formatvertrag: Anfrage snake_case, Antwort camelCase

Das ist die eine Stelle, an der App und Function leicht auseinanderlaufen.

| | Feldnamen | Grund |
|---|---|---|
| **Anfrage-Rumpf** | `chain_id`, `school_number`, `is_global`, `display_name` | gehen 1:1 in die Spalten der Datenbank |
| **Antwort** | `deviceId`, `isGlobal`, `username`, `displayName` | ist das Domänenmodell der App, nicht die Datenbank |

Diese Asymmetrie hat schon einmal stillschweigend geschnitten: Der Client
schickte `isGlobal`, die Function las `is_global`, bekam `undefined` und
antwortete `400 invalidShare` – ohne jeden Hinweis, dass ein einziger
Namenszusatz schuld war. Beide Seiten sind jetzt auf `snake_case`
umgestellt (`supabase/functions/shares/index.ts`), der Client ebenso
(`lib/services/sync/SyncApiClient.dart`).

**Nach diesem Umbau muss `shares` neu deployed werden.** Ein Test in
`test/sync_live_test.dart` fällt genau dann noch rot auf:

```
SyncException(invalidShare, status: 400)
```

## Warum `verify_jwt = false`

Die App hat keine Konten. Der Sync-Code aus zehn Wörtern *ist* die Identität,
und die daraus abgeleitete Ketten-ID sind 256 Bit, die niemand errät. Ein JWT
müsste sicher verteilt werden – an genau die Leute, die ihn gerade nicht
brauchen.

### Der `apikey`-Header ist keine Schranke

An der fertigen Instanz nachgemessen:

```sh
curl -o /dev/null -w '%{http_code}\n' \
  '…/functions/v1/chain-snapshots?chain_id=eq.probe'      # → 200
curl -o /dev/null -w '%{http_code}\n' \
  '…/functions/v1/directory?school_number=12345'           # → 200
```

Ohne `apikey` kommen beide durch. `verify_jwt = false` schaltet die
JWT-Prüfung ab – und im Gateway ist damit auch die `apikey`-Pflicht
weggefallen. Wer die Adresse kennt, kann alles aufrufen.

Das ist hier gewollt: Der Server ist blind, sieht nur verschlüsselte Hüllen
und kennt keine Benutzerkonten. Eine Kennung, die in der App auslieferbar
wäre, wäre nur Scheinsicherheit – jeder könnte sie aus dem APK ziehen. Was
übrig bleibt, ist der zehnwörtige Code als eigentliches Geheimnis und die
Drosselung in `rate_limit` als Bremse gegen Masseabfragen.

Die App schickt den Publishable Key trotzdem mit: Er kostet nichts, und falls
das Gateway later doch wieder eine `apikey` verlangt, fällt es nicht auf.

Die **Datenbank** ist davon nicht betroffen. `anon` und `authenticated` haben
dort nichts zu lesen, nachgemessen über `/rest/v1/shares` → 401. Nur
`service_role` erreicht die Tabellen, und das ausschließlich aus den Functions
heraus.

## Tests

```sh
# ohne Docker, ohne Supabase
deno task check
deno task test        # 25 Tests

# End-to-End, braucht eine laufende Instanz
supabase start
supabase db reset
supabase functions serve
deno task test:e2e    # 31 Tests
```

## Was beim Bauen auffiel

Sieben Fehler, die alle erst das Ausführen gezeigt hat – beim Lesen sind sie
nicht sichtbar.

**`?chain_id=eq.abc` ist kein Bezeichner.** PostgREST kodiert den Operator in
den Wert. `isValidId` hat ihn abgelehnt und die Function auf *jede* Anfrage
mit 400 geantwortet, auch auf völlig gültige. Deshalb gibt es `idParam` als
eigenes `queryParam` für Bezeichner.

**`createClient` aus supabase-js war falsch.** Der Supabase-Client legt seinen
PostgREST-Client beim Konstruieren selbst an
(`SupabaseClient.ts: this.rest = new PostgrestClient(...)`) und bietet keine
Möglichkeit, einen eigenen einzusetzen. Er leitet aus `SUPABASE_URL` einen
Postgres-Port ab – auf Supabase zufällig richtig, überall sonst ein
`ECONNREFUSED` auf Port 5432. Es ist jetzt `PostgrestClient` direkt.

**`BYPASSRLS` allein reicht nicht.** `service_role` sieht ohne separates
`GRANT` "permission denied", weil BYPASSRLS nur die Zeilenregeln überspringt.
Deshalb stehen die Grants in `schema.sql`, Abschnitt 5.

**Die Drosselung muss in die Datenbank.** Jede Function läuft in einer
kurzlebigen Umgebung; ein `Map` im Modul wäre beim nächsten Aufruf weg und
würde nichts zählen – scheinbar wirksam, tatsächlich wirkungslos.

**Ein Zeitstempel muss plausibel sein.** Sonst erklärt ein Gerät mit
verstelltem Systemdatum seinen Stand zum neuesten und überschreibt damit alle
anderen Einträge der Kette. Die Function lehnt deshalb mehr als fünf Minuten
in der Zukunft ab.

**Ein Test-Double, das die Anfrage zurückgibt, prüft gar nichts.** Zwei der
Test-Nachbauten der App haben den gespeicherten Anfragerumpf als Antwort
ausgeliefert, statt das DTO zu bauen, das der Server wirklich schickt. Der
Unterschied ist `device_id` gegen `deviceId` – fällt in der Antwort nur ein
Feld aus, ist der Wert `null`, und die Prüfung "gehört das mein eigenes
Gerät?" antwortet für *jedes* Gerät mit `nein`. Solche Nachbauten sind
schlimmer als gar keine: Sie bestehen jede Behauptung, die man über sie
aufstellt.

## Zwei bewusste Entscheidungen

**`PostgrestClient` statt `createClient`.** Für reine Datenbankzugriffe ist der
Supabase-Client der falsche Griff: Er bringt Auth, Realtime und Storage mit,
von denen hier nichts gebraucht wird.

**`updated_at` kommt vom Gerät, wird aber geprüft.** Der Merge in der App
verlässt sich auf die Reihenfolge der Snapshots, und die kommt aus diesem Feld.
Es wird nicht vom Server vergeben – sonst hinge die Reihenfolge an der
Systemzeit von Supabase statt an dem, was tatsächlich geändert wurde.

## Geprüft

Gegen die **echte** Instanz gelaufen: `test/sync_live_test.dart` in der App.
Zwölf Tests über den echten `http`-Client – Snapshot hin und zurück, Gerät
hinzufügen und entfernen, Verzeichnis, 404 bei unbekanntem Share, ein
vollständiger `SyncEngine`-Lauf, abgewiesener Anzeigename. Sie überspringen
sich selbst, wenn keine Instanz erreichbar ist.

Diese Tests haben zwei Dinge gefunden, die beim Lesen unsichtbar waren:

* Die Functions erwarten `snake_case` im Rumpf, der Client schickte
  `camelCase`. Ein 400 ohne Ursache.
* `envelopes` muss **alle fünf** Felder tragen (`v`, `iv`, `ct`, `mac`,
  `kdf`). Eine halbe Hülle wird mit demselben `invalidShare` abgewiesen wie
  ein kaputter Name – beim echten Gerät liest sich beides wie ein
  Serverfehler.

## Nicht geprüft

**Nicht gelaufen sind die 31 End-to-End-Tests** in `functions_test.ts`: In der
Umgebung, in der das hier entstanden ist, lief weder Docker noch die
Supabase-CLI, und eine selbstgebaute PostgREST-Brücke hat mehr Fehler
eingebracht als sie gefunden hat – sie ist deshalb wieder entfernt. Sie sind
typgeprüft und auf die neue Feldform nachgezogen, aber ungelaufen.

Vor dem ersten echten Einsatz also einmal:

```sh
supabase start && supabase db reset && supabase functions serve
deno task test:e2e
```

Ein Test darin – `ein Share lässt sich anlegen und öffnen` – prüft die
Antwortseite der Asymmetrie (`get.body.isGlobal`, `get.body.owner.schoolNumber`)
und wäre der Ort, an dem ein Renew auf einer Teil-Deployment-Stand
scheitern würde.
