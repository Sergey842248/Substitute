-- ============================================================================
--  Substitute Sync & Share – Datenbankschema für Supabase (Postgres)
-- ============================================================================
--
--  Zwei Tabellen, eine für Sync-Ketten, eine für Shares. Beides sind
--  Container für bereits vom Gerät verschlüsselte Daten: Der Server liest
--  den Inhalt nie.
--
--  Diese Datei ist bewusst in dieser Reihenfolge aufgebaut, weil spätere
--  Abschnitte frühere benutzen:
--
--    1. Erweiterungen
--    2. Blockliste + Namensprüfung
--    3. Tabellen, Constraints, Indizes
--    4. Trigger (Mengenbegrenzung)
--    5. RLS und Rechte
--    6. Aufräumen (optional)
--
--  Alle Grenzwerte stehen an den Stellen, an denen sie gebraucht werden, und
--  nicht nur als Kommentar.
--
--  Ausführen: SQL-Editor im Supabase-Dashboard, oder
--              psql "$SUPABASE_DB_URL" -f schema.sql
--
--  Voraussetzung auf Supabase: `anon`, `authenticated` und `service_role`
--  existieren. Auf einer frischen lokalen Instanz vorher:
--
--    create schema extensions;
--    create role anon nologin;
--    create role authenticated nologin;
--    create role service_role bypassrls nologin;
--
--  Die Datei ist mehrfach ausführbar: Alle Anweisungen benutzen IF NOT
--  EXISTS bzw. DROP IF EXISTS. Das ist wichtig, weil das Deploy-Skript sie bei
--  jedem Durchlauf erneut anwendet.
-- ============================================================================


-- ----------------------------------------------------------------------------
--  1. Erweiterungen
-- ----------------------------------------------------------------------------

-- `unaccent` braucht man für die Namensprüfung: "Scheißkopf" und
-- "Scheisskopf" müssen dasselbe ergeben, und dafür ist die Auflösung von
-- Umlauten und ß nötig. `ß` wird dabei zu "ss" – genau wie in der App.
--
-- Achtung: unaccent ist nur dann wirksam, wenn auch die Wörterbuchdatei
-- installiert ist. Ein Aufruf von `select extensions.unaccent('ß')` sollte
-- "ss" liefern; kommt "ß" zurück, fehlt das Wörterbuch und die Prüfung
-- greift für Umlautnamen nicht. In dem Fall: `apt install postgresql-contrib`
-- auf der DB-Maschine, dann ist die Datei unter
-- `$(pg_config --sharedir)/tsearch_data/unaccent.dict` zu finden.
create extension if not exists unaccent with schema extensions;


-- ----------------------------------------------------------------------------
--  2. Blockliste und Namensprüfung
-- ----------------------------------------------------------------------------
--
--  Anzeigenamen stehen offen in der Suchliste einer Schulnummer. Sie werden
--  deshalb serverseitig geprüft – eine Prüfung nur in der App lässt sich
--  umgehen, weil jeder die HTTP-Schnittstelle direkt ansprechen kann.
--
--  Die Liste liegt als **Daten** in einer Tabelle und nicht fest im Code
--  verdrahtet: Eine Ergänzung ist dann ein INSERT und keine Migration.


-- Bringt einen Namen in die Form, in der verglichen wird. Entspricht
-- `NameGuard.normalize` in der App, Schritt für Schritt:
--
--   1. Umlaute und ß auflösen           scheiße -> scheisse
--   2. Groß-/Kleinschreibung             ARSCHLOCH -> arschloch
--   3. Leet-Schrift zurückführen         sh1t -> shit, @rsch -> arsch
--   4. alles außer a-z entfernen         f-u-c-k -> fuck
--   5. Dehnungen zusammenziehen         fuuuuck -> fuuck
--
-- Schritt 4 und 5 sind gegenüber der App vertauscht, weil `translate` vorher
-- die Leet-Zeichen ersetzen muss. Das Ergebnis ist identisch: Beide Schritte
-- betreffen keine Ziffern.
create or replace function public.normalize_name(raw text)
returns text
language sql
immutable
strict
as $$
  select regexp_replace(
           regexp_replace(
             regexp_replace(
               translate(
                 lower(extensions.unaccent(raw)),
                 -- Leet-Schrift auf Klarbuchstaben. `translate` verlangt
                 -- gleich lange Zeichenketten: 16 Zeichen links, 16 Ersetzungen
                 -- rechts. 8->b steht hinter 7->t, die Reihenfolge spielt keine
                 -- Rolle, die Länge schon.
                 '0134578@!$&()<>+|',
                 'oieastbaaisscccti'
               ),
               '[^a-z]', '', 'g'
             ),
             '(.)\1{2,}', '\1\1', 'g'
           ),
           '\s+', ' ', 'g'
         )
