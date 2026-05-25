# homepage

Kubernetes manifests for [Homepage](https://github.com/gethomepage/homepage) on the xd-net cluster.

## Access

- Host: `net.ecksd.ee` (Gateway API via shared cluster Gateway)

## Configuration

Homepage reads config from `/app/config`. This app mounts a Git-managed `ConfigMap` (`homepage-config`).

To customize, edit `apps/homepage/configmap.yaml` keys:

- `settings.yaml`
- `bookmarks.yaml`
- `services.yaml` — manual tiles (Upcoming calendar, UniFi, Pangolin, DSM, external apps not on Gateway discovery)
- `widgets.yaml`

**Service order:** Homepage sorts by `weight` (lower first). Discovered apps use `gethomepage.dev/weight` on HTTPRoutes; manual entries in `services.yaml` can set `weight` too. The Arr! calendar uses `weight: 0`; keep Bazarr/Prowlarr/Flood above `0` (currently `10`/`20`/`30`).

**UniFi widget (optional)** — use the same local admin as UniFi Poller (`secrets/unpoller.yaml` / `unifipoller`) in `secrets/homepage-unifi-widget.yaml`, then SOPS-encrypt and sync **platform-secrets**. The tile is in `services.yaml` under **Management**.

**PeaNUT** — deployed in **`apps/peanut`**; Homepage tile and widget come from `httproute.yaml` (Management). Grafana dashboard in **`apps/monitoring`** (folder **Misc**).

**Pangolin widget (optional)** — create an Integration API key with **List Sites** and **List Resources**, set `HOMEPAGE_VAR_PANGOLIN_API_URL`, `HOMEPAGE_VAR_PANGOLIN_DASHBOARD_URL`, and `HOMEPAGE_VAR_PANGOLIN_ORG` in `secrets/homepage-pangolin-widget.yaml`, then SOPS-encrypt and sync **platform-secrets**. The tile is defined in `services.yaml` under **Management**.

**Management manual tiles** use weights `10` (UniFi), `35` (Pangolin), `45` (DSM). PeaNUT (`15`) and Authentik (`30`) / Grafana (`40`) use HTTPRoute `gethomepage.dev/weight` annotations.
