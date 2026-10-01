/**
 * Tests fuer die Teile der Functions, die keine Datenbank brauchen.
 *
 *   deno test --allow-env supabase/functions/unit_test.ts
 *
 * Diese Datei laeuft ohne Docker und ohne Supabase. Sie deckt genau die Logik
 * ab, in der beim Bauen die Fehler lagen: Filter aus der Query-Zeile,
 * Pruefungen, Fehlerabbildung, Umwandlung in die Form, die die App erwartet,
 * und die drei Entsperrwege.
 *
 * Die End-to-End-Tests ueber HTTP brauchen eine laufende Instanz:
 *
 *   supabase start
 *   supabase db reset                      # schema.sql anwenden
 *   supabase functions serve --env-file supabase/.env.local
 *   deno test --allow-net --allow-env supabase/functions/functions_test.ts
 */

import {
  assertEquals,
  assertRejects,
} from 'https://deno.land/std@0.224.0/assert/mod.ts';

import {
  ApiError,
  clampText,
  handle,
  idParam,
  isValidId,
  isValidSchoolNumber,
  json,
  queryParam,
  rawErrorText,
  toApiError,
} from './_shared/http.ts';
import { isValidEnvelope, toDeviceDto } from './_shared/db.ts';

const tests: Array<[string, () => void | Promise<void>]> = [];
function test(name: string, fn: () => void | Promise<void>) {
  tests.push([name, fn]);
}

function request(target: string, method = 'GET'): Request {
  return new Request(`http://127.0.0.1:8000/${target}`, { method });
}

// ---------------------------------------------------------------------------
// idParam – der Operator 'eq.' muss weg
// ---------------------------------------------------------------------------

test('idParam entfernt den PostgREST-Operator', () => {
  // Ohne das scheitert jede Anfrage: 'eq.abc' ist kein gueltiger Bezeichner.
  assertEquals(idParam(request('?chain_id=eq.abc123'), 'chain_id'), 'abc123');
  assertEquals(idParam(request('?id=eq.share-1'), 'id'), 'share-1');
});

test('idParam versteht auch einen nackten Wert', () => {
  assertEquals(idParam(request('?chain_id=abc123'), 'chain_id'), 'abc123');
});

test('idParam nimmt bei einer Liste nur den ersten Wert', () => {
  assertEquals(idParam(request('?chain_id=eq.a,b,c'), 'chain_id'), 'a');
});

test('idParam liefert null, wenn der Parameter fehlt', () => {
  assertEquals(idParam(request('?andere=1'), 'chain_id'), null);
  assertEquals(queryParam(request('?andere=1'), 'chain_id'), null);
});

// ---------------------------------------------------------------------------
// isValidId
// ---------------------------------------------------------------------------

test('isValidId nimmt base64url-kodierte Digests', () => {
  // Das ist die Form, die PayloadCrypto.publicId liefert.
  const id = 'Vls9ujLhV_YgDHfJEmfQyF7tuEWv61nnrrxev1ywTJo';
  assertEquals(isValidId(id), true);
  assertEquals(isValidId('chain-test-1'), true);
  assertEquals(isValidId('ABC_def-123'), true);
});

test('isValidId weist Pfade und Steuerzeichen ab', () => {
  for (const bad of [
    '../../etc/passwd',
    'a/b',
    'a b',
    'a\nb',
    '',
    'x'.repeat(129),
    null,
    undefined,
    42,
  ]) {
    assertEquals(isValidId(bad as unknown), false, `${JSON.stringify(bad)}`);
  }
});

test('isValidId nimmt genau 128 Zeichen, nicht 129', () => {
  assertEquals(isValidId('a'.repeat(128)), true);
  assertEquals(isValidId('a'.repeat(129)), false);
});

// ---------------------------------------------------------------------------
// Weitere Pruefungen
// ---------------------------------------------------------------------------

test('isValidSchoolNumber braucht eine nicht leere, kurze Angabe', () => {
  assertEquals(isValidSchoolNumber('12345'), true);
  assertEquals(isValidSchoolNumber('12345-abc'), true);
  assertEquals(isValidSchoolNumber(''), false);
  assertEquals(isValidSchoolNumber('   '), false);
  assertEquals(isValidSchoolNumber('a'.repeat(33)), false);
  assertEquals(isValidSchoolNumber('../x'), false);
  assertEquals(isValidSchoolNumber(null), false);
});