$$;

comment on function public.normalize_name(text) is
  'Normalisiert einen Namen für die Blocklistenprüfung. Spiegelbild von '
  'NameGuard.normalize – die beiden dürfen nicht auseinanderlaufen.';


create table if not exists blocked_terms (
  term text not null,
  -- 'word'     = muss als eigenständiges Wort vorkommen  (Arschloch)
  -- 'compound' = darf ein Wort nur beginnen            (Scheiß… in Scheißkopf)
  -- 'phrase'   = muss als Zeichenfolge vorkommen       ("kill your self")
  kind text not null check (kind in ('word', 'compound', 'phrase')),

  -- Der Primärschlüssel ist (term, kind) und **nicht** term allein: Ein
  -- Begriff darf zugleich als Wort und als Vorsilbe gelten. 'porn' ist genau
  -- so ein Fall – 'porn' als eigenständiges Wort und 'pornografie' über die
  -- Vorsilbe. Mit `primary key (term)` verschwand der zweite Eintrag still,
  -- und 'Pornografie' blieb ungeprüft durch. Genau dieser Fehler ist beim
  -- ersten Testen des Schemas aufgefallen.
  constraint blocked_terms_pkey primary key (term, kind),

  -- Einmal vorberechnet statt bei jeder Prüfung neu: `unaccent` ist nicht
  -- billig, und die Liste wird für jeden hochgeladenen Namen durchlaufen.
  norm text generated always as (public.normalize_name(term)) stored,

  constraint blocked_terms_norm_length check (char_length(norm) > 0)
);

comment on table blocked_terms is
  'Blockliste für Anzeigenamen. Muss mit lib/services/sync/NameGuard.dart '
  'übereinstimmen – siehe Abschnitt 7.';

create index if not exists blocked_terms_norm on blocked_terms (norm);

-- `on conflict do nothing` bleibt, ist hier aber unkritisch: Der Konflikt
-- entsteht nur beim erneuten Einspielen derselben Datei, und die Zeile ist
-- dann identisch. Sollte sich ein Eintrag inhaltlich geändert haben, ist das
-- ein Fehler und fällt beim Vergleich mit der App auf.
insert into blocked_terms (term, kind) values
  -- Schimpfwörter und Beleidigungen (deutsch)
  ('arschloch', 'word'), ('dummkopf', 'word'), ('hurensohn', 'word'),
  ('idioten', 'word'), ('lügner', 'word'), ('mörder', 'word'),
  ('vergewaltiger', 'word'), ('verrat', 'word'),
  -- Schimpfwörter (englisch)
  ('arse', 'word'), ('arsehole', 'word'), ('asshole', 'word'),
  ('bastard', 'word'), ('bitch', 'word'), ('bollock', 'word'),
  ('bollocks', 'word'), ('bugger', 'word'), ('cunt', 'word'),
  ('dickhead', 'word'), ('dildo', 'word'), ('jackass', 'word'),
  ('motherfucker', 'word'), ('prick', 'word'), ('twat', 'word'),
  ('wanker', 'word'), ('whore', 'word'),
  -- Menschenfeindliche Bezeichnungen
  ('faggot', 'word'), ('nigger', 'word'), ('nigga', 'word'),
  ('retarded', 'word'), ('spastic', 'word'),
  -- Themen, die in einem offenen Verzeichnis nichts verloren haben
  ('porno', 'word'), ('naked', 'word'), ('nackt', 'word'),
  ('anus', 'word'), ('anal', 'word'), ('tits', 'word'), ('titten', 'word'),
  ('selbstmord', 'word'), ('suicide', 'word'),
  ('sex', 'word'), ('slut', 'word'),
  -- Wortstämme, die im Deutschen als Vorsilbe weitergehen. 'porn' steht hier
  -- zusätzlich zu 'porno' oben – beide Zeilen werden geprüft.
  ('arsch', 'compound'), ('dreck', 'compound'), ('dumb', 'compound'),
  ('dumm', 'compound'), ('fick', 'compound'), ('fuck', 'compound'),
  ('fotze', 'compound'), ('hure', 'compound'), ('idiot', 'compound'),
  ('nazi', 'compound'), ('porn', 'compound'), ('scheiss', 'compound'),
  ('schlampe', 'compound'), ('spast', 'compound'), ('spasti', 'compound'),
  ('vergewaltig', 'compound'), ('wichser', 'compound'),
  ('fag', 'compound'), ('paki', 'compound'), ('retard', 'compound'),
  -- Mehrwortige Kombinationen. Nach der Normalierung bleibt zwischen den
  -- Wörtern ein Leerzeichen, deshalb passt das Muster ' kill yourself '.
  ('stupid idiot', 'phrase'), ('verdammt idiot', 'phrase'),
  ('kill yourself', 'phrase'), ('bring dich um', 'phrase')
