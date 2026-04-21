#!/usr/bin/env bash
# background worker entrypoint.
#
# Why wait for api-server?
#   On first boot the Alembic migrations run inside api-server's entrypoint.
#   If the celery workers start before the schema exists, supervisord's
#   subprocesses crash-loop with "relation \"slack_bot\" does not exist".
#   We poll /health on api-server — it only returns 200 once migrations
#   and the Vespa schema deploy have completed.
#
# Toggle via env:
#   WAIT_FOR_API_SERVER=false   disables the wait loop entirely.
#   API_SERVER_URL=http://...   override the URL (defaults to private DNS).
#   WAIT_TIMEOUT_SECONDS=600    how long to wait before giving up.

set -euo pipefail

WAIT_FOR_API_SERVER="${WAIT_FOR_API_SERVER:-true}"
API_SERVER_URL="${API_SERVER_URL:-http://api-server.railway.internal:8080}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-600}"

if [[ "$WAIT_FOR_API_SERVER" == "true" ]]; then
    echo "[railway-entrypoint] waiting up to ${WAIT_TIMEOUT_SECONDS}s for ${API_SERVER_URL}/health"

    SECONDS_WAITED=0
    SLEEP_INTERVAL=5

    until curl -fsS --max-time 5 "${API_SERVER_URL}/health" >/dev/null 2>&1; do
        if (( SECONDS_WAITED >= WAIT_TIMEOUT_SECONDS )); then
            echo "[railway-entrypoint] timed out waiting for api-server, starting anyway"
            break
        fi
        sleep "$SLEEP_INTERVAL"
        SECONDS_WAITED=$(( SECONDS_WAITED + SLEEP_INTERVAL ))
    done

    if (( SECONDS_WAITED < WAIT_TIMEOUT_SECONDS )); then
        echo "[railway-entrypoint] api-server is healthy after ${SECONDS_WAITED}s"
    fi
fi

echo "[railway-entrypoint] exec supervisord"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
