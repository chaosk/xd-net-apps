# homepage

[Homepage](https://github.com/gethomepage/homepage) dashboard for the xd-net cluster. Served at **https://net.ecksd.ee** on the shared Gateway (`gateway/shared`, HTTPS).

## Apply

```bash
kubectl apply -k apps/homepage
```

Widget API keys and credentials live in `secrets/homepage-*.yaml`. SOPS-encrypt each file, add it to the **platform-secrets** Application in xd-net, and sync. The Deployment maps those Secrets to `HOMEPAGE_VAR_*` environment variables.

## Config

All YAML is in the `homepage-config` ConfigMap (`configmap.yaml`), mounted at `/app/config`.

| Key | Role |
|-----|------|
| `settings.yaml` | Title, layout groups, favicon path, UI options |
| `services.yaml` | Tiles not discovered from the cluster (see below) |
| `widgets.yaml` | Header logo and Kubernetes cluster/node widgets |
| `kubernetes.yaml` | In-cluster mode; Gateway API HTTPRoute discovery enabled |
| `custom.css` | Logo widget sizing (`logo.png` is a wide banner) |

`bookmarks.yaml`, `docker.yaml`, and `proxmox.yaml` are empty placeholders.

Favicon and logo are in `images/`. Kustomize packs them into the `homepage-images` ConfigMap, mounted at `/app/public/images`. Paths in config: `settings.yaml` → `/images/favicon.png`, `widgets.yaml` → `/images/logo.png`.

## Service tiles

Most tiles come from **Gateway API HTTPRoutes** annotated with `gethomepage.dev/*`. Homepage discovers them via `kubernetes.yaml` (`gateway: true`). Each app’s `httproute.yaml` (or Helm values) sets group, weight, icon, href, and widget fields.

Tiles defined manually in `services.yaml` because they are external or not on a discovered route:

| Tile | Group | Weight | Widget | Credentials |
|------|-------|--------|--------|-------------|
| UniFi | Management | 10 | UniFi controller | `secrets/homepage-unifi-widget.yaml` — same local admin as UniFi Poller (`secrets/unpoller.yaml`) |
| Pangolin | Management | 35 | Pangolin Integration API | `secrets/homepage-pangolin-widget.yaml` — List Sites, List Resources |
| DSM | Management | 45 | Disk Station (`volume_1`) | `secrets/homepage-dsm-widget.yaml` |
| Garage | Data storage | 5 | — | — (Web UI at `garage.nas.net.ecksd.ee`; status via unauthenticated S3 endpoint `s3.nas.net.ecksd.ee`) |

The **Arr!** group includes an **Upcoming** calendar tile (`weight: -1`) backed by the Sonarr integration in `services.yaml`.

**Argo CD** is not in this repo. Its tile and widget are on the Argo CD HTTPRoute in **xd-net** (`apps/argocd-route.tf`). The API token is in `secrets/homepage-argocd-widget.yaml` (`HOMEPAGE_VAR_ARGOCD_API_KEY`), generated for the local `homepage` account (`apiKey`, `role:readonly`).

Discovered apps reference widget secrets through `{{HOMEPAGE_VAR_*}}` placeholders on their HTTPRoutes; the Deployment supplies the matching env vars.

## Groups and sort order

Homepage sorts tiles by `weight` (lower first). Layout groups are in `settings.yaml`: **Media**, **Arr!**, **Management**, **Data storage**, **Misc**.

**Management** (manual + discovered):

| Weight | Tile | Source |
|--------|------|--------|
| 10 | UniFi | `services.yaml` |
| 15 | PeaNUT | `apps/peanut/httproute.yaml` |
| 25 | Argo CD | xd-net `argocd-route.tf` |
| 30 | Authentik | `apps/authentik/values.yaml` |
| 35 | Pangolin | `services.yaml` |
| 40 | Grafana | `apps/monitoring/httproute.yaml` |
| 45 | DSM | `services.yaml` |

**Arr!** app weights: Bazarr `10`, Prowlarr `20`, Flood/qBittorrent `30`, Invidious `40`. The calendar tile stays at `-1` (below the apps).

**Media**: Plex `0`, Sonarr `10`, Radarr `20`.

**Data storage**: Garage `5` (manual), Paperless `10`, Immich `20`, Actual Budget `30`, Tube Archivist `30`.

**Misc**: Tracearr `0`, Speedtest Tracker `20`, Miniflux `30`, Home Assistant `30`, Bambuddy `35`, Spoolman `36`, Mealie `40`, Bitmagnet `100`.

## Runtime

Image tag is set in `kustomization.yaml` and updated by Argo CD Image Updater.

`HOMEPAGE_ALLOWED_HOSTS=net.ecksd.ee`. `HOMEPAGE_PROXY_DISABLE_IPV6=true` avoids IPv6 timeout on dual-stack Talos nodes during widget proxy calls.

The ServiceAccount has RBAC to read cluster state for the Kubernetes widget and HTTPRoute discovery.
