FROM nginx:1.25.5-alpine

# Remove the default "welcome to nginx" config — we provide our own.
RUN rm -f /etc/nginx/conf.d/default.conf

# nginx's official image automatically runs envsubst on any .template file in
# /etc/nginx/templates/ at container start, writing the output to
# /etc/nginx/conf.d/<filename-without-.template>. This is the clean, upstream-
# sanctioned way to parameterise the config — no base64 hacks.
COPY onyx.conf.template /etc/nginx/templates/onyx.conf.template

# Sensible defaults — overridable per-environment on Railway.
# Only these tokens will be substituted; everything else (nginx variables like
# $host, $remote_addr) stays literal because NGINX_ENVSUBST_FILTER restricts it.
ENV NGINX_ENVSUBST_FILTER='^(API_SERVER_HOST|API_SERVER_PORT|WEB_SERVER_HOST|WEB_SERVER_PORT|NGINX_LISTEN_PORT|NGINX_MAX_BODY_SIZE|NGINX_RESOLVER|NGINX_PROXY_TIMEOUT)$' \
    API_SERVER_HOST=api-server.railway.internal \
    API_SERVER_PORT=8080 \
    WEB_SERVER_HOST=web-server.railway.internal \
    WEB_SERVER_PORT=3000 \
    NGINX_LISTEN_PORT=80 \
    NGINX_MAX_BODY_SIZE=1024m \
    NGINX_RESOLVER='1.1.1.1 1.0.0.1' \
    NGINX_PROXY_TIMEOUT=300s

EXPOSE 80
