/**
 * Gemeinsame Grundlagen für alle Edge Functions.
 *
 * Hier steht alles, was an mehreren Stellen gebraucht wird und was
 * bewusst *nicht* in der App steht: Grenzwerte, Fehlercodes und die
 * Namensprüfung. Die Werte müssen mit `lib/services/crypto/PayloadCrypto.dart`,
 * `lib/services/sync/SyncApiClient.dart` und `Limits` in
 * `docs/server/lib/src/limits.dart` übereinstimmen.
 */

// ---------------------------------------------------------------------------
// Grenzwerte
// ---------------------------------------------------------------------------

/** Höchstgröße eines Anfragetexts. Entspricht `Limits.maxBodyBytes`. */
export const MAX_BODY_BYTES = 16 * 1024 * 1024;

/** Höchstzahl an Geräten in einer Kette. Entspricht `Limits.maxDevicesPerChain`. */
export const MAX_DEVICES_PER_CHAIN = 12;

/** Höchstzahl an Shares je Person. Entspricht `Limits.maxSharesPerUser`. */
export const MAX_SHARES_PER_USER = 50;

/** Höchstzahl an Geräten, die eine Antwort auflistet. */
export const MAX_DIRECTORY_ENTRIES = 500;

export const MAX_USERNAME_LENGTH = 60;
export const MAX_DISPLAY_NAME_LENGTH = 40;
export const MAX_LABEL_LENGTH = 60;
export const MAX_DEVICE_NAME_LENGTH = 60;
export const MAX_SCHOOL_NUMBER_LENGTH = 32;

/**
 * Obergrenze für Bezeichner.
 *
 * Die IDs der App sind base64url-kodierte SHA-256-Digests, also 43 Zeichen.
 * Erlaubt sind deshalb nur `A-Za-z0-9_-`. Alles andere abzulehnen ist reine
 * Härtung: Ohne diese Prüfung könnte ein Aufruf mit einem Bezeichner wie
 * `../` in einem Vergleich oder Dateinamen landen.
 */
const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

/** Prüft einen Bezeichner und gibt ihn bereinigt zurück, oder `null`. */
export function isValidId(value: unknown): value is string {
  return typeof value === 'string' && ID_PATTERN.test(value);
}

/** Kürzt Text auf eine Höchstlänge, ohne mitten im Wort zu zerreißen. */
export function clampText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().length > max ? value.trim().slice(0, max) : value.trim();
}

// ---------------------------------------------------------------------------
// Fehler
// ---------------------------------------------------------------------------

/**
 * Fehlercodes, die `SyncApiClient` in der App kennt.
 *
 * Die App übersetzt sie in eigenen Text; steht hier etwas anderes, sieht der
 * Nutzer eine kryptische Fehlermeldung. Deshalb sind es exakt die Codes aus
 * `SyncException.defaultMessages`.
 */
export type ErrorCode =
  | 'invalidJson'
  | 'invalidEncoding'
  | 'invalidShare'
  | 'invalidSnapshot'
  | 'notFound'
  | 'shareNotFound'
  | 'forbidden'
  | 'conflict'
  | 'tooManyDevices'
  | 'tooManyShares'
  | 'tooManyRequests'
  | 'tooLarge'
  | 'serverError';

/** Der Fehler, den eine Function zurückgibt, wenn etwas nicht stimmt. */
export class ApiError extends Error {
  constructor(
    readonly code: ErrorCode,
    readonly status: number,
    /** Nur für das Protokoll, geht nicht an den Client. */
    readonly detail?: string,
  ) {
    super(code);
    this.name = 'ApiError';
  }
}

/**
 * Fängt Fehler aus der Datenbank und übersetzt sie.
 *
 * Nötig, weil die Trigger in `schema.sql` bewusst mit einer sprechenden
 * Meldung arbeiten (`raise exception 'tooManyDevices'`), und weil ein
 * ungehandelter Datenbankfehler sonst als 500 mit SQL-Interna nach außen
 * ginge. Der genaue Wortlaut von Postgres verrät Table- und Spaltennamen.
 */