on conflict (term, kind) do nothing;


-- true, wenn der Name nicht verwendbar ist, plus der Begriff, der anstoß war.
-- Der zweite Rückgabewert dient nur dem Protokoll.
--
-- 'padded' ist der normalisierte Name mit je einem Leerzeichen links und
-- rechts. Damit wird die Wortgrenze zum Muster, ohne dass eine Regex
-- gebraucht wird:
--
--   ' bass '      trifft  Bass        (Wortgrenze davor und danach)
--   ' bassist '   trifft  Bass nicht  (danach steht ein Buchstabe)
--   ' scheiss'    trifft  Scheißkopf  (Vorsilbe, Rest egal)
create or replace function public.check_display_name(raw text)
returns table (blocked boolean, matched text)
language plpgsql
stable
strict
as $$
declare
  padded text;
  hit    text;
begin
  padded := ' ' || public.normalize_name(raw) || ' ';

  -- 1. Wortweise: ' bass ' trifft Bass, nicht Bassist.
  select t.term into hit
    from public.blocked_terms t
   where t.kind = 'word'
     and padded like '% ' || t.norm || ' %'
   limit 1;

  if hit is not null then
    return query select true, hit;
    return;
  end if;

  -- 2. Vorsilben: ' scheiss' trifft Scheißkopf.
  select t.term into hit
    from public.blocked_terms t
   where t.kind = 'compound'
     and padded like '% ' || t.norm || '%'
   limit 1;

  if hit is not null then
    return query select true, hit;
    return;
  end if;

  -- 3. Wortfolgen: ' kill yourself '.
  select t.term into hit
    from public.blocked_terms t
   where t.kind = 'phrase'
     and padded like '% ' || t.norm || ' %'
   limit 1;

  if hit is not null then
    return query select true, hit;
    return;
  end if;

  return query select false, null::text;
end;
$$;

comment on function public.check_display_name(text) is
  'true, wenn der Anzeigename abgelehnt werden muss. Spiegelbild von '
  'NameGuard.check – siehe Abschnitt 7.';


-- ----------------------------------------------------------------------------
--  3. Tabellen
-- ----------------------------------------------------------------------------

