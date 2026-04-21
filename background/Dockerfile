# Same base as api-server — supervisord bundles the celery workers that Onyx
# needs for indexing, connector runs, slack/teams webhooks, etc.
ARG ONYX_VERSION=latest
FROM onyxdotapp/onyx-backend:${ONYX_VERSION}

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

COPY entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

ENTRYPOINT ["/railway-entrypoint.sh"]
