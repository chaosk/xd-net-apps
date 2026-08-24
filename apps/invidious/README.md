# Invidious

[Invidious](https://invidious.io/) via bjw-s `app-template` and **CloudNativePG**. **`invidious-companion`** is required for playback — web and companion share a 16-character secret key.

## Access

- Host: `https://invidious.net.ecksd.ee` (Gateway `shared`, Authentik forward-auth)
- Homepage tile in **Arr!** group

Forward auth covers `/` and `/companion`. **authentik** must be applied first (`ReferenceGrant` for namespace **`invidious`**).

## Secrets

| Secret | Purpose |
|--------|---------|
| `invidious-db` | CNPG bootstrap — `username` `invidious`, `password` |
| `invidious` | `database_url`, `hmac_key`, `companion_key` (exactly **16** chars, `pwgen 16 1`; wired to both containers) |

SOPS-encrypt placeholders in `secrets/`, sync **platform-secrets** before CNPG and the app start.

Authentik **Proxy provider** for `invidious.net.ecksd.ee` on the embedded outpost (same pattern as other forward-auth apps).

## App config

Non-secret settings live in **`INVIDIOUS_CONFIG`** in `values.yaml`. DB URL, `hmac_key`, and companion key come from the **`invidious`** Secret via `INVIDIOUS_*` env vars. `check_tables: true` builds schema on first start.

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG **`invidious-db`** on `local-path` (5Gi) |
| `values.yaml` | Web + companion controllers, probes, secret env |
| `service-companion.yaml` | Service **`invidious-companion:8282`** |
| `httproute.yaml` | `/` → web, `/companion` → companion; Homepage |
| `securitypolicy-forward-auth.yaml` | Envoy forward-auth |
| `restart-cronjob.yaml` | Daily rollout-restart (YouTube session/po-token refresh) |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/invidious" --enable-helm | kubectl apply -f -
```

Wait for **`invidious-db`** ready. Raise CronJob cadence in `restart-cronjob.yaml` if playback breaks between daily restarts.

**Argo CD Image Updater** tracks `quay.io/invidious/invidious` and **`invidious-companion`** in lockstep (`newest-build`) in `apps/argocd-image-updater/image-updater.yaml`.
