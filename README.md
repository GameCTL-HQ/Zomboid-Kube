# Zomboid-Kube

A from-scratch **Project Zomboid dedicated server** image for Kubernetes,
maintained by [GameCTL](https://github.com/GameCTL-HQ/GameCTL). Sources:
Debian's official base, Valve's official steamcmd, and the server from Steam's
CDN (app `380870`, anonymous; bundles its own JRE). Baked at build time; daily
CI tracks new builds.

## Image

`ghcr.io/gamectl-hq/zomboid-kube` — `:latest` or `:build-<steam buildid>`.

## Usage

```bash
docker run -d --name zomboid \
  -p 16261-16262:16261-16262/udp \
  -v /srv/zomboid:/home/steam/Zomboid \
  -e SERVER_NAME=servertest -e ADMIN_PASSWORD=secret123 \
  -e RCON_PASSWORD=rcon-secret \
  ghcr.io/gamectl-hq/zomboid-kube:latest
```

Config + saves persist at `/home/steam/Zomboid` (`Server/<name>.ini`,
`Saves/`, `db/`). GameCTL-owned ini keys (RCON, password, max players) are
re-applied each boot; other operator edits survive.

| Var | Default | Notes |
|-----|---------|-------|
| `SERVER_NAME` | `servertest` | Selects `Server/<name>.ini` |
| `ADMIN_PASSWORD` | `changeme` | Admin account |
| `SERVER_PASSWORD` | — | Join password |
| `RCON_PORT` / `RCON_PASSWORD` | `27015` / — | Keep RCON off public tunnels |
| `MAX_PLAYERS` | — | |
| `UID`/`GID` | `1000` | Unprivileged |
