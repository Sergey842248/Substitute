/**
 * Shares: anlegen, lesen, loeschen.
 *
 *   GET    ?id=X      einen Share samt Huellen
 *   PUT              anlegen oder aktualisieren
 *   DELETE ?id=X      loeschen
 *
 * Der Server kann den Inhalt nicht lesen – er speichert `envelopes` als
 * unlesbaren Blob. Was im Klartext steht, ist genau das, was die Suche
 * braucht: Nutzername, Schulnummer, Anzeigename, Label und die zwei
 * Flags. Mehr nicht.
 */

import {
  ApiError,
  MAX_DISPLAY_NAME_LENGTH,
  MAX_LABEL_LENGTH,
  MAX_USERNAME_LENGTH,
  clampText,
  clientAddress,
  handle,
  isValidId,
  isValidSchoolNumber,
  json,
  idParam,
  readJson,
  serve,
} from '../_shared/http.ts';
import {
  db,
  isValidEnvelope,
  throttle,
  type ShareRow,
} from '../_shared/db.ts';

const WRITE_LIMIT = 30;

/** Die drei Sorten von Huellen. Unbekannte Namen waeren toter Ballast. */
const KNOWN_SLOTS = ['byUsername', 'byPassword', 'bySchool'] as const;

serve(async (req): Promise<Response> => {
    const client = db();

    switch (req.method) {
      case 'GET':
        return await getShare(req, client);
      case 'PUT':
        return await putShare(req, client);
      case 'DELETE':
        return await deleteShare(req, client);
      default:
        throw new ApiError('forbidden', 405, `Methode ${req.method}`);
    }
});

// ---------------------------------------------------------------------------

async function getShare(req: Request, client: ReturnType<typeof db>): Promise<Response> {
  const id = idParam(req, 'id');
  if (!isValidId(id)) {
    throw new ApiError('invalidShare', 400, 'id');
  }

  const { data, error } = await client
    .from('shares')
    .select(
      'id, owner_username, school_number, display_name, label, searchable, is_global, updated_at, envelopes, has_password, unlockable_with_school',
    )
    .eq('id', id)
    .maybeSingle();

  if (error) throw error;
  if (!data) {
    // Leer ist hier ein Fehler: Die App unterscheidet an dieser Stelle
    // "kein Share mit diesem Nutzernamen" von "Server kaputt".
    throw new ApiError('shareNotFound', 404, id);
  }

  const row = data as ShareRow;
  return json({
    id: row.id,
    owner: {
      username: row.owner_username,
      schoolNumber: row.school_number,
      displayName: row.display_name,
    },
    label: row.label,
    // Von Postgres vorkalkuliert und deshalb nicht abhaengig von den
    // tatsaechlich vorhandenen Huellen: Die beiden Flags *koennen* nicht von
    // ihnen abweichen.
    hasPassword: row.has_password,
    unlockableWithSchoolCredentials: row.unlockable_with_school,
    isGlobal: row.is_global,
    updatedAt: new Date(row.updated_at).toISOString(),
    // Unveraendert durchgereicht. `has_password` und
    // `unlockable_with_school_credentials` sind nur Kurzformen; die App
    // entscheidet aber ueber `envelopes`, welcher Schluessel passt.
    envelopes: row.envelopes,
  });
}

// ---------------------------------------------------------------------------

