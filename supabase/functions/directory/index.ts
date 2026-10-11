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
 * Es gibt bewusst **keinen** "globalen" Share mehr. Jeder Share haengt am
 * Nutzernamen und ist damit von jeder Schule aus oeffnenbar, sobald man ihn
 * kennt. Die Schulnummer hat damit genau **eine** Aufgabe: Sie haelt fremde
 * Schulen aus diesem Verzeichnis heraus. Alles andere waere doppelt – und ein
 * zweiter Schalter, den man falsch verstehen koennte.
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
        'id, owner_username, school_number, display_name, label, searchable, updated_at, has_password',
      )
      // **Die Schulnummer ist die einzige Grenze des Verzeichnisses.** Es gibt
      // keinen globalen Share mehr: Wer einen Share einer fremden Schule
      // oeffnen will, braucht den Nutzernamen – dann geht es, denn die
      // Verschluesselung haengt nicht an der Schule. Das Verzeichnis hier
      // filtert deshalb ausschliesslich nach der Schulnummer der suchenden
      // Person und listet danach nur deren eigene Schule auf.
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
        hasPassword: row.has_password,
        updatedAt: new Date(row.updated_at).toISOString(),
      });
    }

    return json({
      schoolNumber,
      people: [...people.values()],
    });
});
