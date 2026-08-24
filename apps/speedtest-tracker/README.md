# Speedtest Tracker

[Speedtest Tracker](https://docs.speedtest-tracker.dev/) (linuxserver image) via bjw-s `app-template` and **CloudNativePG** PostgreSQL.

## Access

- Host: `https://speedtest.net.ecksd.ee` (Gateway `shared`; public dashboard, no Authentik)

## Secrets

| Secret | Keys |
|--------|------|
| `speedtest-tracker-db` | `username`, `password` — owner/database `speedtest` / `speedtest_tracker` |
| `speedtest-tracker` | `APP_KEY` — `base64:` + 32 random bytes |
| `homepage-speedtest-tracker-widget` | `HOMEPAGE_VAR_SPEEDTEST_TRACKER_API_KEY` — token from **Admin → API tokens** (Read Results) |

SOPS-encrypt and sync **platform-secrets** before CNPG and the app start ([`secrets/README.md`](../../secrets/README.md)).

## Runtime

- App config PVC: StorageClass **`synology`** (1Gi)
- PostgreSQL: CNPG on **`local-path`**
- Schedule: every five minutes (`*/5 * * * *`) against servers `7202`, `23677`, `14139` (`values.yaml`)
- Prometheus: enabled in app **Settings → Data platforms → Prometheus**; scrapes from `apps/monitoring/scrape-apps.yaml` at `/prometheus`; Grafana dashboard in **Misc**

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `speedtest-tracker-db` |
| `pvc.yaml` | App config on Synology |
| `values.yaml` | Container env, probes, resources |
| `httproute.yaml` | `speedtest.net.ecksd.ee` + Homepage |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/speedtest-tracker" --enable-helm | kubectl apply -f -
```

Wait for **`speedtest-tracker-db`** ready before the app pod stays healthy.

**Argo CD Image Updater** tracks `lscr.io/linuxserver/speedtest-tracker` in `apps/argocd-image-updater/image-updater.yaml`.
