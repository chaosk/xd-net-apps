# Speedtest Tracker

Deploys [Speedtest Tracker](https://docs.speedtest-tracker.dev/) (linuxserver image) with the **bjw-s app-template** chart and **CloudNativePG** PostgreSQL.

## Access

- Host: `https://speedtest.net.ecksd.ee` (Gateway API via shared cluster Gateway; public dashboard, no Authentik)

## Before sync

1. **Secret `speedtest-tracker-db`** in namespace **`speedtest-tracker`** — CNPG bootstrap (`postgres.yaml`) and app DB password. Keys: `username`, `password` (owner/database `speedtest` / `speedtest_tracker`). See [`secrets/speedtest-tracker-db.yaml`](../../secrets/speedtest-tracker-db.yaml).

2. **Secret `speedtest-tracker`** in namespace **`speedtest-tracker`** — Laravel app key:
   - `APP_KEY` — `base64:` plus 32 random bytes, e.g. `echo "base64:$(openssl rand -base64 32)"`

   Encrypt both secrets with **SOPS** and sync **platform-secrets** before the CNPG cluster and app start ([`secrets/README.md`](../../secrets/README.md)).

3. **Homepage widget (optional)** — after first login, create an API token in Speedtest Tracker (**Admin → API tokens**, ability **Read Results**) and add **`secrets/homepage-speedtest-tracker-widget.yaml`** (`HOMEPAGE_VAR_SPEEDTEST_TRACKER_API_KEY`). Wire the env var in `apps/homepage/deployment.yaml`.

4. **Storage** — `pvc.yaml` uses **`synology`** for `/config` (1Gi). PostgreSQL data stays on CNPG **`local-path`**.

5. **Scheduling** — `values.yaml` runs tests every five minutes (`*/5 * * * *`) against servers `7202`, `23677`, and `14139`. Adjust `SPEEDTEST_SCHEDULE` and `SPEEDTEST_SERVERS` there if needed.

6. **Prometheus (optional)** — after the app is running, enable **Settings → Data platforms → Prometheus** in the UI. Under **Allowed IPs**, permit in-cluster scrapes (for example `10.0.0.0/8` or your pod CIDR). Metrics are scraped by `apps/monitoring/scrape-apps.yaml` at `/prometheus`; view them in Grafana under folder **Misc** ([community dashboard](https://github.com/CrazyWolf13/Speedtest-Tracker-Prometheus)).

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG cluster `speedtest-tracker-db` on `local-path` |
| `pvc.yaml` | App config on Synology |
| `values.yaml` | Container env, probes, resources |
| `httproute.yaml` | `speedtest.net.ecksd.ee` + Homepage discovery |

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/speedtest-tracker" --enable-helm | kubectl apply -f -
```

Wait for **`speedtest-tracker-db`** to report ready before the app pod stays healthy. Complete the web setup wizard on first visit.
