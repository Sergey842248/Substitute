/**
 * Testet die Edge Functions gegen eine echte Postgres-Instanz.
 *
 *   supabase start                       # oder ein eigenes Postgres
 *   psql "$SUPABASE_DB_URL" -f docs/server-supabase/schema.sql
 *   deno test --allow-net --allow-env supabase/functions/
 *
 * Ohne `--allow-env` kommen SUPABASE_URL und SUPABASE_SERVICE_ROLE_KEY nicht
 * an; ohne `--allow-net` kann die Function die Datenbank nicht erreichen.
 *
 * Der Test spricht die Functions über HTTP an, nicht über interne Aufrufe. So
 * wird der ganze Weg geprüft: CORS, Routing, JSON, Fehlercodes, Datenbank.
 */

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';

/**
 * Basis je Function.
 *
 * Auf Supabase liegen alle unter einer Adresse
 * (`https://<projekt>.supabase.co/functions/v1/<name>`), weil die Plattform
 * sie selbst verteilt. Lokal laeuft jede in einem eigenen Prozess auf einem
 * eigenen Port, weil jede fuer sich `Deno.serve` aufruft – sonst wuerde die
 * zweite Function am Port der ersten scheitern.
 */
const PORTS: Record<string, number> = {
  health: Number(Deno.env.get('PORT_HEALTH') ?? 54501),
  'chain-snapshots': Number(Deno.env.get('PORT_CHAIN') ?? 54502),
  shares: Number(Deno.env.get('PORT_SHARES') ?? 54503),
  directory: Number(Deno.env.get('PORT_DIRECTORY') ?? 54504),
};

const HOST = Deno.env.get('FUNCTIONS_HOST') ?? 'http://127.0.0.1';
const ANON = Deno.env.get('ANON_KEY') ?? 'test-anon-key';

function url(name: string, query: Record<string, string> = {}): string {
  const params = new URLSearchParams(query).toString();
  return `${HOST}:${PORTS[name]}${params ? `?${params}` : ''}`;
}

function headers(extra: Record<string, string> = {}): Record<string, string> {
  return {
    'apikey': ANON,
    'authorization': `Bearer ${ANON}`,
    'content-type': 'application/json',
    // Für die Drosselung: eigene Test-IP, damit sie nicht mit anderen
    // Anfragen in denselben Zähler läuft.
    'x-forwarded-for': '203.0.113.99',
    ...extra,
  };
}