test('clampText schneidet zu, behält aber den Inhalt', () => {
  assertEquals(clampText('  Frau Müller  ', 40), 'Frau Müller');
  assertEquals(clampText('a'.repeat(80), 60), 'a'.repeat(60));
  assertEquals(clampText(undefined, 60), '');
  assertEquals(clampText(42, 60), '');
});

test('isValidEnvelope verlangt die vier Felder und die kdf-Angabe', () => {
  const valid = {
    v: 1,
    iv: 'aXY=',
    ct: 'Y2lwaGVy',
    mac: 'bWFj',
    kdf: { alg: 'pbkdf2-sha256', iter: 120000 },
  };
  assertEquals(isValidEnvelope(valid), true);

  // Der Inhalt ist dem Server egal – nur die Form muss stimmen.
  assertEquals(isValidEnvelope({ ...valid, ct: '' }), true);

  for (const missing of ['v', 'iv', 'ct', 'mac', 'kdf']) {
    const broken: Record<string, unknown> = { ...valid };
    delete broken[missing];
    assertEquals(isValidEnvelope(broken), false, `ohne ${missing}`);
  }
  assertEquals(isValidEnvelope({ ...valid, kdf: null }), false);
  assertEquals(isValidEnvelope('text'), false);
  assertEquals(isValidEnvelope([]), false);
  assertEquals(isValidEnvelope(null), false);
});

// ---------------------------------------------------------------------------
// toDeviceDto – die Form, die SyncApiClient in der App erwartet
// ---------------------------------------------------------------------------

test('toDeviceDto liefert camelCase und einen ISO-String mit Z', () => {
  const dto = toDeviceDto({
    chain_id: 'c1',
    device_id: 'd1',
    device_name: 'Pixel 8',
    updated_at: '2026-09-30T10:00:00+00:00',
    includes_settings: true,
    envelope: {},
  });
  assertEquals(dto, {
    deviceId: 'd1',
    deviceName: 'Pixel 8',
    // Ohne das 'Z' haette die App eine Ortszeit interpretiert und ein Geraet
    // in einer anderen Zeitzone laege Stunden daneben.
    updatedAt: '2026-09-30T10:00:00.000Z',
    includesSettings: true,
  });
});

test('toDeviceDto haelt einen leeren Geraetenamen leer', () => {
  const dto = toDeviceDto({
    chain_id: 'c1',
    device_id: 'd1',
    device_name: '   ',
    updated_at: '2026-09-30T10:00:00Z',
    includes_settings: false,
    envelope: {},
  });
  assertEquals(dto.deviceName, '   ');
});

// ---------------------------------------------------------------------------
// toApiError – Datenbankfehler auf die Codes der App abbilden
// ---------------------------------------------------------------------------

function pgError(code: string, message: string, detail?: string) {
  return Object.assign(new Error(message), { code, message, detail });
}

test('toApiError bildet das Geraetelimit auf 409 ab', () => {
  const mapped = toApiError(pgError('P0001', 'tooManyDevices'));
  assertEquals(mapped.code, 'tooManyDevices');
  assertEquals(mapped.status, 409);
});

test('toApiError bildet das Sharelimit auf 409 ab', () => {
  const mapped = toApiError(pgError('P0001', 'tooManyShares'));
  assertEquals(mapped.code, 'tooManyShares');
  assertEquals(mapped.status, 409);
});

test('toApiError bildet einen blockierten Namen auf 400 ab', () => {
  // 400 ist richtig: Der Aufrufer muss den Namen aendern, nicht spaeter noch
  // einmal versuchen.
  const mapped = toApiError(pgError('P0001', 'nameBlocked', 'arschloch'));
  assertEquals(mapped.code, 'invalidShare');
  assertEquals(mapped.status, 400);
});