async function putShare(req: Request, client: ReturnType<typeof db>): Promise<Response> {
  await throttle(client, clientAddress(req), 'share-put', WRITE_LIMIT, 60);

  const body = await readJson(req);

  const id = body.id;
  if (!isValidId(id)) {
    throw new ApiError('invalidShare', 400, 'id');
  }

  const owner = body.owner;
  if (typeof owner !== 'object' || owner === null || Array.isArray(owner)) {
    throw new ApiError('invalidShare', 400, 'owner');
  }
  const ownerRecord = owner as Record<string, unknown>;

  const username = typeof ownerRecord.username === 'string'
    ? ownerRecord.username.trim()
    : '';
  if (username.length < 1 || username.length > MAX_USERNAME_LENGTH) {
    throw new ApiError('invalidShare', 400, 'username');
  }

  // Die Rumpf-Felder heissen snake_case, weil sie 1:1 in die Spalten der
  // Datenbank gehen. `chain-snapshots` macht es so, und zwei Functions mit
  // unterschiedlichen Formaten sind der sicherste Weg zu einem Fehler, den
  // erst ein Gerät findet.
  const schoolNumber = typeof ownerRecord.school_number === 'string'
    ? ownerRecord.school_number.trim()
    : '';
  if (!isValidSchoolNumber(schoolNumber)) {
    throw new ApiError('invalidShare', 400, 'schoolNumber');
  }

  const displayName = typeof ownerRecord.display_name === 'string'
    ? ownerRecord.display_name.trim()
    : '';
  if (displayName.length < 2 || displayName.length > MAX_DISPLAY_NAME_LENGTH) {
    throw new ApiError('invalidShare', 400, 'displayName');
  }

  const label = clampText(body.label, MAX_LABEL_LENGTH);

  const envelopes = parseEnvelopes(body.envelopes);

  // Die Grenze "50 Shares je Person" prueft der Trigger in schema.sql. Sie
  // hier noch einmal zu machen waere doppelt – der Trigger greift auch bei
  // einem direkten Weg an der Function vorbei, und genau darauf beruht die
  // Absicht.

  const { error } = await client.from('shares').upsert(
    {
      id,
      owner_username: username,
      school_number: schoolNumber,
      display_name: displayName,
      label,
      searchable: body.searchable === true,
      is_global: body.is_global === true,
      // Der Zeitstempel kommt vom Geraet, nicht vom Server: Bei einem
      // passwortgeschuetzten Share entscheidet die Aenderungszeit in der
      // Geraeteliste darueber, wer zuletzt daran war. Eine Serverzeit waere
      // hier ein stummer Datenverlust.
      updated_at: String(body.updated_at ?? new Date().toISOString()),
      envelopes,
    },
    { onConflict: 'id' },
  );

  // Der Name-Trigger in schema.sql wirft hier `nameBlocked`. Das wird in
  // `toApiError` auf 400 mit `invalidShare` abgebildet; die App prueft den
  // Namen allerdings schon selbst, bevor sie sendet – diese zweite Instanz
  // ist nur das Netz gegen einen direkten Aufruf der Schnittstelle.
  if (error) throw error;

  return json({ id, storedAt: new Date().toISOString() });
}

/**
 * Prueft die mitgeschickten Huellen.
 *
 * Entscheidend ist, *dass* eine passende da ist, nicht *welche*: Ist ein
 * Share passwortgeschuetzt, entfaellt `byUsername`, und genau daran
 * erkennt die App, dass der Nutzername allein nicht mehr genuegt.
 */
function parseEnvelopes(value: unknown): Record<string, Record<string, unknown>> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new ApiError('invalidShare', 400, 'envelopes');
  }
  const source = value as Record<string, unknown>;
  const result: Record<string, Record<string, unknown>> = {};

  for (const slot of KNOWN_SLOTS) {
    const envelope = source[slot];
    if (envelope === undefined) continue;
    if (!isValidEnvelope(envelope)) {
      throw new ApiError('invalidShare', 400, `envelopes.${slot}`);
    }
    result[slot] = envelope;
  }

  if (Object.keys(result).length === 0) {
    throw new ApiError('invalidShare', 400, 'keine Huelle');
  }
  return result;
}

// ---------------------------------------------------------------------------

async function deleteShare(req: Request, client: ReturnType<typeof db>): Promise<Response> {
  await throttle(client, clientAddress(req), 'share-delete', WRITE_LIMIT, 60);

  const id = idParam(req, 'id');
  if (!isValidId(id)) {
    throw new ApiError('invalidShare', 400, 'id');
  }

  const { data, error } = await client
    .from('shares')
    .delete()
    .eq('id', id)
    .select('id');

  if (error) throw error;
  const removed = (data ?? []).length > 0;

  return json({ removed }, removed ? 200 : 404);
}