-- --- Sync-Ketten -----------------------------------------------------------
--
-- Ein Snapshot pro Gerät, je Kette. Genau das erzwingt der zusammengesetzte
-- Primärschlüssel: Ein Gerät kann keinen zweiten Snapshot in derselben Kette
-- anlegen, und ein Upsert ersetzt seinen alten.
create table if not exists chain_snapshots (
  chain_id          text        not null,
  device_id         text        not null,

  -- Frei wählbar, wird nur in der Geräteliste angezeigt. Nicht verschlüsselt.
  device_name       text        not null default '',

  updated_at        timestamptz not null default now(),
  includes_settings boolean     not null default false,

  -- Die verschlüsselte Hülle. Wird nie gelesen, nur gespeichert und
  -- unverändert zurückgegeben. Details siehe Abschnitt 6 zur Größe.
  envelope          jsonb       not null,

  constraint chain_snapshots_pkey
    primary key (chain_id, device_id),

  -- Die IDs stammen aus base64url(SHA-256) bzw. Hex. Alles andere abzulehnen
  -- ist reine Härtung: Ohne diese Prüfung könnte ein Aufruf mit einem
  -- Bezeichner wie '../../etc' in einem Dateinamen oder Vergleich landen.
  constraint chain_snapshots_chain_id_format
    check (chain_id ~ '^[A-Za-z0-9_-]{1,128}$'),
  constraint chain_snapshots_device_id_format
    check (device_id ~ '^[A-Za-z0-9_-]{1,128}$'),

  -- Grenzen aus Limits.maxDeviceNameLength
  constraint chain_snapshots_device_name_length
    check (char_length(device_name) <= 60),

  -- Die Hülle muss die vier erwarteten Felder haben. Nur eine Formprüfung:
  -- ob der Inhalt sinnvoll ist, weiß nur der Client mit dem Schlüssel.
  constraint chain_snapshots_envelope_shape
    check (
      jsonb_typeof(envelope) = 'object'
      and envelope ? 'v'
      and envelope ? 'iv'
      and envelope ? 'ct'
      and envelope ? 'mac'
      and jsonb_typeof(envelope -> 'kdf') = 'object'
    )
);

comment on table chain_snapshots is
  'Verschlüsselte Snapshots je Gerät einer Sync-Kette. Der Inhalt ist für den '
  'Server nicht lesbar.';

-- Für die Geräteliste: alle Geräte einer Kette, neueste zuerst.
create index if not exists chain_snapshots_by_chain
  on chain_snapshots (chain_id, updated_at desc);

-- Aufräumen verwaister Ketten (Abschnitt 6).
create index if not exists chain_snapshots_stale
  on chain_snapshots (updated_at);


-- --- Shares ----------------------------------------------------------------
create table if not exists shares (
  id              text        not null,

  -- Metadaten im Klartext. Sie stehen in der Suchliste der Schule und
  -- müssen deshalb lesbar sein – der Inhalt des Shares nicht.
  owner_username  text        not null,
  school_number   text        not null,
  display_name    text        not null,
  label           text        not null default '',

  searchable      boolean     not null default false,
  is_global       boolean     not null default false,
  updated_at      timestamptz not null default now(),

  -- Die verschlüsselten Hülln: byUsername, byPassword, bySchool.
  -- Welche vorhanden sind, bestimmt, wie der Share zu öffnen ist.
  envelopes       jsonb       not null,

  constraint shares_pkey primary key (id),

  constraint shares_id_format
    check (id ~ '^[A-Za-z0-9_-]{1,128}$'),

  -- Grenzen aus Limits.maxUsernameLength
  constraint shares_username_length
    check (char_length(owner_username) between 1 and 60),
  -- Grenze aus Limits.maxShareSchoolLength
  constraint shares_school_length
    check (char_length(school_number) between 1 and 32),
  -- Grenzen aus Limits.maxDisplayNameLength
  constraint shares_display_name_length
    check (char_length(display_name) between 2 and 40),
  -- Grenze aus Limits.maxLabelLength
  constraint shares_label_length
    check (char_length(label) <= 60),

  -- Mindestens eine Hülle, und nur die drei bekannten. Eine Hülle mit
  -- unbekanntem Namen würde nie geöffnet und wäre toter Ballast.
  --
  -- `envelopes - 'a' - 'b' - 'c'` entfernt die drei bekannten Schlüssel; was
  -- übrig bleibt, muss leer sein. Damit ist zugleich "höchstens drei" erfüllt,
  -- weil es nur drei erlaubte gibt.
  --
  -- Bewusst kein `jsonb_object_length`: Die Funktion existiert in Postgres
  -- nicht, und `jsonb_object_keys` ist eine Mengenfunktion – die darf in
  -- einem CHECK-Constraint nicht als Subquery stehen. Der `-`-Operator ist
  -- skalar und immutable, deshalb funktioniert er.
  constraint shares_envelopes_shape
    check (
      jsonb_typeof(envelopes) = 'object'
      and envelopes <> '{}'::jsonb
      and (envelopes - 'byUsername' - 'byPassword' - 'bySchool') = '{}'::jsonb
    ),

  -- Abgeleitet, gespeichert. Der Vorteil gegenüber zwei normalen Spalten:
  -- Die Flags *können* nicht von den Hüllen abweichen, weil sie aus ihnen
  -- berechnet werden. Beim bisherigen Dart-Server werden sie pro Anfrage
  -- berechnet; ein von Hand geänderter Datensatz konnte dort abweichen.
  --
  -- Rückfällt `?` für jsonb nicht als IMMUTABLE durch, muss statt der
  -- Spalten ein BEFORE-INSERT/UPDATE-Trigger diese beiden Felder setzen.
  has_password boolean generated always as
    (envelopes ? 'byPassword') stored,

  unlockable_with_school boolean generated always as
    (envelopes ? 'bySchool') stored
);