export function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;

  const message = error instanceof Error ? error.message : String(error);
  // Postgres-Fehler tragen ihre SQLSTATE in `code`, den Text in `message`.
  const postgresCode =
    typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code: unknown }).code)
      : '';

  if (postgresCode === '23514' || postgresCode === '23505' || postgresCode === 'P0001') {
    // check_violation / unique_violation / raise_exception
    switch (message) {
      case 'tooManyDevices':
        return new ApiError('tooManyDevices', 409, message);
      case 'tooManyShares':
        return new ApiError('tooManyShares', 409, message);
      case 'nameBlocked':
        // 400 ist hier richtig: Der Aufrufer muss den Namen ändern, nicht
        // später noch einmal versuchen.
        return new ApiError('invalidShare', 400, message);
      default:
        return new ApiError('invalidShare', 400, message);
    }
  }

  if (postgresCode === '23503' || postgresCode === '23502') {
    return new ApiError('invalidShare', 400, message);
  }

  return new ApiError('serverError', 500, message);
}

/**
 * Der rohe Fehlertext, so wie er aus der Datenbank kommt.
 *
 * Nur für die Fehlersuche. `toApiError` verschluckt den Postgres-Text
 * absichtlich, weil er Spalten- und Tabellennamen verrät – wenn man aber
 * herausfinden muss, warum ein Upsert scheitert, ist genau das die
 * Information, die man braucht.
 */
export function rawErrorText(error: unknown): string {
  if (typeof error === 'object' && error !== null) {
    const parts: string[] = [];
    for (const key of ['code', 'message', 'details', 'hint']) {
      const value = (error as Record<string, unknown>)[key];
      if (value !== undefined && value !== null) parts.push(`${key}=${value}`);
    }
    if (parts.length > 0) return parts.join(' ');
  }
  return error instanceof Error ? error.message : String(error);
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------

/** Antwortkopfzeilen. */
export const CORS_HEADERS: Record<string, string> = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, PUT, DELETE, OPTIONS',
  'access-control-allow-headers':
    'authorization, x-client-info, apikey, content-type',
  'access-control-max-age': '86400',
};

/**
 * Beantwortet eine Anfrage einheitlich.
 *
 * Wird von jeder Function einmal aufgerufen, damit CORS-Vorabfragen,
 * Fehlerbehandlung und Größenbegrenzung überall gleich sind und nicht
 * viermal neu erfunden werden.
 *
 * Aufruf als `Deno.serve(handle)`: `handle` hat genau die Signatur, die
 * `Deno.serve` erwartet, und gibt `req` an [fn] weiter.
 */
/**
 * Der Handler, wie `Deno.serve` ihn erwartet.
 *
 * Die Signatur ist bewusst ein Wrapper statt `async`: `Deno.serve` akzeptiert
 * auch eine Coroutine, aber der Rückgabetyp von [handle] wird sonst als
 * `Promise<Response>` statt als `Response | Promise<Response>` inferred und
 * TypeScript lehnt den Aufruf ab. Der Wrapper ist die kleinste Form, die
 * beide Fälle abdeckt.
 */
export function handler(fn: (req: Request) => Promise<Response> | Response) {
  return (req: Request): Response | Promise<Response> => handle(req, fn);
}

/** Wie [handler], aber bindet vorher den Port. */
export function serve(fn: (req: Request) => Promise<Response> | Response): void {
  Deno.serve({ port: localPort() }, handler(fn));
}

