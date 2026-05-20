# qBittorrent

BitTorrent client via bjw-s `app-template` and `ghcr.io/home-operations/qbittorrent`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS volumes, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (10Gi). |
| `nfs-media.yaml` | RWX NFS library (same export as Plex) → `/data/media`. |
| `nfs-torrents.yaml` | RWX NFS ingest at `/volume1/ingest/torrents` → `/data/torrents`. |
| `values.yaml` | Image, TCP probes on port 8080; config, media, and torrents mounts. |
| `httproute.yaml` | `qbittorrent.net.ecksd.ee` via Gateway `shared`. |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/qbittorrent" --enable-helm | kubectl apply -f -
```

Set the default save path to `/data/torrents` (or a subfolder). Use `/data/media` only if you relocate completed files there for Sonarr/Radarr.

## VPN egress

Torrent traffic is routed through **[pod-gateway](../vpn-gateway/README.md)** + Gluetun:

- Namespace label **`allows-vpn-gateway: "true"`** (`namespace.yaml`)
- Pod label **`vpn-gateway: "true"`** (`values.yaml` → `defaultPodOptions.labels`)
- **`qbittorrent`** listed under **`routed_namespaces`** in `apps/vpn-gateway/values-pod-gateway.yaml`

Apply order: **vpn-gateway** (if `routed_namespaces` changed), then recreate the qBittorrent pod. Verify:

```bash
kubectl exec -n qbittorrent deploy/qbittorrent -c main -- curl -4 -sS --max-time 15 https://api.ipify.org
```

Sonarr/Radarr stay off the VPN; they reach qBittorrent via the cluster Service as usual.

Pin the image `tag` in `values.yaml` when upgrading.
