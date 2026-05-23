# Monitoring

Prometheus, Grafana, and Loki for the xd-net cluster, installed with upstream Helm charts via Kustomize.

| Chart | Version | Role |
|-------|---------|------|
| [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) | 85.3.0 | Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics |
| [loki](https://github.com/grafana/loki/tree/main/production/helm/loki) | 7.0.0 | Log storage (SingleBinary, Synology PVC) |
| [alloy](https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy) | 1.8.1 | Pod log collection |
## Access

- **Grafana:** `https://grafana.net.ecksd.ee` (shared Gateway TLS covers `*.net.ecksd.ee`)
- **Prometheus / Alertmanager:** ClusterIP only (`kube-prometheus-stack-prometheus`, `kube-prometheus-stack-alertmanager` in `monitoring`). Use Grafana’s Prometheus datasource or port-forward for ad-hoc queries.

Grafana is pre-wired with a **Loki** datasource at `http://loki.monitoring.svc.cluster.local:3100`.

## Layout

| File | Purpose |
|------|---------|
| `namespace.yaml` | **`monitoring`** namespace; Pod Security **`privileged`** (node-exporter). |
| `kustomization.yaml` | Namespace, HTTPRoute, three Helm releases, dashboard ConfigMaps. |
| `values-prometheus.yaml` | Retention, Synology PVCs for Prometheus and Alertmanager, Grafana admin Secret reference. |
| `values-loki.yaml` | SingleBinary Loki on Synology PVC (Memcached caches disabled). |
| `values-alloy.yaml` | DaemonSet Alloy agents (`loki.source.kubernetes`) pushing to in-cluster Loki. |
| `httproute.yaml` | `grafana.net.ecksd.ee` → `kube-prometheus-stack-grafana:80`. |
| `scrape-cnpg.yaml` | PodMonitors for `authentik-db`, `immich-db`, `tracearr-db`, `bitmagnet-db`. |
| `scrape-apps.yaml` | Authentik server PodMonitor; Immich and Bitmagnet ServiceMonitors. |
| `scrape-platform.yaml` | Envoy Gateway controller + dataplane; Cilium agent ServiceMonitor. |
| `dashboards/` | CNPG, Cilium, and Envoy Grafana dashboards (ConfigMaps for sidecar). |

Custom `ServiceMonitor` / `PodMonitor` resources must carry label **`release: kube-prometheus-stack`** so the stack’s Prometheus picks them up (`serviceMonitorSelectorNilUsesHelmValues` is left at the chart default).

## Extra scrape targets

| Target | Monitor | Notes |
|--------|---------|--------|
| CNPG (`*-db`) | `scrape-cnpg.yaml` | Port `metrics` (9187) on cluster pods. |
| Authentik server | `scrape-apps.yaml` | `/metrics` on pod port `metrics` (9300), not the HTTP Service. |
| Immich server | `scrape-apps.yaml` | `/metrics` on Service port `http` (2283). |
| Bitmagnet | `scrape-apps.yaml` | `/metrics` on Service port `http` (3333). Postgres via `scrape-cnpg.yaml` (`bitmagnet-db`). |
| Envoy Gateway controller | `scrape-platform.yaml` | Service `envoy-gateway:19001/metrics`. |
| Envoy dataplane (`shared`) | `scrape-platform.yaml` | Pod port `metrics`, path `/stats/prometheus`. |
| Cilium agent | `scrape-platform.yaml` | Service `cilium-agent` port `metrics` in `kube-system`. |

Sonarr/Radarr expose `/metrics` only with app-side auth and are not scraped here.

## Grafana dashboards

kube-prometheus-stack ships the usual Kubernetes, node, and Prometheus dashboards. This app adds:

| Folder | Dashboard | Source | Metrics / logs |
|--------|-----------|--------|----------------|
| *(default)* | **CloudNativePG** | [Grafana 20417](https://grafana.com/grafana/dashboards/20417-cloudnativepg/) (`dashboards/cnpg.json`) | CNPG PodMonitors (`scrape-cnpg.yaml`) |
| **Platform** | **Cilium Agent Metrics** | [Grafana 16611](https://grafana.com/grafana/dashboards/16611-cilium-metrics/) | `cilium-agent` ServiceMonitor |
| **Platform** | **Envoy global** | [Grafana 7253](https://grafana.com/grafana/dashboards/7253-envoy-global/) | Envoy dataplane PodMonitor |

JSON dashboards live under `dashboards/`; Kustomize builds ConfigMaps with label **`grafana_dashboard=1`** for the Grafana sidecar. Datasource placeholders are rewritten to **`Prometheus`**.

Use **Explore → Loki** for log queries (`{namespace="homepage"}`, etc.).

Dashboard ConfigMaps use **`argocd.argoproj.io/sync-options: ServerSideApply=true`** so Argo CD does not store the full manifest in `last-applied-configuration` (that annotation has a 256KiB limit and breaks large boards like CloudNativePG and Cilium).

For CloudNativePG, use the **Namespace** and **Cluster** variables (for example `immich` / `immich-db`).

Generic Postgres dashboards (for example Grafana **9628**) target `postgres_exporter` and will not match CNPG.

The Cilium board (Grafana **16611**) originally filtered on in-metric label `k8s_app="cilium"`. Scrapes via ServiceMonitor expose `job`, `pod`, and `service` instead; `dashboards/cilium.json` drops that filter so panels match Prometheus.

## Prerequisites

1. **Secret `grafana-admin`** in namespace `monitoring` — see `secrets/grafana-admin.yaml`. Generate a password, add `# sops:encrypt` on `admin-password`, then `sops --encrypt --in-place secrets/grafana-admin.yaml` and sync **platform-secrets** before the stack can start.
2. **Metrics Server** — `apps/metrics-server` (for node/pod metrics in Grafana).
3. **Synology `storageClass`** — `synology` (same as other apps).
4. **Pod Security** — namespace uses **`privileged`** so `prometheus-node-exporter` can use host network, hostPath, and port 9100 (cluster default is baseline).

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/monitoring" --enable-helm | kubectl apply -f -
```

The prometheus-community chart installs **Prometheus Operator CRDs**. On first sync, Argo CD may need an extra pass or `ServerSideApply=true` if CRD ownership conflicts appear; re-sync after CRDs exist.

## Notes

- **No Authentik forward-auth** on Grafana in this manifest — login uses Grafana’s built-in admin user from `grafana-admin`. Add a `SecurityPolicy` + HTTPRoute outpost rule later if you want SSO on `grafana.net.ecksd.ee`.
- **Resource use:** Prometheus and Loki each request a **50Gi** RWO volume; adjust `values-*.yaml` if your NAS exports are smaller.
- **Homepage:** optional `gethomepage.dev/*` annotations on `httproute.yaml` can be added once the stack is up.
