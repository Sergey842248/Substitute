/**
 * Der Status-Endpunkt.
 *
 *   GET  ->  { "status": "running" }
 *
 * Diesen einen Endpunkt fragt die Statusseite auf GitHub Pages ab
 * (`docs/index.html`), um "Server is running" oder "Server is stopped" zu
 * zeigen. Er ist deshalb der einzige, der nicht gedrosselt ist – er soll
 * immer antworten, auch wenn gerade viele synchrone.
 *
 * Er sagt bewusst *nichts* ueber den Zustand der Datenbank. Einen
 * Datenbankfehler wuerde man an einem Ort sehen wollen, den niemand
 * pollen muss; der Server kann den Inhalt ohnehin nicht lesen, und ein
 * Ausfall der Datenbank faellt den Nutzern sofort auf, weil der Sync
 * fehlschlaegt. Was diese Seite anzeigt, ist nur: antwortet der Dienst
 * ueberhaupt.
 */

import { handle, json, serve } from '../_shared/http.ts';

serve(async (req): Promise<Response> => {
    return json({ status: 'running', version: 1 });
});
