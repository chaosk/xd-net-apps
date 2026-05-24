# Paperless-ngx

Deploys [Paperless-ngx](https://docs.paperless-ngx.com/) with the **bjw-s app-template** chart, **CloudNativePG** PostgreSQL, and an in-cluster **Redis** broker.

## Access

- Host: `https://paperless.net.ecksd.ee` (Gateway API via shared cluster Gateway, Authentik forward-auth)

Forward auth needs **authentik** applied first (shared **ReferenceGrant** and outpost route). See **`apps/authentik/README.md`**.

## Before sync

1. **Secret `paperless-db`** in namespace **`paperless-ngx`** — CNPG bootstrap (`postgres.yaml`) and app DB password. Keys: `username`, `password` (owner/database `paperless`). See [`secrets/paperless-db.yaml`](../../secrets/paperless-db.yaml).

2. **Secret `paperless`** in namespace **`paperless-ngx`** — app bootstrap and signing key:
   - `PAPERLESS_SECRET_KEY` — `openssl rand -hex 32`
   - `PAPERLESS_ADMIN_USER` — initial admin username (e.g. `admin`; only used on first start when no users exist)
   - `PAPERLESS_ADMIN_PASSWORD` — initial admin password

   Encrypt both secrets with **SOPS** and sync **platform-secrets** before the CNPG cluster and app start ([`secrets/README.md`](../../secrets/README.md)).

3. **Homepage widget (optional)** — create an API token in Paperless (**Settings → My Profile**) and add **`secrets/homepage-paperless-widget.yaml`** (`HOMEPAGE_VAR_PAPERLESS_API_TOKEN`). Wire the env var in `apps/homepage/deployment.yaml` if not already present.

4. **Storage** — `pvc.yaml` uses **`synology`** for data (20Gi) and media (100Gi). Redis uses **`emptyDir`** (task broker only; not on NAS).

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `paperless-db` on `local-path` |
| `redis.yaml` | Task queue broker required when using PostgreSQL |
| `pvc.yaml` | Document data and media on Synology |
| `values.yaml` | Paperless container env, probes, resources |
| `httproute.yaml` | `paperless.net.ecksd.ee` + Homepage discovery |
| `securitypolicy-forward-auth.yaml` | Authentik Envoy forward-auth |

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/paperless-ngx" --enable-helm | kubectl apply -f -
```

Wait for **`paperless-db`** to report ready before the app pod stays healthy. On first login use the admin credentials from **`paperless`** Secret, then change the password in the UI.
