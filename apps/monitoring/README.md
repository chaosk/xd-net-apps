# Monitoring

Prometheus, Grafana, and Loki for the xd-net cluster, installed with upstream Helm charts via Kustomize.

| Chart | Version | Role |
|-------|---------|------|
| [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) | 85.3.0 | Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics |
| [loki](https://github.com/grafana/loki/tree/main/production/helm/loki) | 7.0.0 | Log storage (SingleBinary, Synology PVC) |
| [alloy](https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy) | 1.8.1 | Pod log collection |

Chart versions are **not** managed by Argo CD Image Updater (that tracks container images, not Helm chart pins). Bump them deliberately — see **Chart upgrades** below.

## Access

- **Grafana:** `https://grafana.net.ecksd.ee` (shared Gateway TLS covers `*.net.ecksd.ee`)
- **Prometheus / Alertmanager:** ClusterIP only (`kube-prometheus-stack-prometheus`, `kube-prometheus-stack-alertmanager` in `monitoring`). Use Grafana’s Prometheus datasource or port-forward for ad-hoc queries.

Grafana is pre-wired with a **Loki** datasource at `http://loki.monitoring.svc.cluster.local:3100`.

## Layout

| File | Purpose |
|------|---------|
| `namespace.yaml` | **`monitoring`** namespace; Pod Security **`privileged`** (node-exporter). |
| `postgres.yaml` | CNPG cluster **`grafana-db`** (Grafana internal metadata on `local-path`). |
| `kustomization.yaml` | Namespace, HTTPRoute, three Helm releases, dashboard ConfigMaps. |
| `values-prometheus.yaml` | Retention, Synology PVCs for Prometheus and Alertmanager, Grafana Postgres + admin Secret, thin apiserver scrape, Alertmanager → Home Assistant routing. |
| `rules-cnpg.yaml` | Critical `PrometheusRule` for CNPG (`CNPGInstanceDown`, `CNPGClusterDown`). |
| `values-loki.yaml` | SingleBinary Loki on Synology PVC (Memcached caches disabled). |
| `values-alloy.yaml` | DaemonSet Alloy agents (`loki.source.kubernetes`) pushing to in-cluster Loki. |
| `httproute.yaml` | `grafana.net.ecksd.ee` → `kube-prometheus-stack-grafana:80`. |
| `scrape-cnpg.yaml` | PodMonitors for `authentik-db`, `immich-db`, `invidious-db`, `tracearr-db`, `bitmagnet-db`, `paperless-db`, `speedtest-tracker-db`, `miniflux-db`, `mealie-db`, `grafana-db`. |
| `scrape-apps.yaml` | Authentik server PodMonitor; Immich, Bitmagnet, and Speedtest Tracker ServiceMonitors. |
| `scrape-platform.yaml` | Envoy Gateway controller + dataplane; Cilium agent ServiceMonitor. |
| `dashboards/` | CNPG, Cilium, Envoy Gateway, Speedtest Tracker, PeaNUT, and UniFi Poller Grafana dashboards (ConfigMaps for sidecar). |

Custom `ServiceMonitor` / `PodMonitor` resources must carry label **`release: kube-prometheus-stack`** so the stack’s Prometheus picks them up (`serviceMonitorSelectorNilUsesHelmValues` is left at the chart default).

## Extra scrape targets

| Target | Monitor | Notes |
|--------|---------|--------|
| CNPG (`*-db`) | `scrape-cnpg.yaml` | Port `metrics` (9187) on cluster pods. |
| Authentik server | `scrape-apps.yaml` | `/metrics` on pod port `metrics` (9300), not the HTTP Service. |
| Immich server | `scrape-apps.yaml` | `/metrics` on Service ports `metrics-api` (8081) and `metrics-ms` (8082); requires `immich.metrics.enabled: true` in `apps/immich/values.yaml`. |
| Bitmagnet | `scrape-apps.yaml` | `/metrics` on Service port `http` (3333). Postgres via `scrape-cnpg.yaml` (`bitmagnet-db`). |
| Speedtest Tracker | `scrape-apps.yaml` | `/prometheus` on Service port `http` (80), interval 5m. Enable in app **Settings → Data platforms → Prometheus** ([docs](https://docs.speedtest-tracker.dev/settings/data-platforms/prometheus)); allow cluster scrape sources (e.g. `10.0.0.0/8`). Postgres via `scrape-cnpg.yaml` (`speedtest-tracker-db`). |
| Envoy Gateway controller | `scrape-platform.yaml` | Service `envoy-gateway:19001/metrics`. |
| Envoy dataplane (`shared`) | `scrape-platform.yaml` | Pod port `metrics`, path `/stats/prometheus`. |
| Cilium agent | `scrape-platform.yaml` | Service `cilium-agent` port `metrics` in `kube-system`. |
| UniFi Poller | `apps/unpoller` PodMonitor | Pod port `tcp` (9130), path `/metrics` (default). Requires `secrets/unpoller.yaml`. |
| PeaNUT | `apps/peanut` ServiceMonitor | `/api/v1/metrics` on Service `peanut:8080`. Enable Prometheus in PeaNUT UI; Synology NUT must allow the pod IP. |

Sonarr/Radarr expose `/metrics` only with app-side auth and are not scraped here.

## Grafana dashboards

kube-prometheus-stack ships the usual Kubernetes, node, and Prometheus dashboards. This app adds:

| Folder | Dashboard | Source | Metrics / logs |
|--------|-----------|--------|----------------|
| *(default)* | **CloudNativePG** | [Grafana 20417](https://grafana.com/grafana/dashboards/20417-cloudnativepg/) (`dashboards/cnpg.json`) | CNPG PodMonitors (`scrape-cnpg.yaml`) |
| **Platform** | **Cilium Agent Metrics** | [Grafana 16611](https://grafana.com/grafana/dashboards/16611-cilium-metrics/) | `cilium-agent` ServiceMonitor |
| **Platform** | **Envoy Gateway Global** | [envoy-gateway-global.json](https://github.com/envoyproxy/gateway/blob/main/charts/gateway-addons-helm/dashboards/envoy-gateway-global.json) | Envoy Gateway controller (`scrape-platform.yaml`) |
| **Platform** | **Envoy Global** | [envoy-proxy-global.json](https://github.com/envoyproxy/gateway/blob/main/charts/gateway-addons-helm/dashboards/envoy-proxy-global.json) | Shared Gateway dataplane PodMonitor |
| **Platform** | **Envoy Clusters** | [envoy-clusters.json](https://github.com/envoyproxy/gateway/blob/main/charts/gateway-addons-helm/dashboards/envoy-clusters.json) | Per-route upstream cluster stats from the dataplane |
| **Platform** | **Resources Monitor** | [resources-monitor.gen.json](https://github.com/envoyproxy/gateway/blob/main/charts/gateway-addons-helm/dashboards/resources-monitor.gen.json) | Controller and dataplane CPU/memory (`container_*` metrics) |

JSON dashboards live under `dashboards/`; Kustomize builds ConfigMaps with label **`grafana_dashboard=1`** for the Grafana sidecar. Datasource placeholders are rewritten to **`Prometheus`**.

Use **Explore → Loki** for log queries (`{namespace="homepage"}`, etc.). Apps that log to files only (for example **Plex**) need a sidecar so lines reach container stdout; Plex uses `{namespace="plex", container="log-tailer"}` with timestamp and **`level`** parsing in `values-alloy.yaml`.

Dashboard ConfigMaps use **`argocd.argoproj.io/sync-options: ServerSideApply=true`** so Argo CD does not store the full manifest in `last-applied-configuration` (that annotation has a 256KiB limit and breaks large boards like CloudNativePG and Cilium).

For CloudNativePG, use the **Namespace** and **Cluster** variables (for example `immich` / `immich-db`).

Generic Postgres dashboards (for example Grafana **9628**) target `postgres_exporter` and will not match CNPG.

The Cilium board (Grafana **16611**) originally filtered on in-metric label `k8s_app="cilium"`. Scrapes via ServiceMonitor expose `job`, `pod`, and `service` instead; `dashboards/cilium.json` drops that filter so panels match Prometheus.

Envoy Gateway addon dashboards live under `dashboards/` with upstream filenames (except `envoy-resources-monitor.json`, from `resources-monitor.gen.json`). **Global Ratelimit** is omitted because no ratelimit service is deployed.

| **Misc** | **Speedtest Tracker** | [CrazyWolf13/Speedtest-Tracker-Prometheus](https://github.com/CrazyWolf13/Speedtest-Tracker-Prometheus) (`dashboards/speedtest-tracker.json`; [Grafana 24608](https://grafana.com/grafana/dashboards/24608-speedtest-tracker/)) | Speedtest Tracker `/prometheus` (`scrape-apps.yaml`) |
| **Misc** | **PeaNUT** | Prometheus adaptation of [zephyr325/Grafana-for-PeaNUT](https://github.com/zephyr325/Grafana-for-PeaNUT) (`dashboards/peanut.json`; numeric NUT metrics only—no Influx outage/status panels) | `apps/peanut` ServiceMonitor (`/api/v1/metrics`) |
| **UniFi** | **Network Sites** | [Grafana 11311](https://grafana.com/grafana/dashboards/11311-unifi-poller-network-sites-prometheus/) (`unpoller-network-sites.json`) | UniFi Poller (`apps/unpoller` PodMonitor) |
| **UniFi** | **USW Insights** | [Grafana 11312](https://grafana.com/grafana/dashboards/11312-unifi-poller-usw-insights-prometheus/) (`unpoller-usw-insights.json`) | UniFi Poller |
| **UniFi** | **USG Insights** | [Grafana 11313](https://grafana.com/grafana/dashboards/11313-unifi-poller-usg-insights-prometheus/) (`unpoller-usg-insights.json`) | UniFi Poller |
| **UniFi** | **UAP Insights** | [Grafana 11314](https://grafana.com/grafana/dashboards/11314-unifi-poller-uap-insights-prometheus/) (`unpoller-uap-insights.json`) | UniFi Poller |
| **UniFi** | **Client Insights** | [Grafana 11315](https://grafana.com/grafana/dashboards/11315-unifi-poller-client-insights-prometheus/) (`unpoller-client-insights.json`) | UniFi Poller |

## Prerequisites

1. **Secret `grafana-admin`** in namespace `monitoring` — see `secrets/grafana-admin.yaml`. Generate a password, add `# sops:encrypt` on `admin-password`, then `sops --encrypt --in-place secrets/grafana-admin.yaml` and sync **platform-secrets** before the stack can start. Keeps break-glass local login when OAuth auto-login is enabled.
2. **Secret `grafana-db`** in namespace `monitoring` — CNPG bootstrap for `postgres.yaml` (`username`, `password`; owner/database `grafana`). See `secrets/grafana-db.yaml`. Encrypt with SOPS and sync **platform-secrets** before the **`grafana-db`** cluster and Grafana pod start.
3. **Secret `grafana-oidc`** in namespace `monitoring` — Authentik OAuth2 client credentials (`client_id`, `client_secret`) for Generic OAuth. See `secrets/grafana-oidc.yaml`. Provider slug **`grafana`**, redirect URI **`https://grafana.net.ecksd.ee/login/generic_oauth`**. Encrypt with SOPS and sync **platform-secrets** before enabling OAuth in `values-prometheus.yaml`.
4. **Secret `alertmanager-ha`** in namespace `monitoring` — Home Assistant webhook URL for Alertmanager (`url`). See `secrets/alertmanager-ha.yaml` and **Alerting** below. Sync **platform-secrets** before Alertmanager can notify.
5. **Metrics Server** — `apps/metrics-server` (for node/pod metrics in Grafana).
6. **Synology `storageClass`** — `synology` (same as other apps).
7. **Pod Security** — namespace uses **`privileged`** so `prometheus-node-exporter` can use host network, hostPath, and port 9100 (cluster default is baseline).

## Alerting

Alertmanager is enabled. The default receiver is **`null`** (no outbound notify). A whitelist route sends a small critical set to **Home Assistant** via webhook; everything else stays in-cluster (Grafana / Alertmanager UI).

### What pages the phone

| Alert | Source | Role |
|-------|--------|------|
| **KubeNodeNotReady**, **KubeNodeUnreachable**, **KubeAPIDown** | chart defaults | Node / API failure |
| **KubePersistentVolumeFillingUp**, **KubePersistentVolumeInodesFillingUp**, **NodeFilesystemSpaceFillingUp**, **NodeFilesystemAlmostOutOfSpace** | chart defaults | PVC / node disk pressure |
| **CNPGInstanceDown**, **CNPGClusterDown** | `rules-cnpg.yaml` | CloudNativePG instance or whole cluster not up |

**Watchdog** stays on receiver **`null`** (always-firing heartbeat; do not page the phone). Warnings (CrashLoop, TargetDown on optional scrapes, CPU/memory, etc.) also stay on **`null`**.

In the Alertmanager UI, **`null` is a real receiver name** (the default sink), not “unconfigured.” Most firing alerts show `null` on purpose. Whitelist names only appear under **`home-assistant`** while they are actively firing (they are quiet when the cluster is healthy).

### Home Assistant setup

1. Sync **platform-secrets** so Secret **`alertmanager-ha`** exists (`url` points at `http://home-assistant.home-assistant.svc.cluster.local:8123/api/webhook/<webhook_id>`).
2. In HA, create an automation with a **Webhook** trigger. Use the same `webhook_id` as in the secret (default in repo: **`xdnet_alertmanager_9559984c05d4cb89fbb23a98f4d019f1`**). Prefer **`local_only: true`** so only in-cluster / LAN callers can fire it.
3. Action: call your companion notify service (replace the entity id):

```yaml
alias: Alertmanager → mobile
description: Critical xd-net alerts from Prometheus Alertmanager
trigger:
  - platform: webhook
    webhook_id: xdnet_alertmanager_9559984c05d4cb89fbb23a98f4d019f1
    allowed_methods:
      - POST
    local_only: true
action:
  - service: notify.mobile_app_YOUR_DEVICE
    data:
      title: >-
        {% if trigger.json.status == 'resolved' %}Resolved{% else %}Alert{% endif %}
        {{ trigger.json.commonLabels.alertname | default('Alertmanager') }}
      message: >-
        {% for a in trigger.json.alerts -%}
        {{ a.annotations.summary | default(a.labels.alertname) }}
        {% if not loop.last %} · {% endif %}
        {%- endfor %}
mode: queued
```

Find the notify entity under **Developer tools → Actions** (`notify.mobile_app_*`). To rotate the webhook id: `sops secrets/alertmanager-ha.yaml`, update the URL path, sync **platform-secrets**, and match the automation.

### Silences

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
# open http://localhost:9093/#/silences
```

Create a silence with matchers (for example `alertname=KubeAPIDown` during maintenance). Silences persist on the Alertmanager PVC.

### Secrets

| File | Secret | Keys |
|------|--------|------|
| `secrets/alertmanager-ha.yaml` | `alertmanager-ha` | `url` (full webhook URL; `# sops:encrypt`) |

Alertmanager mounts that Secret at `/etc/alertmanager/secrets/alertmanager-ha/` and reads `url` via `url_file` in `values-prometheus.yaml`.

## Chart upgrades

Pins live in `kustomization.yaml` under `helmCharts[].version` (and the version table at the top of this README). Fetched chart tarballs land under `apps/monitoring/charts/` and are gitignored — do not vendor them.

1. Pick a target chart version from upstream release notes:
   - [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/releases?q=kube-prometheus-stack)
   - [loki](https://github.com/grafana/loki/releases?q=helm-loki)
   - [alloy](https://github.com/grafana/alloy/releases?q=helm-chart)
2. Set the matching `helmCharts[].version` in `kustomization.yaml` and update the version table above.
3. Diff values against the new chart defaults (breaking renames are common on kube-prometheus-stack major/minor bumps):

   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo add grafana https://grafana.github.io/helm-charts
   helm repo update
   helm show values prometheus-community/kube-prometheus-stack --version <new> > /tmp/kps-values.yaml
   # likewise: grafana/loki --version <new>, grafana/alloy --version <new>
   diff -u values-prometheus.yaml /tmp/kps-values.yaml   # review; do not overwrite our values wholesale
   ```

4. Render and review the full manifest before syncing:

   ```bash
   kubectl kustomize "$HOME/Projects/xd-net-apps/apps/monitoring" --enable-helm > /tmp/monitoring-render.yaml
   ```

5. Commit the pin + any `values-*.yaml` / `patchesJson6902` adjustments, then sync the **monitoring** Argo CD Application (or apply as below). Watch Prometheus Operator CRD upgrades and Grafana rollout; re-apply `patchesJson6902` hostNetwork strips if the chart reintroduces those fields.

Bump one chart at a time when possible so a bad render is easy to bisect.

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/monitoring" --enable-helm | kubectl apply -f -
```

The prometheus-community chart installs **Prometheus Operator CRDs**. On first sync, Argo CD may need an extra pass or `ServerSideApply=true` if CRD ownership conflicts appear; re-sync after CRDs exist.

## Notes

- **Apiserver metrics:** `values-prometheus.yaml` scrapes the API server every **60s** and drops histogram buckets, SLI/SLO series, and high-cardinality labels (`resource`, `subresource`, etc.) to cut control-plane and Prometheus load. Bundled **API server SLO** dashboards and recording rules are disabled; **`KubeAPIDown`** and other coarse `kubernetesSystem` alerts remain. Restore chart defaults temporarily when debugging apiserver latency.
- **Grafana database:** Internal state (users, preferences, secure values) uses **PostgreSQL** via CNPG (`grafana-db`).
- **Authentik login:** Generic OAuth in `values-prometheus.yaml` ([integration guide](https://integrations.goauthentik.io/monitoring/grafana/)). Authentik groups **`Grafana Admins`** / **`Grafana Editors`** map to Grafana **Admin** / **Editor**; everyone else gets **Viewer** (`auto_assign_org_role`). Use a custom **`profile`** scope mapping without embedded groups plus a filtered **`groups`** scope (same pattern as Argo CD in `apps/authentik/README.md`).
- **Resource use:** Prometheus and Loki each use a **50Gi** RWO volume on StorageClass **`synology`** (`values-*.yaml`).
