#!/usr/bin/env bash
# api-server entrypoint for Railway.
#
# Responsibilities:
#   1. Run Alembic migrations (the upstream image's default CMD skips this).
#   2. Exec uvicorn so the python process becomes PID 1 and receives SIGTERM
#      directly — critical for graceful shutdown during Railway redeploys.
#
# Not done here:
#   - Vespa schema deployment — Onyx's Python startup handles that itself.
#   - Waiting for Postgres/Redis/Vespa/OpenSearch readiness — Onyx's
#     `app_base.py` already polls those with sensible timeouts.

set -euo pipefail

echo "[railway-entrypoint] alembic upgrade head"
alembic upgrade head

PORT="${PORT:-8080}"
WORKERS="${UVICORN_WORKERS:-1}"
LOG_LEVEL="${UVICORN_LOG_LEVEL:-info}"

echo "[railway-entrypoint] starting uvicorn onyx.main:app on 0.0.0.0:${PORT} (workers=${WORKERS})"
exec uvicorn onyx.main:app \
    --host 0.0.0.0 \
    --port "${PORT}" \
    --workers "${WORKERS}" \
    --log-level "${LOG_LEVEL}" \
    --proxy-headers \
    --forwarded-allow-ips='*'
