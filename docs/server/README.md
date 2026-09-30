# Der Substitute Sync- und Share-Server

Ein kleiner, abhängigkeitsfreier Dart-Server, der ausschließlich **bereits vom
Gerät verschlüsselte** Daten entgegennimmt. Er sieht keine Pläne, keine
Personen, keine Einstellungen – nicht einmal der Betreiber des Servers kann
die Inhalte lesen.

* **Port:** 8384 (nur an `127.0.0.1` gebunden, nginx reicht ihn weiter)
* **Datenverzeichnis:** `/var/lib/substitute-sync`
* **Datenablage:** eine JSON-Datei je Kette und je Share, mit atomarem
  Schreiben

## Schnellstart

```sh
# Dart holen (Ubuntu 24.04 bringt es mit, sonst:)
sudo apt-get install -y dart

# Bauen und starten
cd docs/server
dart pub get
dart test                      # 39 Tests
dart run bin/server.dart --port 8384 --data /var/lib/substitute-sync
```

Danach `curl http://127.0.0.1:8384/v1/health` → `{"status":"running"}`.

## Produktiv aufsetzen

`deploy/install.sh` macht alles in einem Durchgang:

```sh
sudo ./deploy/install.sh
```

Das Script legt an:

* den Nutzer `substitute-sync` (ohne Login-Shell),
* `/var/lib/substitute-sync` (Eigentum des Nutzers, nicht der Gruppe),
* `/etc/substitute-sync/server.env` (Port, Datenverzeichnis, optional ein
  Token) mit `chmod 600`,
* die systemd-Unit `substitute-sync.service`,
* das nginx-Site-Fragment für `substitute-sync.open-nexor.org`.

Danach ein Zertifikat holen und nginx neu laden:

```sh
sudo certbot --nginx -d substitute-sync.open-nexor.org
sudo systemctl restart nginx
```

### systemd

```sh
sudo systemctl status substitute-sync
sudo journalctl -u substitute-sync -f
```

`deploy/substitute-sync.service` ist bewusst hart auf Sicherheit getrimmt:
`ProtectSystem=strict`, `PrivateTmp`, `NoNewPrivileges`,
`ReadWritePaths` nur für das Datenverzeichnis. Ein compromised Server soll
nicht das ganze System mitnehmen können.

## Schnittstelle

Alles unter `/v1`. Antworten sind JSON. Der Server ist blind – er sieht
ausschließlich die Hüllen.

### Status

| Methode | Pfad | Zweck |
|---|---|---|
| `GET` | `/v1/health` | `{"status":"running"}` – auch die Grundlage der Statusseite auf GitHub Pages |

### Sync-Ketten

| Methode | Pfad | Zweck |
|---|---|---|
| `GET` | `/v1/chain/{id}` | alle Snapshots der Kette |
| `PUT` | `/v1/chain/{id}` | den eigenen Snapshot anlegen/ersetzen |
| `GET` | `/v1/chain/{id}/devices` | Geräteliste (ohne Hüllen) |
| `DELETE` | `/v1/chain/{id}/devices/{deviceId}` | ein Gerät aus der Kette nehmen |
| `DELETE` | `/v1/chain/{id}` | die ganze Kette löschen |

Pro Gerät existiert immer genau ein Snapshot. Höchstens
`Limits.maxDevicesPerChain` (12) Geräte je Kette.

### Shares

| Methode | Pfad | Zweck |
|---|---|---|
| `GET` | `/v1/share/{id}` | ein Share samt Hüllen |
| `PUT` | `/v1/share/{id}` | anlegen/aktualisieren |
| `DELETE` | `/v1/share/{id}` | löschen |
| `GET` | `/v1/directory/{schulnummer}` | das Suchverzeichnis einer Schule |

## Was der Server prüft – und was nicht

Der Server ist **nicht vertrauenswürdig gegenüber der App**: Jeder kann die
Schnittstelle direkt ansprechen. Deshalb prüft er selbst:

* **Struktur** – ein Snapshot braucht `deviceId` und eine Hülle; ein Share
  braucht Nutzername, Schulnummer, Anzeigename und mindestens eine Hülle.
* **Anzeigenamen** – dieselbe Moderationsliste wie die App
  (`lib/src/moderation.dart`). Ein Name, den die App abgelehnt hätte, wird
  auch hier abgelehnt.
* **Zeichen** – Bezeichner werden auf `A-Za-z0-9_-` bereinigt und auf 128
  Zeichen gekürzt. Ein `../` kann so weder in einen Dateinamen noch in einen
  Vergleich gelangen.
* **Größen** – höchstens 16 MiB je Anfrage, 12 Geräte je Kette, 50 Shares je
  Person.
* **Häufigkeit** – 120 Lese- und 30 Schreibzugriffe pro Minute und IP.

Der Server prüft **nicht**, ob die Verschlüsselung stimmt – er kann es nicht.
Er speichert die Hüllen als Zeichenkette, ohne sie zu öffnen.

## Das Suchverzeichnis

`GET /v1/directory/{schulnummer}` liefert nur:

* Personen **derselben Schulnummer**, und
* nur Shares, die der Ersteller ausdrücklich als `searchable` markiert hat.

Ein als `isGlobal` markierter Share bleibt auffindbar und ist über seine ID
von jeder Schule aus nutzbar – er taucht aber **nicht** im Verzeichnis fremder
Schulen auf. "Global" heißt: jeder kann ihn mit dem Nutzernamen öffnen, nicht:
er wird überall hineinprominent.

Die verschlüsselten Hüllen sind im Verzeichnis **nicht** enthalten. Wer das
Verzeichnis sieht, sieht Nutzernamen, Anzeigenamen und die Anzahl der Shares –
sonst nichts.

## Wenn der Server ausfällt

Die App ist dadurch nicht kaputt: Sync und Shares sind Zusatzfunktionen. Ein
Sync-Lauf schlägt fehl, meldet es in der Statuszeile und lässt die lokalen
Daten unangetastet. Beim nächsten Lauf geht es weiter.

Daten, die auf dem Server liegen, kann der Betreiber **nicht** sichern und im
Notfall nicht wiederherstellen – er kann sie nur löschen. Das ist die Kehrseite
der Ende-zu-Ende-Verschlüsselung und sollte in der Datenschutzerklärung stehen.

## Tests

```sh
dart test
```

39 Tests decken ab: Persistenz über Neustarts, alle Endpunkte, die
Größen- und Mengenbegrenzungen, das Verzeichnis (nur eigene Schule, nur
suchbare Shares), die Namensmoderation, die Drosselung, das Schreiben-Token
und den Umgang mit einer beschädigten Datei.
