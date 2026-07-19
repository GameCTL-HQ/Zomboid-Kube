#!/usr/bin/env bash
# GameCTL Project Zomboid entrypoint. The game lives on the volume at
# /home/steam/Zomboid/.gamectl/install; config + saves at /home/steam/Zomboid
# (same mount contract as before). A normal boot never runs steamcmd;
# UPDATE_ON_START=true updates once (GameCTL toggle).
set -euo pipefail

uid="${UID:-1000}"; gid="${GID:-1000}"
name="${SERVER_NAME:-servertest}"

export HOME=/home/steam
ZOMBOID="$HOME/Zomboid"
GAMEDIR="$ZOMBOID/.gamectl/install"
echo "gamectl: entrypoint starting (data: $ZOMBOID)"
mkdir -p "$GAMEDIR" "$ZOMBOID/.gamectl/steamhome" "$ZOMBOID/Server"
chown "$uid:$gid" "$ZOMBOID" "$ZOMBOID/Server" 2>/dev/null || true
# Fix ownership of files dropped onto the share as root (e.g. an operator
# scp'ing in saves/worlds) — kubelet does not apply fsGroup to NFS volumes,
# and root-owned data files can break the server in silent ways (see
# Necesse-Kube d4b719f). Only touches mismatched files; the steamcmd install
# tree is pruned (large, root-managed, read-only for the run user).
find "$ZOMBOID" -path "$ZOMBOID/.gamectl" -prune -o ! -user "$uid" -exec chown "$uid:$gid" {} + 2>/dev/null || true

steamcmd_update() {
  for i in 1 2 3 4 5 6; do
    HOME="$ZOMBOID/.gamectl/steamhome" /opt/steamcmd/steamcmd.sh \
      +force_install_dir "$GAMEDIR" +login anonymous +app_update 380870 validate +quit && return 0
    echo "gamectl: steamcmd attempt $i failed — clearing appcache and retrying" >&2
    rm -rf "$ZOMBOID/.gamectl/steamhome/Steam/appcache" 2>/dev/null || true
    [ "$i" -ge 4 ] && { echo "gamectl: resetting steam state" >&2; rm -rf "$ZOMBOID/.gamectl/steamhome/Steam" 2>/dev/null || true; }
    sleep 10
  done
  return 1
}

need_install=0
[ -f "$GAMEDIR/start-server.sh" ] || need_install=1
if [ "$need_install" = "1" ] || [ "$(echo "${UPDATE_ON_START:-false}" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  echo "gamectl: installing/updating Project Zomboid into $GAMEDIR"
  steamcmd_update || { [ "$need_install" = "0" ] && echo "gamectl: WARN update failed, starting existing install" || { echo "ERROR: install failed" >&2; exit 1; }; }
else
  echo "gamectl: existing install found — starting without steamcmd (set UPDATE_ON_START=true to update)"
fi

# Manage the GameCTL-owned ini keys, preserving operator edits to the rest.
ini="$ZOMBOID/Server/${name}.ini"
touch "$ini"
setkey() { grep -qE "^$1=" "$ini" && sed -i "s|^$1=.*|$1=$2|" "$ini" || echo "$1=$2" >> "$ini"; }
[ -n "${RCON_PORT:-}" ]       && setkey RCONPort "$RCON_PORT"
[ -n "${RCON_PASSWORD:-}" ]   && setkey RCONPassword "$RCON_PASSWORD"
[ -n "${SERVER_PASSWORD:-}" ] && setkey Password "$SERVER_PASSWORD"
[ -n "${MAX_PLAYERS:-}" ]     && setkey MaxPlayers "$MAX_PLAYERS"
chown "$uid:$gid" "$ini" 2>/dev/null || true

mkdir -p "$HOME/.steam/sdk64"
ln -sf /opt/steamcmd/linux64/steamclient.so "$HOME/.steam/sdk64/steamclient.so"
chown -R "$uid:$gid" "$HOME/.steam" 2>/dev/null || true

echo "gamectl: starting Project Zomboid server '${name}' (16261-16262/udp, rcon ${RCON_PORT:-27015}/tcp)"
cd "$GAMEDIR"
run=(./start-server.sh -cachedir="$ZOMBOID" -servername "$name" -adminpassword "${ADMIN_PASSWORD:-changeme}")
if [ "$(id -u)" = "0" ]; then
  exec setpriv --reuid "$uid" --regid "$gid" --clear-groups "${run[@]}"
else
  exec "${run[@]}"
fi
