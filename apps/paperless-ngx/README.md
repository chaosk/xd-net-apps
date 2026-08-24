# Paperless-ngx

[Paperless-ngx](https://docs.paperless-ngx.com/) via bjw-s `app-template`, **CloudNativePG**, in-cluster **Redis**, and **Authentik forward-auth**.

## Access

- Host: `https://paperless.net.ecksd.ee` (Gateway `shared`, Authentik forward-auth)

Forward auth needs **authentik** applied first. See **`apps/authentik/README.md`**.

## Secrets

| Secret | Purpose |
|--------|---------|
| `paperless-db` | CNPG bootstrap (`username`, `password`; owner/database `paperless`) |
| `paperless` | `PAPERLESS_SECRET_KEY`, `PAPERLESS_ADMIN_USER`, `PAPERLESS_ADMIN_PASSWORD` (first-run admin) |
| `homepage-paperless-widget` | `HOMEPAGE_VAR_PAPERLESS_API_TOKEN` — token from **Settings → My Profile** |

SOPS-encrypt and sync **platform-secrets** before CNPG and the app start.

## Storage

- Document data and media: StorageClass **`synology`** (20Gi + 100Gi)
- Redis: **`emptyDir`** (task broker only)

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `paperless-db` on `local-path` |
| `redis.yaml` | Task queue broker |
| `pvc.yaml` | Data and media on Synology |
| `values.yaml` | Paperless env, probes |
| `httproute.yaml` | `paperless.net.ecksd.ee` + Homepage |
| `securitypolicy-forward-auth.yaml` | Authentik Envoy forward-auth |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/paperless-ngx" --enable-helm | kubectl apply -f -
```

**Argo CD Image Updater** tracks `ghcr.io/paperless-ngx/paperless-ngx` in `apps/argocd-image-updater/image-updater.yaml`.
