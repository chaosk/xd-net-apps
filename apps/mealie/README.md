# Mealie

Deploys [Mealie](https://docs.mealie.io/) with the **bjw-s app-template** chart, **CloudNativePG** PostgreSQL, and **Authentik OIDC** login.

## Access

- Host: `https://mealie.net.ecksd.ee` (Gateway API via shared cluster Gateway)

Sign in with **OpenID Connect** (Authentik); local signup is disabled (`ALLOW_SIGNUP=false`).

## Before sync

1. **Secret `mealie-db`** in namespace **`mealie`** — CNPG bootstrap (`postgres.yaml`). Keys: `username`, `password` (owner/database `mealie`). See [`secrets/mealie-db.yaml`](../../secrets/mealie-db.yaml).

2. **Secret `mealie`** in namespace **`mealie`** — `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET` from the Authentik OAuth2/OpenID **Provider** (slug **`mealie`**). See [`secrets/mealie.yaml`](../../secrets/mealie.yaml).

   Encrypt with **SOPS** and sync **platform-secrets** before the CNPG cluster and app start ([`secrets/README.md`](../../secrets/README.md)).

3. **Authentik OIDC** — create an **OAuth2/OpenID Provider** with slug **`mealie`**, client type **confidential**, and redirect URI `https://mealie.net.ecksd.ee/login`. Copy the client ID and secret into **`secrets/mealie.yaml`**. Discovery URL is `https://authentik.net.ecksd.ee/application/o/mealie/.well-known/openid-configuration` (set in `values.yaml` as `OIDC_CONFIGURATION_URL`). Users in the **`mealie-admins`** group in Authentik become Mealie admins; `OIDC_AUTO_REDIRECT=true` sends visitors straight to Authentik.

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `mealie-db` on `local-path` |
| `pvc.yaml` | Recipe assets and app data on Synology (`/app/data`) |
| `values.yaml` | Mealie container env, OIDC, probes, resources |
| `httproute.yaml` | `mealie.net.ecksd.ee` + Homepage discovery |

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/mealie" --enable-helm | kubectl apply -f -
```

Wait for **`mealie-db`** to report ready before the app pod stays healthy. Open the URL and use **Login with Authentik** in Mealie.
