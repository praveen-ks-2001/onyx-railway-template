# Pin the Onyx version via build arg. Override with `--build-arg ONYX_VERSION=v1.x.y`.
# The upstream `onyxdotapp/onyx-backend` image ships both the API server and the
# background worker binaries; we only diverge here in the entrypoint.
ARG ONYX_VERSION=latest
FROM onyxdotapp/onyx-backend:${ONYX_VERSION}

# Non-interactive, fail-fast defaults for the Python runtime.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

COPY entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# Railway ignores Dockerfile EXPOSE but this documents the contract.
EXPOSE 8080

ENTRYPOINT ["/railway-entrypoint.sh"]
