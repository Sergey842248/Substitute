/**
 * Zugriff auf die Datenbank.
 *
 * Wichtig: Die Functions benutzen den **service_role**-Key, nicht den
 * anon-Key der App. Grund ist `schema.sql` Abschnitt 5: Für `anon` und
 * `authenticated` ist alles gesperrt, und nur der service_role umgeht RLS.
 * Das ist die einzige Stelle, an der die Datenbank überhaupt erreichbar ist.
 *
 * Der service_role-Key ist damit das Geheimnis dieser Installation. Er darf
 * nicht in die App, nicht ins Repo und nicht in ein Log – Supabase liefert
 * ihn den Functions automatisch als Umgebungsvariable.
 */

import { PostgrestClient } from 'npm:@supabase/postgrest-js@2';
import { ApiError, clientAddress, MAX_DEVICES_PER_CHAIN, MAX_SHARES_PER_USER } from './http.ts';

/** Der Typ, den die Functions benutzen. */
export type Db = PostgrestClient;

/**
 * Ein PostgREST-Client pro Aufruf.
 *
 * Bewusst `PostgrestClient` und nicht `createClient` aus supabase-js: Der
 * Supabase-Client legt seinen PostgREST-Client in `SupabaseClient.ts` beim
 * Konstruieren selbst an (`this.rest = new PostgrestClient(...)`) und bietet
 * keine Möglichkeit, einen eigenen einzusetzen. Er baut die Adresse aus
 * `SUPABASE_URL` und leitet daraus einen Postgres-Port ab – was auf Supabase
 * zufällig stimmt und überall sonst in einem ECONNREFUSED auf Port 5432
 * endet. Genau das ist beim ersten Testen passiert.
 *
 * Für reine Datenbankzugriffe ist der Supabase-Client ohnehin der falsche
 * Griff: Er bringt Auth, Realtime und Storage mit, von denen hier nichts
 * gebraucht wird.
 */
export function db(): Db {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) {
    // Das ist ein Konfigurationsfehler, kein Angriffsversuch – deshalb 500
    // und ein klarer Text im Log.
    console.error('SUPABASE_URL oder SUPABASE_SERVICE_ROLE_KEY fehlt');
    throw new ApiError('serverError', 500, 'missing env');
  }

  return new PostgrestClient(`${url.replace(/\/+$/, '')}/rest/v1`, {
    headers: { apikey: key, Authorization: `Bearer ${key}` },
  });
}

/**
 * Einfache Drosselung je IP.
 *
 * Supabase bringt keine mit, und ohne Drosselung kann jeder die Functions
 * so aufreihen, dass das Kontingent des Projekts leerläuft. Bewusst nach
 * *schreibenden* Zugriffen: Lesende Zugriffe sind häufig (jeder Sync zieht
 * die Kette) und sollen nicht limitiert werden.
 *
 * Die Zählung liegt in der Datenbank statt im Speicher der Function, weil
 * jede Function-Aufruf eine frische, kurzlebige Umgebung ist – ein `Map` im
 * Modul würde nach dem nächsten Aufruf weg sein und nichts zählen.
 */
export async function throttle(
  client: Db,
  address: string,
  bucket: string,
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const windowStart = new Date(Date.now() - windowSeconds * 1000).toISOString();

  // Ein einzelnes Statement: Zähler erhöhen, wenn das Fenster noch offen ist,
  // sonst neu beginnen. Dadurch ist das Ganze atomar – zwei gleichzeitige
  // Anfragen können sich nicht beide „unter dem Limit" einordnen.
  const { error } = await client.rpc('bump_rate_limit', {
    p_key: `${bucket}:${address}`,
    p_window_start: windowStart,
    p_limit: limit,
  });

  if (error) {
    // Eine defekte Drosselung darf Anfragen nicht blockieren. Der Fehler
    // fällt auf, wird protokolliert und die Anfrage läuft weiter – lieber
    // ungedrosselt als gar nicht.
    console.error(`Drosselung fehlgeschlagen: ${error.message}`);
    return;
  }
}

// ---------------------------------------------------------------------------
// Typen
// ---------------------------------------------------------------------------

export type Envelope = Record<string, unknown>;

/** Ein Snapshot, wie er in der Tabelle liegt (snake_case). */
export interface SnapshotRow {
  chain_id: string;
  device_id: string;
  device_name: string;
  updated_at: string;
  includes_settings: boolean;
  envelope: Envelope;
}

/** Ein Share, wie er in der Tabelle liegt. */
export interface ShareRow {
  id: string;
  owner_username: string;
  school_number: string;
  display_name: string;
  label: string;
  searchable: boolean;
  is_global: boolean;
  updated_at: string;
  envelopes: Record<string, Envelope>;
  has_password: boolean;
  unlockable_with_school: boolean;
}

/** Die Form, die `SyncApiClient` in der App erwartet. */
export interface DeviceDto {
  deviceId: string;
  deviceName: string;
  updatedAt: string;
  includesSettings: boolean;
}

export function toDeviceDto(row: SnapshotRow): DeviceDto {
  return {
    deviceId: row.device_id,
    deviceName: row.device_name,
    // Supabase gibt timestamptz als ISO-String zurück. Ohne das `Z` hätte die
    // App eine Ortszeit interpretiert – ein Gerät in einer anderen Zeitzone
    // läge dann Stunden daneben.
    updatedAt: new Date(row.updated_at).toISOString(),
    includesSettings: row.includes_settings,
  };
}

// ---------------------------------------------------------------------------
// Pruefungen
// ---------------------------------------------------------------------------

/**
 * Prueft die Form einer Sync-Huelle.
 *
 * Nur eine Formpruefung: Ob der Inhalt sinnvoll ist, weiss ausschliesslich
 * der Client mit dem passenden Schluessel. Der `envelope`-Pfad in der
 * Datenbank macht dieselbe Pruefung noch einmal, weil Trigger billiger zu
 * pflegen sind als jeder Aufrufer.
 */
export function isValidEnvelope(value: unknown): value is Envelope {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return false;
  }
  const envelope = value as Record<string, unknown>;
  return (
    typeof envelope.v === 'number' &&
    typeof envelope.iv === 'string' &&
    typeof envelope.ct === 'string' &&
    typeof envelope.mac === 'string' &&
    typeof envelope.kdf === 'object' &&
    envelope.kdf !== null
  );
}

export { MAX_DEVICES_PER_CHAIN, MAX_SHARES_PER_USER };
