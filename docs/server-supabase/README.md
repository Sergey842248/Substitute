# Supabase-Variante des Sync-Servers

Dieselbe Schnittstelle wie [`docs/server`](../server), nur auf Supabase statt
auf einem eigenen Ubuntu-Server. Die App muss dafür nichts umbauen – die
gesamte Krypto und der Merge laufen auf dem Gerät.

## Dateien

| Datei | Wofür |
|---|---|
| `schema.sql` | Tabellen, Constraints, Indizes, Trigger, RLS |
| `verify-moderation.sql` | prüft die Namensprüfung gegen dieselben Fälle wie der Dart-Test |
| `verify-constraints.sql` | prüft Identifier, Hüllen-Form, Gerätelimit, Upsert |
| `verify-shares.sql` | prüft Hülln, Namens-Trigger, Sichtbarkeit im Verzeichnis |

## Loslegen

```sh
# 1. Lokal, ohne Supabase-Konto (braucht Docker)
supabase start
supabase db reset          # schema.sql anwenden
supabase db reset && psql "$SUPABASE_DB_URL" -f verify-moderation.sql

# 2. Prüfen, dass die Datenbank von außen dicht ist
curl "$SUPABASE_URL/rest/v1/shares" -H "apikey: $ANON_KEY"
#   → muss 401 liefern, niemals Zeilen

# 3. Gehostet: SQL-Editor im Dashboard, schema.sql einfügen
```

`schema.sql` ist mehrfach ausführbar (`IF NOT EXISTS` überall), weil das
Deploy-Skript es bei jedem Durchlauf erneut anwendet.

## Zwei Tabellen

`chain_snapshots` – ein Snapshot pro Gerät, zusammengesetzter Primärschlüssel
`(chain_id, device_id)`. Genau das erzwingt in der Tabelle, was der Dart-Server
in `putChainSnapshot` mit `removeWhere` + `add` erzwingt.

`shares` – die verschlüsselten Hülln plus die Metadaten, die das Suchmenü
braucht. Zwei Spalten sind **generiert** und können deshalb nicht von den
Hülln abweichen:

```sql
has_password           boolean generated always as (envelopes ? 'byPassword') stored
unlockable_with_school boolean generated always as (envelopes ? 'bySchool')  stored
```

## Zugriffsschutz

RLS ist an, und für `anon`/`authenticated` gibt es ausdrücklich nur
`using (false)`. Dazu kommt `revoke all`. Ergebnis: Von außen ist nichts
erreichbar, nur die Edge Functions kommen über `service_role` ran.

Das ist der Punkt, der leicht übersehen wird. Eine offen gelassene Tabelle mit
dem Gedanken "Vielleicht braucht die App das später" ergibt sehr schnell
Schreibrecht auf allem – und weil die Daten verschlüsselt sind, sieht man den
Schaden erst, wenn jemand fremde Snapshots überschreibt.

## Was beim Bauen auffiel

Drei Fehler, die erst das Ausführen des Schemas gegen ein echtes Postgres
gezeigt hat. Alle drei sind die Art, die man beim Lesen nicht sieht.

**`jsonb_object_length` gibt es nicht.** Es gibt nur `jsonb_array_length`, und
`jsonb_object_keys` ist eine Mengenfunktion – die darf in einem CHECK nicht als
Subquery stehen. Die Alternative ist der `-`-Operator:

```sql
(envelopes - 'byUsername' - 'byPassword' - 'bySchool') = '{}'::jsonb
```

Skalar, immutable, und „höchstens drei" ist damit automatisch erfüllt.

**`primary key (term)` ließ `pornografie` durch.** Der Begriff `porn` steht in
der Liste zweimal: als eigenständiges Wort und als Vorsilbe für `pornografie`.
Mit `term` allein als Schlüssel und `on conflict do nothing` verschwand die
zweite Zeile still – `Pornografie` war nicht mehr blockiert, ohne dass etwas
fehlschlug. Der Schlüssel ist jetzt `(term, kind)`.

**Der Gerätelimit-Trigger hat bestehende Geräte mitgezählt.** Ein
`BEFORE INSERT` zählt alle Zeilen der Kette, auch die, die gerade ersetzt
werden. Nach dem 12. Gerät konnte damit **kein** Gerät mehr synchronisieren –
auch nicht die zwölf vorhandenen. Abhilfe: Erst prüfen, ob das Gerät schon
dabeist, und dann nichts tun.

## Zwei Stellen, die bewusst offen bleiben

**Die Blockliste existiert jetzt doppelt** – hier als Tabelle und in
`lib/services/sync/NameGuard.dart`. Zwei Implementierungen derselben Regel
laufen unausweichlich auseinander, und die stillere Drift ist die gefährliche:
Ein Name, den die App blockiert, aber der Server nicht, landet trotzdem im
Suchverzeichnis. `schema.sql` Abschnitt 7 beschreibt die zwei Wege, das zu
verhindern. Der saubere ist eine JSON-Datei im Repo, aus der beide Seiten
erzeugt werden.

**`check_display_name` prüft keine Längen**, das macht der CHECK-Constraint in
der Tabelle. Wer die Funktion allein aufruft, bekommt für `''` `false`. Das ist
Absicht und steht so im Kommentar – aber es ist eine Fußangel, wenn später
jemand die Funktion aus einer Edge Function heraus statt über einen `insert`
prüft.

## Nicht getestet

Das Schema ist gegen **Postgres 18 lokal** gelaufen, inklusive aller drei
Prüfskripte. Nicht getestet sind:

- das Verhalten auf der Supabase-Variante von Postgres (derzeit 15/17),
- `extensions.unaccent` mit dem Supabase-Wörterbuch – ein `select
  extensions.unaccent('ß')` muss `ss` liefern, sonst greift die Prüfung für
  Umlautnamen nicht,
- die Edge Functions selbst.
