FROM nginx:1.25.5-alpine

# Replace the default "welcome" config with the Onyx routing config.
# Keeping this static (no envsubst) for determinism — the upstream hostnames
# are Railway-internal DNS names derived from service names, which are stable.
RUN rm -f /etc/nginx/conf.d/default.conf
COPY onyx.conf /etc/nginx/conf.d/onyx.conf

EXPOSE 80
