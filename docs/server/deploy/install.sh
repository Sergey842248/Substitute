#!/usr/bin/env bash
#
# Installiert den Substitute Sync- und Share-Server auf Ubuntu.
#
#   sudo ./deploy/install.sh
#
# Erwartet: Ubuntu mit systemd, ein installiertes `dart`, Root-Rechte.
# Nach dem Lauf noch:
#   sudo certbot --nginx -d substitute-sync.open-nexor.org
#   sudo systemctl restart nginx

set -euo pipefail

SERVER_USER="substitute-sync"
INSTALL_DIR="/opt/substitute-sync"
DATA_DIR="/var/lib/substitute-sync"
CONF_DIR="/etc/substitute-sync"
DOMAIN="substitute-sync.open-nexor.org"
PORT="8384"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
die() { printf '\033[31mFEHLER: %s\033[0m\n' "$1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "bitte mit sudo ausführen"

command -v dart >/dev/null || die "dart ist nicht installiert (apt-get install -y dart)"

# --- Dart: Die App braucht eine bestimmte Mindestversion für switch
#     Ausdrücke und Records.
dart --version

say "Benutzer $SERVER_USER"
if ! id -u "$SERVER_USER" >/dev/null 2>&1; then
  useradd --system --home-dir "$DATA_DIR" --shell /usr/sbin/nologin "$SERVER_USER"
fi
# 750: Der Server selbst darf lesen und schreiben, die Gruppe nicht.
install -d -m 750 -o "$SERVER_USER" -g "$SERVER_USER" "$DATA_DIR"

say "Programm nach $INSTALL_DIR"
# `pub get` läuft als Root; das ist unkritisch, weil der Server keine
# Build-Hooks ausführt – es gibt schlicht keine Abhängigkeiten.
install -d -m 755 "$INSTALL_DIR"
cp -r "$SOURCE_DIR/lib" "$SOURCE_DIR/bin" "$SOURCE_DIR/pubspec.yaml" \
      "$SOURCE_DIR/README.md" "$INSTALL_DIR/"
(cd "$INSTALL_DIR" && dart pub get)

say "Konfiguration nach $CONF_DIR"
install -d -m 750 "$CONF_DIR"
if [ ! -f "$CONF_DIR/server.env" ]; then
  # Kein Token: die App kennt kein Geheimnis, das sicher zu verteilen wäre.
  # Wer den Server ohne nginx betreibt, kann hier eines setzen – dann
  # verlangt der Server es bei jedem Schreibzugriff im Header `x-api-token`.
  cat > "$CONF_DIR/server.env" <<EOF
# Vom systemd-Unit gelesen. Nicht committen.
PORT=$PORT
DATA=$DATA_DIR
BIND=127.0.0.1
# TOKEN=hier-ein-langes-zufaelliges-passwort
EOF
  chmod 600 "$CONF_DIR/server.env"
  chown root:root "$CONF_DIR/server.env"
  say "server.env angelegt – bei Bedarf ein TOKEN ergänzen"
fi

say "systemd-Unit"
install -m 644 "$SOURCE_DIR/deploy/substitute-sync.service" \
  /etc/systemd/system/substitute-sync.service
systemctl daemon-reload
systemctl enable substitute-sync.service
systemctl restart substitute-sync.service
sleep 2
systemctl --no-pager --lines=5 status substitute-sync.service || true

say "nginx"
if command -v nginx >/dev/null; then
  install -m 644 "$SOURCE_DIR/deploy/nginx.conf" \
    "/etc/nginx/sites-available/$DOMAIN"
  ln -sfn "/etc/nginx/sites-available/$DOMAIN" \
    "/etc/nginx/sites-enabled/$DOMAIN"
  # Die Standardseite würde sonst auf Port 80 mit antworten.
  rm -f /etc/nginx/sites-enabled/default
  if nginx -t 2>/dev/null; then
    systemctl reload nginx
    say "nginx ist eingerichtet"
  else
    say "nginx-Konfiguration prüfen: nginx -t"
  fi
else
  say "nginx ist nicht installiert – $DOMAIN wird noch nicht ausgeliefert"
fi

say "Fertig"
cat <<EOF

Status prüfen:
  curl http://127.0.0.1:$PORT/v1/health     # -> {"status":"running"}

Protokoll:
  journalctl -u substitute-sync -f

Noch offen:
  1. DNS-A-Record für $DOMAIN auf diesen Server setzen
  2. Zertifikat:  certbot --nginx -d $DOMAIN
  3. nginx neu starten

Die Statusseite auf GitHub Pages fragt $PORT über
https://$DOMAIN/v1/health ab und zeigt "Server is running" oder
"Server is stopped".

Hinweis: Der Server kann die gespeicherten Daten nicht wiederherstellen –
sie sind nur für die Geräte lesbar, die den passenden Schlüssel haben.
EOF
