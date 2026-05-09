# homepage

Kubernetes manifests for [Homepage](https://github.com/gethomepage/homepage) on the xd-net cluster.

## Access

- Host: `net.ecksd.ee` (Gateway API via shared cluster Gateway)

## Configuration

Homepage reads config from `/app/config`. This app mounts a Git-managed `ConfigMap` (`homepage-config`).

To customize, edit `apps/homepage/configmap.yaml` keys:

- `settings.yaml`
- `bookmarks.yaml`
- `services.yaml`
- `widgets.yaml`

