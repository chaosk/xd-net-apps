# Plex

[Plex Media Server](https://www.plex.tv/) via the upstream **plex-media-server** Helm chart ([pms-docker](https://github.com/plexinc/pms-docker)). Intel Quick Sync transcoding uses **`gpu.intel.com/i915`** and **`nodeSelector`** `intel.feature.node.kubernetes.io/gpu` (Intel device plugin on xd-net GPU nodes).

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, PVC, NFS media, LAN LoadBalancer, Pangolin route, Helm chart |
| `pvc.yaml` | **`plex-config`** on StorageClass `synology` (20Gi, RWO) |
| `nfs-media.yaml` | NFS PV/claim **`plex-media`** (RWX) — `nas.net.ecksd.ee`, path `/volume1/malachit/media/` → `/media` |
| `values.yaml` | **`plex.net.ecksd.ee`** on Gateway `shared`, Homepage + Tracearr widget, GPU, Tube Archivist init |
| `service-lan.yaml` | **`plex-lan`** LoadBalancer **`192.168.4.202:32400`**, `externalTrafficPolicy: Local` |
| `tubearchivist-plex-install.yaml` | Installs [tubearchivist-plex](https://github.com/tubearchivist/tubearchivist-plex) on the config PVC |
| `httproute-pangolin.yaml` | **`plex.ecksd.ee`** via Pangolin (`site-ref: xd-net`); homelab HTTPS stays on `plex.net.ecksd.ee` |

LAN clients use **`plex-lan`** directly on port **32400** (Plex ignores private **`X-Forwarded-For`**). **`ADVERTISE_IP`** publishes that URL alongside HTTPS hostnames. The LB IP comes from the xd-net Cilium pool (`gateway-lb-pool`, **`apps-l2-announce`** policy).

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/plex" --enable-helm | kubectl apply -f -
```

After install: add libraries under **`/media`**, enable hardware transcoding in **Settings → Transcoder** when the GPU path is working.

## Tube Archivist Plex integration

The init container installs tubearchivist-plex on the config volume and writes **`ta_config.json`** with in-cluster Tube Archivist URL **`http://tubearchivist.tubearchivist.svc.cluster.local:8000`** and API token from **`secrets/plex-tubearchivist-plex.yaml`** (same token as **`homepage-tubearchivist-widget`**).

Add a **TV Shows** library at **`/media/youtube`**. In **Manage Library → Edit → Advanced**, set **Scanner** to **TubeArchivist Scanner** and **Agent** to **TubeArchivist Agent**. Roll the StatefulSet after upgrading the integration script version in **`tubearchivist-plex-install.yaml`**.

## Logs in Grafana (Loki)

Plex logs to **`Plex Media Server.log`** on the config volume. A **`log-tailer`** sidecar forwards lines to Loki via Alloy. Query **`{namespace="plex", container="log-tailer"}`** or filter by **`level="ERROR"`**.

## Upgrades

**Argo CD Image Updater** tracks `docker.io/plexinc/pms-docker` in `apps/argocd-image-updater/image-updater.yaml`.

Helm chart version is pinned in **`kustomization.yaml`** (`helmCharts.version`); bump manually when the upstream chart changes.