comment on table shares is
  'Verschlüsselte Shares. Nur die Metadaten sind für den Server lesbar – '
  'genau das, was die Suche braucht.';

-- Das Suchmenü. Partial Index, weil `searchable` selten wahr ist: Nur die
-- wenigen Zeilen, die im Verzeichnis überhaupt auftauchen dürfen, werden
-- überhaupt indiziert.
--
-- Wichtig: **kein** Filter auf is_global hier. Ein globaler Share ist
-- nutzbar von jeder Schule, taucht aber nur im Verzeichnis seiner eigenen
-- Schulnummer auf.
create index if not exists shares_directory
  on shares (school_number, updated_at desc)
  where searchable;

-- Für die Mengenbegrenzung je Person (Abschnitt 4).
create index if not exists shares_by_owner
  on shares (owner_username, school_number);

-- Aufräumen verwaister Shares (Abschnitt 6).
create index if not exists shares_stale on shares (updated_at);


-- ----------------------------------------------------------------------------
--  4. Trigger: Mengenbegrenzung und Namensprüfung
-- ----------------------------------------------------------------------------

-- Höchstzahl an Geräten je Kette: Limits.maxDevicesPerChain
--
-- Das Zählen passiert **vor** dem Einfügen, also zählt die eigene Zeile noch
-- nicht mit. Deshalb wird gegen ein Gerät, das es schon gibt, nichts geprüft:
-- Wer seinen Snapshot erneuert, muss auch in einer voll besetzten Kette
-- weiterkommen, sonst wäre Sync nach dem 12. Gerät für alle tot.
--
-- Ohne diese Ausnahme ist die Kette nach dem 12. Gerät blockiert – auch für
-- die Geräte, die schon drin sind. Beim Testen des Schemas ist genau das
-- aufgefallen.
create or replace function public.enforce_device_limit()
returns trigger
language plpgsql
as $$
begin
  -- Bekanntes Gerät? Dann ist es eine Erneuerung, keine Neuaufnahme.
  if exists (
       select 1 from chain_snapshots
        where chain_id = new.chain_id
          and device_id = new.device_id
     ) then
    return new;
  end if;

  if (select count(*) from chain_snapshots where chain_id = new.chain_id) >= 12 then
    raise exception 'tooManyDevices'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists chain_snapshots_device_limit on chain_snapshots;
create trigger chain_snapshots_device_limit
  before insert on chain_snapshots
  for each row execute function public.enforce_device_limit();


-- Höchstzahl an Shares je Person und Schule: Limits.maxSharesPerUser
create or replace function public.enforce_share_limit()
returns trigger
language plpgsql
as $$
declare
  existing integer;
