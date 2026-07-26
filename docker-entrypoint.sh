#!/bin/sh
set -eu

CONFIG_DIR="${XDG_CONFIG_HOME:-/config}"
PLUGIN_DIR="${CONFIG_DIR}/plugins/${TUBIFARRY_OWNER:-Zerlaxv1}/Tubifarry"

mkdir -p "${CONFIG_DIR}"

# Replace rather than merge: a plugin left by an older image would keep its assemblies
# next to the new ones, and Lidarr loads whichever it finds first.
if [ -d /opt/tubifarry ]; then
    rm -rf "${PLUGIN_DIR}"
    mkdir -p "${PLUGIN_DIR}"
    cp -a /opt/tubifarry/. "${PLUGIN_DIR}/"
    echo "[entrypoint] Tubifarry installed into ${PLUGIN_DIR}"
fi

exec /app/Lidarr -nobrowser -data="${CONFIG_DIR}" "$@"
