# UniFi Poller

Deploys [UniFi Poller](https://unpoller.com/) to export UniFi controller metrics for Prometheus (port **9130**).

## Before sync

1. **Secret `unpoller-unifi`** in namespace **`unpoller`** — UniFi API URL, local admin username, and password (`secrets/unpoller.yaml`). Encrypt with **SOPS** and sync **platform-secrets** ([`secrets/README.md`](../../secrets/README.md)).

2. **UniFi local admin** — create a dedicated local user (for example `unifipoller`) under **Settings → Admins → Local Access** with read-only access to the sites you want polled.

3. **Controller URL** — for UDM Pro / UXG / recent Cloud Keys use `https://<ip>` **without** `:8443`. Legacy controllers may need `https://<ip>:8443`.

## Image updates

**Argo CD Image Updater** tracks `ghcr.io/unpoller/unpoller` (`~v3`, semver) and writes bumps to `values.yaml` (`image.repository` / `image.tag`). See `apps/argocd-image-updater/image-updater.yaml`.

## Prometheus

The chart creates a **PodMonitor** labeled `release: kube-prometheus-stack` (see `podmonitor-patch.yaml`). Metrics appear in Prometheus/Grafana after sync.

Grafana dashboards from the [UniFi Poller org](https://grafana.com/orgs/unpoller/dashboards) (IDs **11311–11315**) ship with **monitoring** under folder **UniFi** (`apps/monitoring/dashboards/unpoller-*.json`). Chart-managed Grafana Operator dashboards stay disabled in `values.yaml`.

## Layout

| File | Purpose |
|------|---------|
| `values.yaml` | Helm chart: image, Prometheus listener, no Grafana Operator dashboards |
| `deployment-patch.yaml` | `UP_UNIFI_DEFAULT_*` env from Secret `unpoller-unifi` |
| `podmonitor-patch.yaml` | Label PodMonitor for kube-prometheus-stack |

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/unpoller" --enable-helm | kubectl apply -f -
```

Verify: `kubectl logs -n unpoller deploy/unpoller` and `kubectl port-forward -n unpoller deploy/unpoller 9130:9130` then open `http://127.0.0.1:9130/metrics`.
