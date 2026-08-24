# Miniflux

[Miniflux](https://miniflux.app/) via bjw-s `app-template`, **CloudNativePG**, and **Authentik OIDC** (no Envoy forward-auth).

## Access

- Host: `https://miniflux.net.ecksd.ee` (Gateway `shared`)

## Secrets and Authentik

| Secret | Purpose |
|--------|---------|
| `miniflux-db` | CNPG bootstrap (`username`, `password`; owner/database `miniflux`) |
| `miniflux` | `DATABASE_URL`, `OAUTH2_CLIENT_ID`, `OAUTH2_CLIENT_SECRET` |
| `homepage-miniflux-widget` | `HOMEPAGE_VAR_MINIFLUX_API_KEY` — API key from Miniflux **Settings → API keys** |

Authentik provider slug **`miniflux`**: redirect URI `https://miniflux.net.ecksd.ee/oauth2/oidc/callback`. Discovery base `https://authentik.net.ecksd.ee/application/o/miniflux/`. `OAUTH2_USER_CREATION=1` creates Miniflux users on first OIDC sign-in.

SOPS-encrypt and sync **platform-secrets** before CNPG and the app start.

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `miniflux-db` on `local-path` |
| `values.yaml` | Miniflux env, OIDC, probes |
| `httproute.yaml` | `miniflux.net.ecksd.ee` + Homepage |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/miniflux" --enable-helm | kubectl apply -f -
```

**Argo CD Image Updater** tracks `miniflux/miniflux` in `apps/argocd-image-updater/image-updater.yaml`.
