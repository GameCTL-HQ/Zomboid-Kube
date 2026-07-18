# GameCTL Project Zomboid dedicated server image — built from scratch so
# GameCTL controls exactly what runs.
#
# Sources: Debian's official base, Valve's official steamcmd tarball, and the
# PZ dedicated server from Steam's CDN (app 380870, anonymous). The server
# bundles its own JRE. Baked at build time; daily CI tracks new builds.
FROM debian:12-slim AS steam

RUN dpkg --add-architecture i386 && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl lib32gcc-s1 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /steamcmd && cd /steamcmd \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xz

ARG PZ_BUILDID=dev
RUN echo "target buildid: ${PZ_BUILDID}" \
    && for i in 1 2 3 4 5; do \
         /steamcmd/steamcmd.sh +force_install_dir /opt/pzserver +login anonymous +app_update 380870 validate +quit && break \
         || { echo "steamcmd attempt $i failed (cold-start config race); sleep + retry"; sleep 10; }; \
       done \
    && test -f /opt/pzserver/steamapps/appmanifest_380870.acf


FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates tini util-linux \
    && rm -rf /var/lib/apt/lists/*

COPY --from=steam --chown=1000:1000 /opt/pzserver /opt/pzserver
COPY --from=steam /steamcmd/linux64/steamclient.so /opt/steam-sdk64/steamclient.so
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN useradd -u 1000 -d /home/steam -m -s /usr/sbin/nologin steam \
    && chmod +x /usr/local/bin/entrypoint

ENV SERVER_NAME=servertest \
    ADMIN_PASSWORD=changeme \
    RCON_PORT=27015 \
    UID=1000 \
    GID=1000

# 16261/udp direct + 16262/udp (per-player), RCON tcp internal-only.
# Config/saves persist at /home/steam/Zomboid (mount it).
EXPOSE 16261/udp 16262/udp 27015/tcp
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
