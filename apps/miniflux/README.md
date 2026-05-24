# Miniflux

Deploys [Miniflux](https://miniflux.app/) with the **bjw-s app-template** chart, **CloudNativePG** PostgreSQL, and **Authentik OIDC** login.

## Access

- Host: `https://miniflux.net.ecksd.ee` (Gateway API via shared cluster Gateway)

Sign in with **OpenID Connect** (Authentik OIDC provider); there is no Envoy forward-auth on this route.

## Before sync

1. **Secret `miniflux-db`** in namespace **`miniflux`** — CNPG bootstrap (`postgres.yaml`). Keys: `username`, `password` (owner/database `miniflux`). See [`secrets/miniflux-db.yaml`](../../secrets/miniflux-db.yaml).

2. **Secret `miniflux`** in namespace **`miniflux`**:
   - `DATABASE_URL` — `postgres://miniflux:<password>@miniflux-db-rw:5432/miniflux?sslmode=disable` (password must match `miniflux-db`)
   - `OAUTH2_CLIENT_ID` and `OAUTH2_CLIENT_SECRET` — from the Authentik OAuth2/OpenID **Provider** (slug **`miniflux`**)

   Encrypt with **SOPS** and sync **platform-secrets** before the CNPG cluster and app start ([`secrets/README.md`](../../secrets/README.md)).

3. **Authentik OIDC** — create an **OAuth2/OpenID Provider** with slug **`miniflux`** and redirect URI `https://miniflux.net.ecksd.ee/oauth2/oidc/callback`. Copy the client ID and secret into **`secrets/miniflux.yaml`**. Discovery URL is `https://authentik.net.ecksd.ee/application/o/miniflux/` (Miniflux appends `.well-known/openid-configuration`; see [Miniflux how-to](https://miniflux.app/docs/howto.html)). `OAUTH2_USER_CREATION=1` creates Miniflux users on first OIDC sign-in.

4. **Homepage widget (optional)** — create an API key in Miniflux (**Settings → API keys**) and add **`secrets/homepage-miniflux-widget.yaml`** (`HOMEPAGE_VAR_MINIFLUX_API_KEY`). The env var is wired in `apps/homepage/deployment.yaml`.

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `miniflux-db` on `local-path` |
| `values.yaml` | Miniflux container env, OIDC, probes, resources |
| `httproute.yaml` | `miniflux.net.ecksd.ee` + Homepage discovery |

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/miniflux" --enable-helm | kubectl apply -f -
```

Wait for **`miniflux-db`** to report ready before the app pod stays healthy. Open the URL and use **Sign in with OpenID Connect** in Miniflux.