begin
  if exists (select 1 from shares where id = new.id) then
    return new;   -- Aktualisierung eines vorhandenen Shares
  end if;

  select count(*) into existing
    from shares
   where owner_username = new.owner_username
     and school_number = new.school_number;

  if existing >= 50 then
    raise exception 'tooManyShares'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists shares_share_limit on shares;
create trigger shares_share_limit
  before insert or update on shares
  for each row execute function public.enforce_share_limit();


-- Namensprüfung. Der zweite Teil ist der eigentliche Grund für diesen
-- Trigger: Ein Aufrufer kann display_name direkt setzen, und genau das wäre
-- eine Umgehung der Prüfung in der App.
create or replace function public.enforce_display_name()
returns trigger
language plpgsql
as $$
declare
  verdict record;
begin
  -- Die structuralen Grenzen (Länge, Zeichen) stehen als CHECK in der
  -- Tabelle; hier geht es nur um den Inhalt.
  select * into verdict from public.check_display_name(new.display_name);
  if verdict.blocked then
    raise exception 'nameBlocked'
      using errcode = 'check_violation', detail = verdict.matched;
  end if;
  return new;
end;
$$;

drop trigger if exists shares_name_check on shares;
create trigger shares_name_check
  before insert or update of display_name on shares
  for each row execute function public.enforce_display_name();


-- ----------------------------------------------------------------------------
--  4b. Drosselung
-- ----------------------------------------------------------------------------
--
--  Supabase bringt keine Drosselung mit. Ohne diese Tabelle koennte jeder die
--  Functions so aufreihen, dass das Aufrufkontingent des Projekts leerlaeuft –
--  und im Free-Tier ist das Kontingent die Betriebsgrenze.
--
--  Warum in der Datenbank und nicht im Speicher der Function: Jeder Aufruf
--  laeuft in einer eigenen, kurzlebigen Umgebung. Ein `Map` im Modul waere
--  beim naechsten Aufruf weg und wuerde nichts zaehlen – scheinbar wirksam,
--  tatsaechlich wirkungslos. Genau die Sorte Fehler, die man erst im
--  Produktivbetrieb bemerkt.

create table if not exists rate_limit (
  -- zusammengesetzt aus "aktion:ip", z.B. "chain-put:203.0.113.7"
  bucket          text        primary key,
  window_started  timestamptz not null,
  hits            integer     not null default 0
);

comment on table rate_limit is
  'Zaehler fuer die Drosselung je IP. Wird von den Edge Functions ueber '
  'bump_rate_limit() gefuehrt.';

-- Eine Anfrage gleichzeitig erhoehen und pruefen. Ein einzelnes Statement ist
-- atomar: Zwei gleichzeitige Anfragen koennen sich nicht beide "unter dem
-- Limit" einordnen, was bei getrenntem Lesen und Schreiben passieren wuerde.
--
-- `p_window_start` kommt aus der Function und ist "jetzt minus Fenster": Liegt
-- der gespeicherte Wert davor, beginnt das Fenster neu.
--
-- Der erste Teil liest die alte Zeile bewusst einmal in eine Variable. Ein
-- `ON CONFLICT DO UPDATE` wertet zwar alle Spaltenausdruecke gegen die alte
-- Zeile aus – aber sobald `window_started` zuerst geschrieben wurde, sieht der
-- zweite Ausdruck schon den **neuen** Wert. Die Reihenfolge von `SET` ist also
-- nicht beliebig, und `r.window_started` in beiden Ausdruecken zu verwenden
-- fuehrt dazu, dass ein abgelaufenes Fenster nie zurueckgesetzt wird: Der
-- Zaehler bleibt auf seinem alten Stand und der Aufrufer wird dauerhaft
-- abgewiesen. Beim Testen genau das passiert.
create or replace function public.bump_rate_limit(
  p_bucket        text,
  p_window_start  timestamptz,
  p_limit         integer
)
returns boolean
language plpgsql
volatile
as $$
declare
  previous record;
  expired  boolean;
  after    integer;
