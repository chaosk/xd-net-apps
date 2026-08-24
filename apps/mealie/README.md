# Mealie

[Mealie](https://docs.mealie.io/) via bjw-s `app-template`, **CloudNativePG**, and **Authentik OIDC**.

## Access

- Host: `https://mealie.net.ecksd.ee` (Gateway `shared`)
- Sign in with **OpenID Connect**; local signup disabled (`ALLOW_SIGNUP=false`)

## Secrets and Authentik

| Secret | Purpose |
|--------|---------|
| `mealie-db` | CNPG bootstrap (`username`, `password`; owner/database `mealie`) |
| `mealie` | `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` from Authentik provider slug **`mealie`** |

Authentik **OAuth2/OpenID Provider** **`mealie`**: redirect URI `https://mealie.net.ecksd.ee/login`. Discovery URL in `values.yaml`: `https://authentik.net.ecksd.ee/application/o/mealie/.well-known/openid-configuration`. Users in Authentik group **`mealie-admins`** become Mealie admins; `OIDC_AUTO_REDIRECT=true`.

SOPS-encrypt and sync **platform-secrets** before CNPG and the app start.

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `mealie-db` on `local-path` |
| `pvc.yaml` | Recipe assets on Synology (`/app/data`) |
| `values.yaml` | Mealie env, OIDC, probes |
| `httproute.yaml` | `mealie.net.ecksd.ee` + Homepage |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/mealie" --enable-helm | kubectl apply -f -
```

**Argo CD Image Updater** tracks `ghcr.io/mealie-recipes/mealie` in `apps/argocd-image-updater/image-updater.yaml`.
