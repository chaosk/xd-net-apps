# homepage

Kubernetes manifests for [Homepage](https://github.com/gethomepage/homepage) on the xd-net cluster.

## Access

- Host: `net.ecksd.ee` (Gateway API via shared cluster Gateway)

## Configuration

Homepage reads config from `/app/config`. This app mounts a Git-managed `ConfigMap` (`homepage-config`).

To customize, edit `apps/homepage/configmap.yaml` keys:

- `settings.yaml`
- `bookmarks.yaml`
- `services.yaml` — manual tiles (Upcoming calendar, external apps not on Gateway discovery)
- `widgets.yaml`

**Service order:** Homepage sorts by `weight` (lower first). Discovered apps use `gethomepage.dev/weight` on HTTPRoutes; manual entries in `services.yaml` can set `weight` too. The Arr! calendar uses `weight: 0`; keep Bazarr/Prowlarr/Flood above `0` (currently `10`/`20`/`30`).
