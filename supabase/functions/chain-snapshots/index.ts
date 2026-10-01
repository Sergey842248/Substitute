/**
 * Sync-Ketten: Snapshots je Gerät.
 *
 *   GET    ?chain_id=X              alle Snapshots (fuer den Merge)
 *   GET    ?chain_id=X&devices=1    nur die Geraeteliste, ohne Huellen
 *   PUT                            eigenen Snapshot anlegen/ersetzen
 *   DELETE ?chain_id=X&device_id=Y  ein Geraet aus der Kette nehmen
 *   DELETE ?chain_id=X              die ganze Kette loeschen
 *
 * Die Ketten-ID ist das base64url eines SHA-256 ueber die Passphrase. Sie ist
 * damit selbst das Geheimnis: Wer sie kennt, darf lesen und schreiben. Ein
 * JWT gibt es nicht, und es wird auch keins verlangt – die App hat keine
 * Konten, und ein Token muesste sicher verteilt werden, was bei einem
 * zehnwoertigen Code, den man in einem Raum weitersagt, genau das Gegenteil
 * waere.
 */

import {
  ApiError,
  MAX_DEVICE_NAME_LENGTH,
  clampText,
  clientAddress,
  handle,
  isValidId,
  json,
  idParam,
  queryParam,
  readJson,
  serve,
} from '../_shared/http.ts';
import {
  db,
  isValidEnvelope,
  throttle,
  toDeviceDto,
  type SnapshotRow,
} from '../_shared/db.ts';

/** Wie viele schreibende Zugriffe je IP und Minute. */
const WRITE_LIMIT = 30;

serve(async (req): Promise<Response> => {
    const client = db();

    switch (req.method) {
      case 'GET':
        return await getSnapshots(req, client);
      case 'PUT':
        return await putSnapshot(req, client);
      case 'DELETE':
        return await deleteSnapshot(req, client);
      default:
        throw new ApiError('forbidden', 405, `Methode ${req.method}`);
    }
});

// ---------------------------------------------------------------------------

async function getSnapshots(req: Request, client: ReturnType<typeof db>): Promise<Response> {
  const chainId = idParam(req, 'chain_id');
  if (!isValidId(chainId)) {
    throw new ApiError('invalidSnapshot', 400, 'chain_id');
  }

  // Geraeteliste ohne Huellen: 12 Geraete a mehreren hundert KB sind sonst
  // ein paar MB nur fuer eine Anzeige, die drei Zeilen Text zeigt.
  if (queryParam(req, 'devices') === '1') {
    const { data, error } = await client
      .from('chain_snapshots')
      .select('chain_id, device_id, device_name, updated_at, includes_settings')
      .eq('chain_id', chainId)
      .order('updated_at', { ascending: false });

    if (error) throw error;
    const rows = (data ?? []) as SnapshotRow[];
    return json({
      chainId,
      devices: rows.map(toDeviceDto),
    });
  }

  const { data, error } = await client
    .from('chain_snapshots')
    .select('chain_id, device_id, device_name, updated_at, includes_settings, envelope')
    .eq('chain_id', chainId)
    .order('updated_at', { ascending: true });

  if (error) throw error;
  const rows = (data ?? []) as SnapshotRow[];

  return json({
    chainId,
    // Der Merge in der App erwartet die aeltesten zuerst: Er fuehrt die
    // Snapshots nacheinander zusammen, und fuer ein deterministisches
    // Ergebnis ist eine feste Reihenfolge noetig.
    snapshots: rows.map((row) => ({ ...toDeviceDto(row), envelope: row.envelope })),
    serverTime: new Date().toISOString(),
  });
}

// ---------------------------------------------------------------------------

