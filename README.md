# Onyx on Railway — Strategy D template

Production-leaning deployment scaffolding for [Onyx](https://github.com/onyx-dot-app/onyx)
(formerly Danswer) on Railway. Four services ship as Dockerfiles in this repo
because the upstream images either lack tooling Railway needs or require
startup logic that's too fragile to express as a `startCommand` override. The
remaining six services are plain upstream images — deploy those straight from
the Railway dashboard.

## Architecture

```
                ┌──────────────┐
  browser ────▶ │    nginx     │  (public)  <-- this repo
                └──────┬───────┘
                       │  /api/*, /scim/*  ┌──────────────┐
                       ├──────────────────▶│  api-server  │  <-- this repo
                       │                   └──────┬───────┘
                       │  everything else         │
                       │  ┌──────────────┐        │
                       └─▶│  web-server  │        │
                          └──────┬───────┘        │
                                 │                │
                                 └──────┬─────────┘
                                        ▼
            ┌─────────────┬─────────────┬─────────────┬──────────────────┐
            │  Postgres   │   Redis     │    Vespa    │    OpenSearch    │  <-- this repo (OpenSearch)
            └─────────────┴─────────────┴─────────────┴──────────────────┘
                                        │                  │
                                ┌───────┴────────┬─────────┴──────────┐
                                ▼                ▼                    ▼
                        ┌────────────┐   ┌──────────────┐    ┌──────────────┐
                        │ background │   │  inference   │    │   indexing   │  <-- this repo (background)
                        │  worker    │   │ model server │    │ model server │
                        └────────────┘   └──────────────┘    └──────────────┘
```

## Service split

### In this repo (custom Dockerfiles)

| Service | Reason it's here |
|---|---|
| `opensearch/` | Upstream image has no `gosu`/`su`/`setpriv`, so there's no inline way to drop privileges. The Dockerfile installs `gosu` and the entrypoint chowns the volume before dropping to uid 1000. |
| `api-server/` | Runs `alembic upgrade head` before `uvicorn`. Baking this into the image avoids encoding the startup sequence in a fragile shell one-liner. |
| `background/` | CMD is `supervisord -c ...` (not the image default). Waits for api-server `/health` before starting celery workers to avoid crash-looping on missing tables. |
| `nginx/` | Config is parameterised via nginx's native `/etc/nginx/templates/*.template` mechanism. Base64 env-var smuggling is replaced by real files. |

### Deployed directly from Railway UI (upstream images)

| Service | How to add | Notes |
|---|---|---|
| Postgres | **+ Add → Database → PostgreSQL** | Railway-managed. |
| Redis | **+ Add → Database → Redis** | Railway-managed. |
| Vespa | **+ Add → Empty Service → source.image `vespaengine/vespa:8.609.39`** | Attach volume at `/opt/vespa/var`. Set `RAILWAY_RUN_UID=0` and `VESPA_SKIP_UPGRADE_CHECK=true`. |
| inference-model-server | **source.image `onyxdotapp/onyx-model-server:latest`** | Volume at `/root/.cache` for model downloads. Port 9000. |
| indexing-model-server | Same image as above | Add `INDEXING_ONLY=True`. Volume at `/root/.cache`. Port 9000. |
| web-server | **source.image `onyxdotapp/onyx-web-server:latest`** | No volume. Listens on 3000. |

## Repo layout

```
onyx-railway-template/
├── README.md
├── opensearch/
│   ├── Dockerfile              FROM opensearchproject/opensearch:3.4.0 + gosu
│   ├── entrypoint.sh           chown volume, exec gosu opensearch
│   └── railway.json
├── api-server/
│   ├── Dockerfile              FROM onyxdotapp/onyx-backend:${ONYX_VERSION}
│   ├── entrypoint.sh           alembic upgrade head → exec uvicorn
│   └── railway.json
├── background/
│   ├── Dockerfile              FROM onyxdotapp/onyx-backend:${ONYX_VERSION}
│   ├── entrypoint.sh           wait-for api-server /health → exec supervisord
│   └── railway.json
└── nginx/
    ├── Dockerfile              FROM nginx:1.25.5-alpine + template
    ├── onyx.conf.template      routes /api/* → api-server, else → web-server
    └── railway.json
```

## Deployment procedure

### 1 — Create the project

In the Railway dashboard, create a new project. Connect this GitHub repo.
Railway will offer to create services — for each service in this repo, set
**Settings → Source → Root Directory** to the subdirectory (e.g. `/opensearch`).
Railway auto-detects the `Dockerfile` in that directory.

### 2 — Add the Railway-UI services

Add the six services listed above (Postgres, Redis, Vespa, inference-model-server,
indexing-model-server, web-server). For each Docker-image service, Railway
will not auto-generate a public domain — only do so for nginx.

### 3 — Create volumes

Only five services need volumes:

| Service | Mount path |
|---|---|
| Postgres | `/var/lib/postgresql/data` (Railway handles this automatically) |
| Redis | `/data` (Railway handles this automatically) |
| OpenSearch | `/usr/share/opensearch/data` |
| Vespa | `/opt/vespa/var` |
| inference-model-server | `/root/.cache` |
| indexing-model-server | `/root/.cache` |

### 4 — Generate the encryption key ONCE

```bash
openssl rand -hex 32
```

Save that value — you'll paste it into two services. **Never** use Railway's
`${{secret(32)}}` template for encryption keys: it re-evaluates on every
deploy, immediately making all previously encrypted data undecryptable.

### 5 — Set environment variables

Each service's vars are listed below. Values in `${{...}}` are Railway
cross-service references — copy them verbatim.

#### OpenSearch

| Variable | Value |
|---|---|
| `RAILWAY_RUN_UID` | `0` |
| `discovery.type` | `single-node` |
| `DISABLE_SECURITY_PLUGIN` | `true` |
| `DISABLE_INSTALL_DEMO_CONFIG` | `true` |
| `OPENSEARCH_JAVA_OPTS` | `-Xms1g -Xmx1g` |
| `OPENSEARCH_INITIAL_ADMIN_PASSWORD` | any long random string |

> `RAILWAY_RUN_UID=0` is required so the entrypoint runs as root long enough
> to chown the volume; `gosu` then drops to uid 1000.

#### Vespa

| Variable | Value |
|---|---|
| `RAILWAY_RUN_UID` | `0` |
| `VESPA_SKIP_UPGRADE_CHECK` | `true` |

#### inference-model-server

| Variable | Value |
|---|---|
| `PORT` | `9000` |
| `MIN_THREADS_ML_MODELS` | `1` |
| `LOG_LEVEL` | `info` |
| `RAILWAY_RUN_UID` | `0` |

#### indexing-model-server

Same as inference-model-server, plus:

| Variable | Value |
|---|---|
| `INDEXING_ONLY` | `True` |

#### api-server

| Variable | Value |
|---|---|
| `PORT` | `8080` |
| `AUTH_TYPE` | `basic` |
| `POSTGRES_HOST` | `${{Postgres.PGHOST}}` |
| `POSTGRES_PORT` | `${{Postgres.PGPORT}}` |
| `POSTGRES_USER` | `${{Postgres.PGUSER}}` |
| `POSTGRES_PASSWORD` | `${{Postgres.PGPASSWORD}}` |
| `POSTGRES_DB` | `${{Postgres.PGDATABASE}}` |
| `VESPA_HOST` | `${{Vespa.RAILWAY_PRIVATE_DOMAIN}}` |
| `REDIS_HOST` | `${{Redis.REDISHOST}}` |
| `REDIS_PORT` | `${{Redis.REDISPORT}}` |
| `REDIS_PASSWORD` | `${{Redis.REDIS_PASSWORD}}` |
| `MODEL_SERVER_HOST` | `${{inference-model-server.RAILWAY_PRIVATE_DOMAIN}}` |
| `MODEL_SERVER_PORT` | `9000` |
| `INDEXING_MODEL_SERVER_HOST` | `${{indexing-model-server.RAILWAY_PRIVATE_DOMAIN}}` |
| `INDEXING_MODEL_SERVER_PORT` | `9000` |
| `OPENSEARCH_HOST` | `${{OpenSearch.RAILWAY_PRIVATE_DOMAIN}}` |
| `OPENSEARCH_PORT` | `9200` |
| `OPENSEARCH_FOR_ONYX_ENABLED` | `true` |
| `OPENSEARCH_DEFAULT_SCHEME` | `http` |
| `FILE_STORE_BACKEND` | `postgres` |
| `ENCRYPTION_KEY_SECRET` | **the hex string from step 4** |
| `USER_AUTH_SECRET` | another `openssl rand -hex 32` |
| `SESSION_EXPIRE_TIME_SECONDS` | `86400` |
| `DISABLE_GENERATIVE_AI` | `false` |
| `LOG_LEVEL` | `info` |

#### background

Identical to api-server (all the same DB / Vespa / Redis / model-server / OpenSearch /
encryption keys), **plus**:

| Variable | Value |
|---|---|
| `API_SERVER_URL` | `http://${{api-server.RAILWAY_PRIVATE_DOMAIN}}:8080` |
| `WAIT_FOR_API_SERVER` | `true` |

Do **not** set `PORT` on this service — it has no HTTP listener.

#### web-server

| Variable | Value |
|---|---|
| `PORT` | `3000` |
| `INTERNAL_URL` | `http://${{api-server.RAILWAY_PRIVATE_DOMAIN}}:8080` |

#### nginx

| Variable | Value |
|---|---|
| `API_SERVER_HOST` | `${{api-server.RAILWAY_PRIVATE_DOMAIN}}` |
| `API_SERVER_PORT` | `8080` |
| `WEB_SERVER_HOST` | `${{web-server.RAILWAY_PRIVATE_DOMAIN}}` |
| `WEB_SERVER_PORT` | `3000` |

### 6 — Generate the public domain

Only nginx should be publicly reachable.

In the Railway dashboard: nginx service → **Settings → Networking → Generate
Domain**. Then confirm the **target port** is `80` (Railway sometimes leaves
it blank — set it explicitly or you'll get 502s).

### 7 — Deploy order

Railway parallelises deploys by default, which is usually fine because each
service's entrypoint waits for its dependencies. Rough order:

1. Postgres, Redis — first (everything depends on them).
2. Vespa, OpenSearch — bring up next. OpenSearch will take ~2 minutes on cold start.
3. inference-model-server, indexing-model-server — download models on first boot (several minutes).
4. api-server — runs migrations, deploys Vespa schema, starts uvicorn.
5. background — waits for api-server `/health`, then starts supervisord.
6. web-server — boots quickly.
7. nginx — needs api-server and web-server healthy to route.

## Troubleshooting

**`OpenSearch cannot run as root`** — `RAILWAY_RUN_UID` isn't `0`, or the
entrypoint isn't being used. Verify the service's Root Directory points at
`/opensearch` and the Dockerfile built successfully.

**`AccessDeniedException: /usr/share/opensearch/data/nodes`** — the volume
exists but the chown didn't run. This usually means the container ran the
default CMD instead of our `railway-entrypoint.sh`. Check the service's
`Dockerfile` was used (Build Logs → "Using detected Dockerfile").

**api-server `Data is not valid UTF-8 — likely encrypted with a different key`**
— `ENCRYPTION_KEY_SECRET` rotated between deploys. You used `${{secret(N)}}`
somewhere. Set a hardcoded hex value, then wipe and re-run migrations:

```sql
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
```

from a Railway Postgres shell, then redeploy api-server.

**502 from nginx** — api-server or web-server isn't healthy. Curl the internal
`/health` and `/` endpoints from any service's shell to narrow down which side
is down.

**background keeps crash-looping** — usually means api-server's migrations
haven't run. Check api-server logs for alembic errors. Set
`WAIT_FOR_API_SERVER=true` (the default) so background pauses until api-server
returns 200 on `/health`.

## Pinning for production

Before pushing to production:

1. Replace `ONYX_VERSION=latest` with a tagged version in each Dockerfile's
   `ARG ONYX_VERSION=...` line. The Onyx team publishes version tags in the
   [onyx GitHub releases](https://github.com/onyx-dot-app/onyx/releases).
2. Pin `opensearchproject/opensearch`, `vespaengine/vespa`, `nginx`, and the
   `onyxdotapp/onyx-*` images to specific digests (`@sha256:...`) rather than
   tags, so rebuilds are deterministic.
3. Capture a Postgres backup schedule (Railway has snapshots, but export
   periodically as well).
4. Set `DISABLE_GENERATIVE_AI=true` until you've wired up an LLM provider.

## Credits

Based on the [official Onyx docker-compose setup](https://github.com/onyx-dot-app/onyx/blob/main/deployment/docker_compose/docker-compose.yml).
The Railway-specific patterns here came out of a prior autonomous deployment
attempt that failed on OpenSearch volume permissions and `${{secret}}` rotation
— the fixes are baked in.
