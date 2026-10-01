/**
 * Das Suchverzeichnis einer Schulnummer.
 *
 *   GET ?school_number=X
 *
 * Zwei Regeln, die beide im Namen der Anforderung stehen und beide hier
 * erzwungen werden:
 *
 * 1. **Nur die eigene Schulnummer.** Fremde Schulen bekommen nichts. Das ist
 *    kein Filter im Code, sondern der einzige Wert, der ueberhaupt abgefragt
 *    wird – die Funktion kann gar nicht anders, als nach der uebergebenen
 *    Schulnummer zu suchen.
 *
 * 2. **Nur ausdruecklich als suchbar markierte Shares.** Ein Share, dessen
 *    Ersteller das nicht getan hat, erscheint hier nie. Das ist der Partial
 *    Index `shares_directory` in schema.sql, nicht ein WHERE hier.
 *
 * `is_global` wird bewusst *nicht* gefiltert. Global heisst: jeder kann ihn
 * per Nutzername oeffnen, auch von einer anderen Schule aus. Es heisst nicht:
 * er wird in fremden Verzeichnissen gelistet. Wer das verwechselt, publishert
 * versehentlich die Pläne der ganzen Schule an jeden.
 *
 * Die verschluesselten Huellen sind in der Antwort nicht enthalten. Wer das
 * Verzeichnis sieht, sieht Namen und Anzahl – sonst nichts.
 */

import {
  MAX_DIRECTORY_ENTRIES,
  handle,
  isValidSchoolNumber,
  json,
  queryParam,
  serve,
} from '../_shared/http.ts';
import { db, type ShareRow } from '../_shared/db.ts';

serve(async (req): Promise<Response> => {
    if (req.method !== 'GET') {
      return json({ error: 'forbidden' }, 405);
    }

    const raw = queryParam(req, 'school_number');
    if (!isValidSchoolNumber(raw)) {
      return json({ error: 'invalidShare' }, 400);
    }
    // Ab hier ist es ein String: die Pruefung oben schliesst null aus, aber
    // TypeScript folgt der Verengung ueber eine eigene Variable nicht.
    const schoolNumber: string = raw.trim();

    const client = db();

    const { data, error } = await client
      .from('shares')
      .select(
        'id, owner_username, school_number, display_name, label, searchable, is_global, updated_at, has_password',
      )
      .eq('school_number', schoolNumber)
      .eq('searchable', true)
      // Ohne diese Grenze koennte ein einzelner Aufruf das ganze Verzeichnis
      // in die Antwort ziehen. Bei einer Schule sind es wenige Zeilen, aber
      // die Grenze ist billig und der Aufrufer ist nicht vertrauenswuerdig.
      .limit(MAX_DIRECTORY_ENTRIES)
      .order('updated_at', { ascending: false });

    if (error) throw error;

    const rows = (data ?? []) as ShareRow[];

    // Nach Person gruppieren, so wie die Suchliste in der App es anzeigt:
    // erst die Person, dann ihre Shares. Ohne Gruppierung stuende eine Person
    // so oft im Verzeichnis, wie sie etwas geteilt hat.
    const people = new Map<string, {
      username: string;
      displayName: string;
      shares: Array<{
        id: string;
        label: string;
        isGlobal: boolean;
        hasPassword: boolean;
        updatedAt: string;
      }>;
    }>();

    for (const row of rows) {
      let person = people.get(row.owner_username);
      if (!person) {
        person = {
          username: row.owner_username,
          displayName: row.display_name,
          shares: [],
        };
        people.set(row.owner_username, person);
      }
      person.shares.push({
        id: row.id,
        label: row.label,
        isGlobal: row.is_global,
        hasPassword: row.has_password,
        updatedAt: new Date(row.updated_at).toISOString(),
      });
    }

    return json({
      schoolNumber,
      people: [...people.values()],
    });
});