async function putSnapshot(req: Request, client: ReturnType<typeof db>): Promise<Response> {
  await throttle(client, clientAddress(req), 'chain-put', WRITE_LIMIT, 60);

  const body = await readJson(req);

  const chainId = body.chain_id;
  const deviceId = body.device_id;
  if (!isValidId(chainId) || !isValidId(deviceId)) {
    throw new ApiError('invalidSnapshot', 400, 'chain_id/device_id');
  }
  if (!isValidEnvelope(body.envelope)) {
    throw new ApiError('invalidSnapshot', 400, 'envelope');
  }

  const deviceName = clampText(body.device_name, MAX_DEVICE_NAME_LENGTH);

  // `updated_at` kommt vom Geraet, nicht vom Server. Ein Geraet mit falscher
  // Uhr wuerde sonst die Reihenfolge des Merges bestimmen – deshalb wird es
  // uebernommen, aber plausibilitaetsgeprueft: nichts in der nahen Zukunft,
  // nichts weit in der Vergangenheit. Sonst koennte ein Geraet mit einem
  // verstellten Systemdatum seinen Stand zum "neuesten" erklaeren und damit
  // alle anderen Eintraege ueberschreiben.
  const updatedAt = new Date(String(body.updated_at ?? Date.now()));
  if (Number.isNaN(updatedAt.getTime())) {
    throw new ApiError('invalidSnapshot', 400, 'updated_at');
  }
  const now = Date.now();
  const drift = updatedAt.getTime() - now;
  if (drift > 5 * 60 * 1000 || drift < -365 * 24 * 60 * 60 * 1000) {
    throw new ApiError('invalidSnapshot', 400, 'updated_at unplausibel');
  }

  // Das ist der Punkt, an dem der primaere Schluessel das Verhalten erzwingt,
  // das `putChainSnapshot` im Dart-Server per `removeWhere` + `add` erzwang:
  // ein Geraet hat genau einen Snapshot je Kette.
  const { data, error } = await client
    .from('chain_snapshots')
    .upsert(
      {
        chain_id: chainId,
        device_id: deviceId,
        device_name: deviceName,
        updated_at: updatedAt.toISOString(),
        includes_settings: body.includes_settings === true,
        envelope: body.envelope,
      },
      { onConflict: 'chain_id,device_id' },
    )
    .select('chain_id, device_id');

  if (error) throw error;

  return json({
    chainId,
    deviceId: (data?.[0] as { device_id?: string } | undefined)?.device_id ?? deviceId,
    storedAt: new Date().toISOString(),
  });
}

// ---------------------------------------------------------------------------

async function deleteSnapshot(req: Request, client: ReturnType<typeof db>): Promise<Response> {
  await throttle(client, clientAddress(req), 'chain-delete', WRITE_LIMIT, 60);

  const chainId = idParam(req, 'chain_id');
  if (!isValidId(chainId)) {
    throw new ApiError('invalidSnapshot', 400, 'chain_id');
  }

  const deviceId = idParam(req, 'device_id');

  // Ohne device_id wird die ganze Kette geloescht. Die Daten bleiben
  // natuerlich auf den Geraeten – das ist der Punkt von "Kette verlassen".
  //
  // Ein Filter wird in Supabase nicht nachtraeglich angehaengt, sondern muss
  // direkt beim `delete()` mitgegeben werden; deshalb gibt es hier keinen
  // gemeinsamen Query-Bau wie bei einem SELECT.
  if (deviceId === null) {
    const { data, error } = await client
      .from('chain_snapshots')
      .delete()
      .eq('chain_id', chainId)
      .select('device_id');
    if (error) throw error;
    const removed = (data ?? []).length > 0;
    return json({ removed }, removed ? 200 : 404);
  }

  if (!isValidId(deviceId)) {
    throw new ApiError('invalidSnapshot', 400, 'device_id');
  }

  const { data, error } = await client
    .from('chain_snapshots')
    .delete()
    .eq('chain_id', chainId)
    .eq('device_id', deviceId)
    .select('device_id');

  if (error) throw error;
  const removed = (data ?? []).length > 0;
  return json({ removed }, removed ? 200 : 404);
}