export async function handle(
  req: Request,
  fn: (req: Request) => Promise<Response> | Response,
): Promise<Response> {
  // Der Status-Endpunkt wird von der Seite auf GitHub Pages aus dem Browser
  // abgefragt; deshalb braucht er dieselben CORS-Kopfzeilen wie alles andere.
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  try {
    const response = await fn(req);
    for (const [key, value] of Object.entries(CORS_HEADERS)) {
      response.headers.set(key, value);
    }
    // Antworten sind nie zwischenspeicherbar: Ein Sync-Snapshot, der
    // zwischengespeichert würde, ist ein Datenleck über die Zeit.
    response.headers.set('cache-control', 'no-store');
    return response;
  } catch (error) {
    const apiError = toApiError(error);
    // Nur der Code geht nach außen. Der rohe Datenbanktext landet im Log –
    // dort nützt er beim Suchen, dem Client nützt er nichts und er verrät
    // die Struktur der Datenbank.
    console.error(
      `[${apiError.code}] ${rawErrorText(error)}`,
    );
    return json({ error: apiError.code }, apiError.status);
  }
}

/** Antwortet mit JSON. */
export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

/**
 * Liest den Anfragetext als JSON-Objekt.
 *
 * Prüft auch die Größe *vor* dem Lesen: Sonst müsste der Server beliebig
 * große Datenmengen empfangen, nur um sie wieder zu verwerfen.
 */
export async function readJson(req: Request): Promise<Record<string, unknown>> {
  const declared = Number(req.headers.get('content-length') ?? '0');
  if (declared > MAX_BODY_BYTES) {
    throw new ApiError('tooLarge', 413);
  }

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) {
    throw new ApiError('tooLarge', 413);
  }
  if (raw.trim().length === 0) return {};

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new ApiError('invalidJson', 400);
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new ApiError('invalidJson', 400);
  }
  return parsed as Record<string, unknown>;
}

/** Prueft eine Schulnummer: nicht leer, nicht zu lang, nur Ziffern und Trenner. */
export function isValidSchoolNumber(value: unknown): value is string {
  return typeof value === 'string' &&
    value.trim().length > 0 &&
    value.trim().length <= MAX_SCHOOL_NUMBER_LENGTH &&
    /^[\w.-]+$/.test(value.trim());
}

/** Liest einen Query-Parameter. */
export function queryParam(req: Request, name: string): string | null {
  return new URL(req.url).searchParams.get(name);
}

/**
 * Liest einen Bezeichner aus den Query-Parametern.
 *
 * Der Wert kommt PostgREST-kodiert: `?chain_id=eq.abc` ist kein reiner
 * Bezeichner, sondern ein Filterausdruck mit Operator. Das `eq.` muss weg,
 * sonst scheitert jede Prüfung an einem völlig gültigen Wert – und weil der
 * Operator Teil des Parameters ist, kann er auch mehrere Werte enthalten
 * (`eq.abc,def`), von denen hier nur der erste interessiert.
 *
 * Ohne dieses Entfernen lehnt `isValidId` jeden Bezeichner ab, und die
 * Function antwortet auf jede Anfrage mit 400.
 */
export function idParam(req: Request, name: string): string | null {
  const raw = queryParam(req, name);
  if (raw === null) return null;
  const withoutOperator = raw.startsWith('eq.') ? raw.slice(3) : raw;
  return withoutOperator.split(',')[0] || null;
}

/**
 * Der Port, auf dem die Function lauscht.
 *
 * Supabase vergibt den Port selbst und setzt dafür `PORT`. Der Umweg über
 * `localPort()` ist nur für die Tests nötig: lokal laufen die vier Functions
 * in getrennten Prozessen, weil jede für sich `Deno.serve` aufruft. Ohne das
 * würde die zweite den Port der ersten nicht bekommen.
 */
export function localPort(): number {
  return Number(Deno.env.get('PORT') ?? 8000);
}

/** Liefert die aufrufende Adresse, für die Drosselung. */
export function clientAddress(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for');
  if (forwarded) return forwarded.split(',')[0].trim();
  return req.headers.get('cf-connecting-ip') ?? 'unknown';
}