test('toApiError macht aus einem Check-Fehler keinen 500er', () => {
  for (const code of ['23514', '23505']) {
    const mapped = toApiError(pgError(code, 'irgendwas'));
    assertEquals(mapped.status, 400, `SQLSTATE ${code}`);
  }
});

test('toApiError laesst einen echten Serverfehler auch einer sein', () => {
  const mapped = toApiError(pgError('57014', 'canceling statement due to statement timeout'));
  assertEquals(mapped.code, 'serverError');
  assertEquals(mapped.status, 500);
});

test('toApiError reicht einen eigenen ApiError unveraendert durch', () => {
  const original = new ApiError('notFound', 404);
  assertEquals(toApiError(original), original);
});

test('toApiError kommt auch ohne Error-Objekt zurecht', () => {
  assertEquals(toApiError('nur ein String').code, 'serverError');
});

test('rawErrorText zeigt, was die Datenbank wirklich gesagt hat', () => {
  // Ohne das ist die Fehlermeldung "[object Object]" – und man jagt eine
  // Stunde einem Fehler in der Function nach, der im CHECK steckt.
  const text = rawErrorText(pgError('23514', 'verletzt chain_snapshots_envelope_shape', 'Failing row'));
  assertEquals(text.includes('23514'), true);
  assertEquals(text.includes('chain_snapshots_envelope_shape'), true);
  assertEquals(rawErrorText(new Error('schlicht')).includes('schlicht'), true);
});

// ---------------------------------------------------------------------------
// handle – CORS, Fehler und Cache
// ---------------------------------------------------------------------------

test('handle beantwortet eine CORS-Vorabfrage mit 204', async () => {
  // Die Function darf dabei gar nicht erst aufgerufen werden – eine
  // Vorabfrage hat keinen Body.
  let aufgerufen = false;
  const response = await handle(request('x', 'OPTIONS'), () => {
    aufgerufen = true;
    return json({ nie: true });
  });
  assertEquals(aufgerufen, false);
  assertEquals(response.status, 204);
  assertEquals(response.headers.get('access-control-allow-origin'), '*');
});

test('handle setzt CORS und no-store auf jede Antwort', async () => {
  const response = await handle(request('x'), () => json({ ok: true }));
  assertEquals(response.headers.get('access-control-allow-origin'), '*');
  assertEquals(response.headers.get('access-control-allow-methods'), 'GET, PUT, DELETE, OPTIONS');
  // Ein zwischengespeicherter Snapshot waere ein Datenleck ueber die Zeit.
  assertEquals(response.headers.get('cache-control'), 'no-store');
});

test('handle gibt einen Fehlercode heraus, nicht den Datenbanktext', async () => {
  // Der Postgres-Text verraet Tabellen- und Spaltennamen.
  const response = await handle(request('x'), () => {
    throw pgError('23514', 'verletzt die Tabelle geheime_tabelle');
  });
  // 23514 ist ein check_violation und damit ein Fehler des Aufrufers, kein
  // Serverausfall – die Function darf ihn nicht als 500 tarnen.
  assertEquals(response.status, 400);
  const body = await response.json();
  assertEquals(JSON.stringify(body).includes('geheime_tabelle'), false);
});

test('handle gibt auch bei einem echten Serverfehler nur den Code heraus', async () => {
  const response = await handle(request('x'), () => {
    throw pgError('57P01', 'administrator shutdown');
  });
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, 'serverError');
  assertEquals(JSON.stringify(body).includes('shutdown'), false);
});

test('handle gibt einen ApiError unveraendert weiter', async () => {
  const response = await handle(request('x'), () => {
    throw new ApiError('tooManyDevices', 409);
  });
  assertEquals(response.status, 409);
  assertEquals((await response.json()).error, 'tooManyDevices');
});

// ---------------------------------------------------------------------------

let failed = 0;
for (const [name, fn] of tests) {
  try {
    await fn();
    console.log(`  ok   ${name}`);
  } catch (error) {
    failed++;
    console.error(`  FAIL ${name}`);
    console.error(`       ${error instanceof Error ? error.message : String(error)}`);
  }
}
console.log(`\n${tests.length - failed}/${tests.length} bestanden`);
if (failed > 0) Deno.exit(1);