begin
  -- In einem `INSERT ... ON CONFLICT` gibt es kein "else", und sich auf die
  -- vom Konflikt betroffene Zeile zu beziehen ist hier nicht moeglich: Die
  -- Referenz `r` bezieht sich auf die neue Zeile, und sobald `window_started`
  -- geschrieben wurde, sieht jeder weitere Ausdruck schon den neuen Wert.
  --
  -- Deshalb wird die alte Zeile zuerst gelesen und in einem `record`
  -- festgehalten. `previous` bleibt unveraendert, egal was der Upsert
  -- danach mit der Zeile macht.
  select r.window_started, r.hits
    into previous
    from public.rate_limit r
   where r.bucket = p_bucket;

  -- Kein Eintrag oder ein altes Fenster: neu beginnen. Sonst hochzaehlen.
  expired := previous.window_started is null
          or previous.window_started <= p_window_start;

  if expired then
    insert into public.rate_limit as r (bucket, window_started, hits)
    values (p_bucket, now(), 1)
    on conflict (bucket) do update
         set hits = 1, window_started = now();
  else
    insert into public.rate_limit as r (bucket, window_started, hits)
    values (p_bucket, previous.window_started, previous.hits + 1)
    on conflict (bucket) do update
         set hits = previous.hits + 1;
  end if;

  select r.hits into after
    from public.rate_limit r
   where r.bucket = p_bucket;

  return after <= p_limit;
end;
$$;

comment on function public.bump_rate_limit is
  'Erhoeht den Zaehler je Schluessel und liefert true, solange das Limit nicht '
  'ueberschritten ist.';

-- Nur die Functions duerfen zaehlen. Der Aufrufer darf weder lesen noch
-- fremde Zaehler zuruecksetzen.
revoke all on public.rate_limit from anon, authenticated;
grant execute on function public.bump_rate_limit(text, timestamptz, integer)
  to service_role;

-- Das Aufraeumen (Abschnitt 6) loescht diese Zeilen mit.


-- ----------------------------------------------------------------------------
--  5. Zugriffsschutz
-- ----------------------------------------------------------------------------
--
--  Absicht: Von außen ist **nichts** erreichbar. Nur die Edge Functions
--  kommen an die Tabellen, und die benutzen den service_role, der RLS
--  umgeht. Das ist der Punkt, den man leicht übersieht – eine offen
--  gelassene Tabelle mit RLS, die "vielleicht braucht die App das später",
--  ergibt sehr schnell Schreibrecht auf allem.
--
--  Zur Prüfung (siehe README):
--    curl "$URL/rest/v1/shares" -H "apikey: $ANON_KEY"
--    → muss 401 oder eine leere Liste liefern, niemals Zeilen

alter table public.chain_snapshots enable row level security;
alter table public.shares        enable row level security;

-- RLS verweigert ohne Policy bereits alles. Die ausdrücklichen Policies sind
-- trotzdem sinnvoll: Wer später versehentlich eine Policy hinzufügt, ersetzt
-- damit diese hier nicht ungewollt, und die Absicht steht im Code.
drop policy if exists "no direct client access to chain_snapshots"
  on public.chain_snapshots;
create policy "no direct client access to chain_snapshots"
  on public.chain_snapshots
  for all
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists "no direct client access to shares" on public.shares;
create policy "no direct client access to shares"
  on public.shares
  for all
  to anon, authenticated
  using (false)
  with check (false);

-- Zweites Schloss: Selbst bei einem Fehler in der Policy sollen die Rollen
-- keine Rechte auf die Tabellen haben.
revoke all on public.chain_snapshots from anon, authenticated;
revoke all on public.shares        from anon, authenticated;

-- Die Gegenrichtung muss man ausdrücklich herstellen. Auf Supabase ist
-- `service_role` bereits vorhanden und hat BYPASSRLS, aber BYPASSRLS allein
-- bedeutet nur "die Zeilenregeln werden übersprungen" – die Tabellenrechte
-- kommen separat über GRANT. Ohne das Grant sieht die Edge Function
-- "permission denied for table shares", obwohl die Rolle berechtigt ist.
--
-- Das hier ist auf Supabase wahrscheinlich schon gesetzt und damit ein
-- No-op; lokal und in frischen Instanzen ist es der Unterschied zwischen
-- "funktioniert" und "funktioniert nicht".
grant all on public.chain_snapshots to service_role;
grant all on public.shares        to service_role;

