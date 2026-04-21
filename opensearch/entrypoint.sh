#!/usr/bin/env bash
# Railway-specific entrypoint for OpenSearch.
#
# Why this exists:
#   Railway volumes are mounted root-owned, but OpenSearch refuses to run as root
#   (Java bootstrap SecurityException). The upstream OpenSearch 3.x image ships
#   without gosu/su/runuser/setpriv, so there is no inline way to drop privileges.
#
# What this does:
#   1. Runs as root (via RAILWAY_RUN_UID=0 on the service).
#   2. chowns the data volume to the opensearch user (uid:gid = 1000:1000).
#   3. exec's gosu to drop to opensearch, preserving PID 1 and signal forwarding.

set -euo pipefail

DATA_DIR="${OPENSEARCH_DATA_DIR:-/usr/share/opensearch/data}"
RUN_AS_UID="${OPENSEARCH_UID:-1000}"
RUN_AS_GID="${OPENSEARCH_GID:-1000}"

if [[ ! -d "$DATA_DIR" ]]; then
    echo "[railway-entrypoint] data dir $DATA_DIR does not exist, creating"
    mkdir -p "$DATA_DIR"
fi

CURRENT_OWNER="$(stat -c '%u:%g' "$DATA_DIR")"
if [[ "$CURRENT_OWNER" != "${RUN_AS_UID}:${RUN_AS_GID}" ]]; then
    echo "[railway-entrypoint] chown $DATA_DIR from $CURRENT_OWNER to ${RUN_AS_UID}:${RUN_AS_GID}"
    chown -R "${RUN_AS_UID}:${RUN_AS_GID}" "$DATA_DIR"
else
    echo "[railway-entrypoint] $DATA_DIR already owned by ${RUN_AS_UID}:${RUN_AS_GID}, skipping chown"
fi

echo "[railway-entrypoint] exec gosu opensearch $*"
exec gosu opensearch "$@"
