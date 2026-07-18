# GameCTL Project Zomboid dedicated server image — built from scratch so
# GameCTL controls exactly what runs.
#
# Sources: Debian's official base and Valve's official steamcmd tarball. The
# game (~5GB, app 380870, anonymous; bundles its own JRE) installs to the
# persistent volume at /home/steam/Zomboid/.gamectl/install on first boot; a
# normal boot NEVER runs steamcmd. Update via UPDATE_ON_START=true (GameCTL's
# per-instance auto-update toggle).
FROM debian:12-slim

RUN dpkg --add-architecture i386 && apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl lib32gcc-s1 tini util-linux \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/steamcmd && cd /opt/steamcmd \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xz \
    && /opt/steamcmd/steamcmd.sh +quit \
    && useradd -u 1000 -d /home/steam -m -s /usr/sbin/nologin steam

COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

ENV SERVER_NAME=servertest \
    ADMIN_PASSWORD=changeme \
    RCON_PORT=27015 \
    UPDATE_ON_START=false \
    UID=1000 \
    GID=1000

# 16261/udp direct + 16262/udp (per-player), RCON tcp internal-only.
# Config/saves persist at /home/steam/Zomboid (mount it).
EXPOSE 16261/udp 16262/udp 27015/tcp
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
