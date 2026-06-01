# PeaNUT

In-cluster [PeaNUT](https://github.com/Brandawg93/PeaNUT) UI that talks to **Synology’s network UPS server** (NUT on `nas.net.ecksd.ee:3493`). Prometheus scrapes PeaNUT’s `/api/v1/metrics`; Grafana dashboard is in **`apps/monitoring`** (folder **Misc**), adapted from [Grafana-for-PeaNUT](https://github.com/zephyr325/Grafana-for-PeaNUT) for Prometheus (overview, trends, power estimate; use Influx + upstream dashboard for outage history).

## Prerequisites (Synology)

1. UPS on **USB** to the NAS.
2. **Control Panel → Hardware & Power → UPS** — enable UPS support and **Enable network UPS server**.
3. **Permitted Synology NAS devices** — allow the **peanut** pod IP (or pod CIDR). See [PeaNUT #257](https://github.com/Brandawg93/PeaNUT/issues/257).
4. NUT username/password from the NAS (`/usr/syno/etc/ups/upsd.users` over SSH).

## Before sync

1. **`secrets/peanut.yaml`** — set `USERNAME` / `PASSWORD` in `settings.yml` to match Synology NUT, then SOPS-encrypt and sync **platform-secrets** ([`secrets/README.md`](../../secrets/README.md)).
2. After first sync, in PeaNUT **Settings** enable **Prometheus** and allow in-cluster scrapes (e.g. `10.0.0.0/8`).

## Access

- UI: `https://peanut.net.ecksd.ee` (Gateway `shared`)
- Homepage: discovered via `httproute.yaml` annotations (Management group)

## Image updates

**Argo CD Image Updater** tracks `docker.io/brandawg93/peanut` (`~6`, semver `X.Y.Z` tags) and writes bumps to `values.yaml`. See `apps/argocd-image-updater/image-updater.yaml`.

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, PVC, Helm `app-template`, HTTPRoute, ServiceMonitor |
| `values.yaml` | `docker.io/brandawg93/peanut:6.0.0`, PVC `/config`, init seeds `settings.yml` from Secret |
| `pvc.yaml` | `peanut-config` on `synology` (UI + Prometheus settings) |
| `httproute.yaml` | `peanut.net.ecksd.ee` + Homepage widget |
| `servicemonitor.yaml` | `/api/v1/metrics` for kube-prometheus-stack |

## Apply (local test)

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/peanut" --enable-helm | kubectl apply -f -
```

Verify NUT: `kubectl logs -n peanut deploy/peanut -c main` and open the UI. Verify metrics: Prometheus target `peanut` or Grafana **Misc → PeaNUT**.