async function call(
  method: string,
  target: string,
  body?: unknown,
): Promise<{ status: number; body: any }> {
  const response = await fetch(target, {
    method,
    headers: headers(),
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return {
    status: response.status,
    body: text ? JSON.parse(text) : null,
  };
}

const ENVELOPE = {
  v: 1,
  iv: 'aXY=',
  ct: 'Y2lwaGVy',
  mac: 'bWFj',
  kdf: { alg: 'pbkdf2-sha256', iter: 120000, salt: 'substitute/share/v1' },
};

// Wie der Client schickt die App: Die Rumpf-Felder heissen snake_case, weil
// sie 1:1 in die Spalten der Datenbank gehen. Die *Antwort* dagegen ist
// camelCase – das ist das Domänenmodell der App. Diese Asymmetrie ist
// Absicht; sie hier beide Formen nebeneinander zu haben macht den Fehler
// sichtbar, der beim Wechsel der einen Form auf die andere entstanden ist.
const OWNER = {
  username: 'blue sky river seven apple candle',
  school_number: '12345',
  display_name: 'Frau Müller',
};

// Den Server einmal gegenprüfen, bevor die eigentlichen Tests laufen.
const health = await call('GET', url('health'));
if (health.status !== 200) {
  console.error('Server nicht erreichbar:', health);
  Deno.exit(1);
}

const tests: Array<[string, () => Promise<void>]> = [];

function test(name: string, fn: () => Promise<void>) {
  tests.push([name, fn]);
}

// ---------------------------------------------------------------------------
// health
// ---------------------------------------------------------------------------

test('health meldet genau das, was die Statusseite anzeigt', async () => {
  const response = await call('GET', url('health'));
  assertEquals(response.status, 200);
  assertEquals(response.body.status, 'running');
});

test('health antwortet auf eine CORS-Vorabfrage', async () => {
  const response = await fetch(url('health'), { method: 'OPTIONS' });
  assertEquals(response.status, 204);
  assertEquals(response.headers.get('access-control-allow-origin'), '*');
});

test('health ist nicht cachebar', async () => {
  const response = await fetch(url('health'), { headers: headers() });
  assertEquals(response.headers.get('cache-control'), 'no-store');
});

// ---------------------------------------------------------------------------
// chain-snapshots
// ---------------------------------------------------------------------------

test('ein Snapshot lässt sich hochladen und wieder laden', async () => {
  const put = await call('PUT', url('chain-snapshots'), {
    chain_id: 'chain-test-1',
    device_id: 'device-a',
    device_name: 'Pixel 8',
    updated_at: new Date().toISOString(),
    includes_settings: true,
    envelope: ENVELOPE,
  });
  assertEquals(put.status, 200);

  const get = await call('GET', url('chain-snapshots', { chain_id: 'chain-test-1' }));
  assertEquals(get.status, 200);
  assertEquals(get.body.snapshots.length, 1);
  assertEquals(get.body.snapshots[0].deviceId, 'device-a');
  assertEquals(get.body.snapshots[0].deviceName, 'Pixel 8');
  assertEquals(get.body.snapshots[0].includesSettings, true);
  assertEquals(get.body.snapshots[0].envelope.ct, 'Y2lwaGVy');
});

test('ein Gerät hat genau einen Snapshot je Kette', async () => {
  // Der zweite PUT darf nicht verdoppeln.
  for (let i = 0; i < 3; i++) {
    await call('PUT', url('chain-snapshots'), {
      chain_id: 'chain-test-1',
      device_id: 'device-a',
      device_name: `Name ${i}`,
      updated_at: new Date().toISOString(),
      includes_settings: false,
      envelope: ENVELOPE,
    });
  }
  const get = await call('GET', url('chain-snapshots', { chain_id: 'chain-test-1' }));
  assertEquals(get.body.snapshots.length, 1);
  assertEquals(get.body.snapshots[0].deviceName, 'Name 2');
});

test('die Geräteliste kommt ohne Hüllen aus', async () => {
  const get = await call(
    'GET',
    url('chain-snapshots', { chain_id: 'chain-test-1', devices: '1' }),
  );
  assertEquals(get.status, 200);
  assertEquals(get.body.devices.length, 1);
  assert(!('envelope' in get.body.devices[0]), 'Geraeteliste darf keine Huelle tragen');
});

test('Snapshots kommen in aufsteigender Zeitfolge', async () => {
  const chain = 'chain-order';
  const order: Array<[string, number]> = [['spaet', 0], ['frueh', -60], ['mitte', -30]];
  for (const [device, offset] of order) {
    await call('PUT', url('chain-snapshots'), {
      chain_id: chain,
      device_id: device,
      updated_at: new Date(Date.now() + offset * 1000).toISOString(),
      envelope: ENVELOPE,
    });
  }
  const get = await call('GET', url('chain-snapshots', { chain_id: chain }));
  const names = get.body.snapshots.map((s: any) => s.deviceName);
  assertEquals(names, ['frueh', 'mitte', 'spaet']);
});

test('updatedAt kommt als ISO-String mit Zeitzone', async () => {
  const get = await call('GET', url('chain-snapshots', { chain_id: 'chain-test-1' }));
  const updated = get.body.snapshots[0].updatedAt;
  assert(typeof updated === 'string', 'updatedAt muss ein String sein');
  assert(updated.endsWith('Z'), `erwartet Z-Suffix, bekam ${updated}`);
  assert(!Number.isNaN(Date.parse(updated)));
});

test('ein Gerät kann die Kette verlassen, ohne dass Daten mitgehen', async () => {
  const chain = 'chain-leave';
  await call('PUT', url('chain-snapshots'), {
    chain_id: chain,
    device_id: 'device-weg',
    updated_at: new Date().toISOString(),
    envelope: ENVELOPE,
  });
  await call('PUT', url('chain-snapshots'), {
    chain_id: chain,
    device_id: 'device-da',
    updated_at: new Date().toISOString(),
    envelope: ENVELOPE,
  });

  const del = await call(
    'DELETE',
    url('chain-snapshots', { chain_id: chain, device_id: 'device-weg' }),
  );
  assertEquals(del.status, 200);
  assertEquals(del.body.removed, true);

  const get = await call('GET', url('chain-snapshots', { chain_id: chain }));
  assertEquals(get.body.snapshots.length, 1);
  assertEquals(get.body.snapshots[0].deviceId, 'device-da');
});

test('ein unbekanntes Gerät meldet 404', async () => {
  const del = await call(
    'DELETE',
    url('chain-snapshots', { chain_id: 'chain-leave', device_id: 'gibt-es-nicht' }),
  );
  assertEquals(del.status, 404);
});

test('eine leere Kette ist kein Fehler', async () => {
  const get = await call('GET', url('chain-snapshots', { chain_id: 'gibt-es-nicht' }));
  assertEquals(get.status, 200);
  assertEquals(get.body.snapshots.length, 0);
});

test('Pfadverschleifung in der Ketten-ID wird abgelehnt', async () => {
  const put = await call('PUT', url('chain-snapshots'), {
    chain_id: '../../etc/passwd',
    device_id: 'device-a',
    updated_at: new Date().toISOString(),
    envelope: ENVELOPE,
  });
  assertEquals(put.status, 400);
  assertEquals(put.body.error, 'invalidSnapshot');
});

test('eine fehlende Hülle wird abgelehnt', async () => {
  const put = await call('PUT', url('chain-snapshots'), {
    chain_id: 'chain-test-1',
    device_id: 'device-b',
    updated_at: new Date().toISOString(),
  });
  assertEquals(put.status, 400);
});

test('ein Zeitstempel aus der fernen Zukunft wird abgelehnt', async () => {
  // Sonst könnte ein Gerät mit verstelltem Systemdatum seinen Stand zum
  // "neuesten" erklären und alle anderen Einträge überschreiben.
  const put = await call('PUT', url('chain-snapshots'), {
    chain_id: 'chain-test-1',
    device_id: 'device-c',
    updated_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    envelope: ENVELOPE,
  });
  assertEquals(put.status, 400);
  assertEquals(put.body.error, 'invalidSnapshot');
});

test('die Gerätegrenzze greift', async () => {
  const chain = 'chain-limit';
  for (let i = 1; i <= 12; i++) {
    const put = await call('PUT', url('chain-snapshots'), {
      chain_id: chain,
      device_id: `device-${i}`,
      updated_at: new Date().toISOString(),
      envelope: ENVELOPE,
    });
    assertEquals(put.status, 200, `Geraet ${i} muss noch gehen`);
  }
  const tooMany = await call('PUT', url('chain-snapshots'), {
    chain_id: chain,
    device_id: 'device-13',
    updated_at: new Date().toISOString(),
    envelope: ENVELOPE,
  });
  assertEquals(tooMany.status, 409);
  assertEquals(tooMany.body.error, 'tooManyDevices');
});

// ---------------------------------------------------------------------------
// shares
// ---------------------------------------------------------------------------

test('ein Share lässt sich anlegen und öffnen', async () => {
  const put = await call('PUT', url('shares'), {
    id: 'share-offen',
    owner: OWNER,
    label: 'Vertretungspläne',
    searchable: true,
    is_global: false,
    updated_at: '2026-09-30T12:00:00.000Z',
    envelopes: { byUsername: ENVELOPE, bySchool: ENVELOPE },
  });
  assertEquals(put.status, 200);

  const get = await call('GET', url('shares', { id: 'share-offen' }));
  assertEquals(get.status, 200);
  assertEquals(get.body.id, 'share-offen');
  assertEquals(get.body.hasPassword, false);
  assertEquals(get.body.unlockableWithSchoolCredentials, true);
  assertEquals(get.body.envelopes.byUsername.ct, 'Y2lwaGVy');
  // Anfrage snake_case, Antwort camelCase. Genau diese Umbenennung ist
  // einmal stillschweigend schiefgegangen: Der Client schickte `isGlobal`,
  // die Function las `is_global` und meldete `invalidShare` – mit 400 und
  // ohne Hinweis darauf, dass es an einem einzigen Namenszusatz lag.
  assertEquals(get.body.isGlobal, false);
  assertEquals(get.body.updatedAt.endsWith('Z'), true);
  assertEquals(get.body.owner.schoolNumber, '12345');
  assertEquals(get.body.owner.displayName, 'Frau Müller');
  // Der Zeitstempel kommt vom Geraet. Uebbernimmt der Server seine eigene
  // Zeit, entscheidet bei einem passwortgeschuetzten Share spaeter eine
  // Falschzeit darueber, wer zuletzt daran war.
  assertEquals(get.body.updatedAt, '2026-09-30T12:00:00.000Z');
});

test('ein passwortgeschützter Share hat nur die Passwort-Hülle', async () => {
  await call('PUT', url('shares'), {
    id: 'share-gesichert',
    owner: { ...OWNER, username: 'red moon water nine tiger mango' },
    label: 'Krankentracking',
    searchable: true,
    is_global: false,
    updated_at: new Date().toISOString(),
    envelopes: { byPassword: ENVELOPE },
  });

  const get = await call('GET', url('shares', { id: 'share-gesichert' }));
  assertEquals(get.body.hasPassword, true);
  assertEquals(get.body.unlockableWithSchoolCredentials, false);
  // Genau daran erkennt die App, dass der Nutzername allein nichts mehr bringt.
  assert(!('byUsername' in get.body.envelopes));
  assert(!('bySchool' in get.body.envelopes));
});

test('ein anstößiger Anzeigename wird abgelehnt', async () => {
  const put = await call('PUT', url('shares'), {
    id: 'share-beleidigend',
    owner: { ...OWNER, display_name: 'Arschloch' },
    searchable: true,
    is_global: false,
    updated_at: new Date().toISOString(),
    envelopes: { byUsername: ENVELOPE },
  });
  assertEquals(put.status, 400);
  assertEquals(put.body.error, 'invalidShare');

  // Und: nichts davon darf gelandet sein.
  const get = await call('GET', url('shares', { id: 'share-beleidigend' }));
  assertEquals(get.status, 404);
});

test('ein Share ohne Hülle wird abgelehnt', async () => {
  const put = await call('PUT', url('shares'), {
    id: 'share-ohne',
    owner: OWNER,
    searchable: true,
    is_global: false,
    updated_at: new Date().toISOString(),
    envelopes: {},
  });
  assertEquals(put.status, 400);
});

test('eine unbekannte Hülle wird abgelehnt', async () => {
  const put = await call('PUT', url('shares'), {
    id: 'share-fremde-huelle',
    owner: OWNER,
    searchable: true,
    is_global: false,
    updated_at: new Date().toISOString(),
    envelopes: { byAdmin: ENVELOPE },
  });
  assertEquals(put.status, 400);
});

test('ein unbekannter Share meldet 404 mit eigenem Code', async () => {
  const get = await call('GET', url('shares', { id: 'gibt-es-nicht' }));
  assertEquals(get.status, 404);
  assertEquals(get.body.error, 'shareNotFound');
});

test('ein Share lässt sich löschen', async () => {
  const del = await call('DELETE', url('shares', { id: 'share-gesichert' }));
  assertEquals(del.status, 200);
  assertEquals((await call('GET', url('shares', { id: 'share-gesichert' }))).status, 404);
});

// ---------------------------------------------------------------------------
// directory
// ---------------------------------------------------------------------------

test('das Verzeichnis zeigt nur die eigene Schulnummer', async () => {
  await call('PUT', url('shares'), {
    id: 'share-schule-99999',
    owner: { ...OWNER, school_number: '99999' },
    label: 'Fremde Schule',
    searchable: true,
    is_global: true,
    updated_at: new Date().toISOString(),
    envelopes: { byUsername: ENVELOPE },
  });

  const eigen = await call('GET', url('directory', { school_number: '12345' }));
  const fremd = await call('GET', url('directory', { school_number: '99999' }));

  const ownNames = JSON.stringify(eigen.body);
  assert(!ownNames.includes('Fremde Schule'), 'fremde Schule darf nicht erscheinen');
  assertEquals(fremd.body.people.length, 1);
  assertEquals(fremd.body.people[0].displayName, 'Frau Müller');
});

test('ein globaler Share erscheint nicht im Verzeichnis', async () => {
  // Global heißt: von jeder Schule per Nutzername nutzbar. Nicht: überall
  // gelistet. Deshalb kein Filter auf is_global, sondern nur auf school_number.
  await call('PUT', url('shares'), {
    id: 'share-global',
    owner: { ...OWNER, username: 'amber field wood two blue crane' },
    label: 'Offen für alle',
    searchable: true,
    is_global: true,
    updated_at: new Date().toISOString(),
    envelopes: { byUsername: ENVELOPE },
  });

  const fremd = await call('GET', url('directory', { school_number: '88888' }));
  assertEquals(fremd.body.people.length, 0);
});

test('ein nicht suchbarer Share erscheint nirgends', async () => {
  await call('PUT', url('shares'), {
    id: 'share-versteckt',
    owner: { ...OWNER, username: 'green hill snow ten lion mango' },
    label: 'Nur direkt',
    searchable: false,
    is_global: false,
    updated_at: new Date().toISOString(),
    envelopes: { byUsername: ENVELOPE },
  });

  const dir = await call('GET', url('directory', { school_number: '12345' }));
  const raw = JSON.stringify(dir.body);
  assert(!raw.includes('Frau Heimlich'), 'nicht suchbare Shares duerfen nicht erscheinen');
});

test('das Verzeichnis enthält keine verschlüsselten Hüllen', async () => {
  const dir = await call('GET', url('directory', { school_number: '12345' }));
  const raw = JSON.stringify(dir.body);
  assert(!raw.includes('byUsername'), 'Huelle darf nicht im Verzeichnis stehen');
  assert(!raw.includes('"ct"'), 'Chiffrat darf nicht im Verzeichnis stehen');
});

test('das Verzeichnis gruppiert nach Person, nicht nach Share', async () => {
  await call('PUT', url('shares'), {
    id: 'share-noch-eins',
    owner: OWNER,
    label: 'Zweites Share',
    searchable: true,
    is_global: false,
    updated_at: new Date().toISOString(),
    envelopes: { byUsername: ENVELOPE },
  });

  const dir = await call('GET', url('directory', { school_number: '12345' }));
  const person = dir.body.people.find((p: any) => p.username === OWNER.username);
  assert(person, 'Person muss im Verzeichnis stehen');
  assertEquals(person.shares.length, 2, 'zwei Shares unter einer Person');
});

test('eine unbrauchbare Schulnummer wird abgelehnt', async () => {
  const dir = await call('GET', url('directory', { school_number: '../x' }));
  assertEquals(dir.status, 400);
});

// ---------------------------------------------------------------------------
// Allgemein
// ---------------------------------------------------------------------------

test('unbekannte Methoden werden abgelehnt', async () => {
  const response = await call('POST', url('chain-snapshots'), {});
  assertEquals(response.status, 405);
});

test('kaputter JSON gibt invalidJson, keinen 500er', async () => {
  const response = await fetch(url('shares'), {
    method: 'PUT',
    headers: headers(),
    body: '{kein json',
  });
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, 'invalidJson');
});

test('jede Antwort trägt die CORS-Kopfzeilen', async () => {
  const response = await fetch(url('health'), { headers: headers() });
  assertEquals(response.headers.get('access-control-allow-origin'), '*');
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
