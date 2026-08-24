# UniFi Poller

[UniFi Poller](https://unpoller.com/) exports UniFi controller metrics for Prometheus (port **9130**).

## Secrets

**`secrets/unpoller.yaml`** — UniFi API URL, local admin username, password (`unpoller-unifi` in namespace **`unpoller`**). SOPS-encrypt and sync **platform-secrets**.

UniFi local admin **`unifipoller`** (read-only) under **Settings → Admins → Local Access**. Controller URL: **`https://unifi.net.ecksd.ee`** (no `:8443` on UDM/UXG).

## Image updates

**Argo CD Image Updater** tracks `ghcr.io/unpoller/unpoller` in `apps/argocd-image-updater/image-updater.yaml`.

## Prometheus

**PodMonitor** labeled `release: kube-prometheus-stack` (`podmonitor-patch.yaml`).

Grafana dashboards **11311–11315** ship with **monitoring** under folder **UniFi** (`apps/monitoring/dashboards/unpoller-*.json`).

## Layout

| File | Purpose |
|------|---------|
| `values.yaml` | Helm chart: image, Prometheus listener |
| `deployment-patch.yaml` | `UP_UNIFI_DEFAULT_*` env from Secret `unpoller-unifi` |
| `podmonitor-patch.yaml` | Label PodMonitor for kube-prometheus-stack |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/unpoller" --enable-helm | kubectl apply -f -
```

Verify: `kubectl logs -n unpoller deploy/unpoller` and `kubectl port-forward -n unpoller deploy/unpoller 9130:9130` → `http://127.0.0.1:9130/metrics`.
