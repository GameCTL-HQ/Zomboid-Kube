#!/usr/bin/env bash
# GameCTL Project Zomboid entrypoint. Server baked at /opt/pzserver (bundled
# JRE); config + saves persist at /home/steam/Zomboid (same path contract as
# before). Env: SERVER_NAME, ADMIN_PASSWORD, RCON_PORT, RCON_PASSWORD,
# SERVER_PASSWORD, MAX_PLAYERS.
set -euo pipefail

uid="${UID:-1000}"; gid="${GID:-1000}"
name="${SERVER_NAME:-servertest}"

export HOME=/home/steam
ZOMBOID="$HOME/Zomboid"
mkdir -p "$ZOMBOID/Server" "$HOME/.steam/sdk64"
ln -sf /opt/steam-sdk64/steamclient.so "$HOME/.steam/sdk64/steamclient.so"

# Manage the GameCTL-owned ini keys, preserving operator edits to the rest.
ini="$ZOMBOID/Server/${name}.ini"
touch "$ini"
setkey() { # key value
  grep -qE "^$1=" "$ini" && sed -i "s|^$1=.*|$1=$2|" "$ini" || echo "$1=$2" >> "$ini"
}
[ -n "${RCON_PORT:-}" ]       && setkey RCONPort "$RCON_PORT"
[ -n "${RCON_PASSWORD:-}" ]   && setkey RCONPassword "$RCON_PASSWORD"
[ -n "${SERVER_PASSWORD:-}" ] && setkey Password "$SERVER_PASSWORD"
[ -n "${MAX_PLAYERS:-}" ]     && setkey MaxPlayers "$MAX_PLAYERS"

chown -R "$uid:$gid" "$HOME" 2>/dev/null || true

echo "gamectl: starting Project Zomboid server '${name}' (16261-16262/udp, rcon ${RCON_PORT:-27015}/tcp)"
cd /opt/pzserver
run=(./start-server.sh -cachedir="$ZOMBOID" -servername "$name" -adminpassword "${ADMIN_PASSWORD:-changeme}")
if [ "$(id -u)" = "0" ]; then
  exec setpriv --reuid "$uid" --regid "$gid" --clear-groups "${run[@]}"
else
  exec "${run[@]}"
fi
