FROM opensearchproject/opensearch:3.4.0

USER root

# OpenSearch image has no gosu/su/runuser/setpriv — grab the gosu static binary
# so we can chown the Railway volume as root, then drop privileges to opensearch (uid 1000).
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/gosu \
        "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64"; \
    chmod +x /usr/local/bin/gosu; \
    /usr/local/bin/gosu nobody true

COPY entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["/usr/share/opensearch/opensearch-docker-entrypoint.sh", "opensearch"]