-- Für alle künftigen Tabellen. Ohne das verliert eine neu angelegte Tabelle
-- die Rechte, sobald jemand sie per ALTER TABLE an einer bestehenden Instanz
-- erweitert.
alter default privileges in schema public
  grant all on tables to service_role;

-- Für die Prüffunktion in Abschnitt 2 braucht der Client nichts, die gehört
-- dem Server. Der folgende Grant ist deshalb **nicht** Teil dieses Schemas –
-- die Functions sind ausschließlich für Edge Functions gedacht, die den
-- service_role benutzen.


-- ----------------------------------------------------------------------------
--  6. Optional: Aufräumen
-- ----------------------------------------------------------------------------
--
--  Ein Sync-Server sammelt sich sonst über Jahre. Der bisherige Dart-Server
--  hat `Limits.shareIdleTimeout` (180 Tage) zwar definiert, aber **nie
--  verwendet** – es gibt dort keinen Aufräumer. Hier ist es mit einer Zeile
--  erledigt.
--
--  pg_cron ist auf Supabase verfügbar, muss aber einmal aktiviert werden:
--    create extension if not exists pg_cron with schema extensions;
--    select cron.schedule(
--      'substitute-sweep',
--      '17 4 * * *',            -- täglich um 04:17
--      $$delete from public.chain_snapshots where updated_at < now() - interval '180 days'$$
--    );
--    select cron.schedule(
--      'substitute-sweep-shares',
--      '23 4 * * *',
--      $$delete from public.shares where updated_at < now() - interval '180 days'$$
--    );
--
--  Zwei Anmerkungen dazu:
--
--  * 180 Tage müssen mehr sein als die Schulferien. Wer in den Sommerferien
--    über sechs Wochen nicht synchronisiert und dann seinen Chain löscht,
--    verliert sonst die Historie. Bei 365 Tagen ist das entspannter.
--
--  * Das Aufräumen von Chains ist heikel: Eine Kette besteht aus mehreren
--    Snapshots, und ein Gerät, das drei Monate offline war (Urlaub,
--    Reparatur) lädt beim nächsten Sync einen Snapshot hoch, den alle anderen
--    schon gelöscht haben. Der Server löscht besser nur Geräte, die seit
--    über einem Jahr nichts geschickt haben, und lässt die Kette selbst
--    stehen.

-- ----------------------------------------------------------------------------
--  7. Die Liste in Abschnitt 2 muss mit der App übereinstimmen
-- ----------------------------------------------------------------------------
--
--  Diese SQL-Fassung ist eine **Neuschreibung** der Logik aus
--  `lib/services/sync/NameGuard.dart`. Zwei Implementierungen derselben
--  Regel laufen unausweichlich auseinander, und die stillere Drift ist die
--  gefährliche: Ein Name, den die App blockiert, aber der Server nicht, landet
--  trotzdem im Suchverzeichnis.
--
--  Zwei Wege, das zu verhindern:
--
--  1. Einen Test in der App, der jeden Eintrag aus `blocked_terms` durch
--     `NameGuard.check` schickt. Findet die App einen Begriff nicht, schlägt
--     der Build fehl. Umgekehrt gilt das auch – deshalb beide Richtungen
--     prüfen, nicht nur eine.
--
--  2. Besser: Die Liste einmal als JSON im Repo ablegen und beide Seiten
--     daraus erzeugen – die App zur Laufzeit, das SQL als Seed beim Deploy.
--     Dann gibt es nur noch eine Wahrheit.
--
--  Ebenso zu beachten: Die *unbeschränkte* Prüfung steckt in der App
--  (`NameGuard`), die *sichtbaren* Metadaten prüft der Server. Der Server
--  braucht die vollständige Liste, weil ein Aufrufer die App umgehen kann.
--  Umgekehrt braucht die App die Liste, weil sie den Namen schon vor dem
--  Senden prüfen soll – der Nutzer soll nicht erst nach dem Absenden eine
--  Fehlermeldung bekommen.
