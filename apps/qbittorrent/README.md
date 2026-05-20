# qBittorrent

BitTorrent client via bjw-s `app-template` and `ghcr.io/home-operations/qbittorrent`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS torrents, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (10Gi). |
| `nfs-torrents.yaml` | RWX NFS ingest at `/volume1/ingest/torrents` → `/data/torrents`. |
| `values.yaml` | Image, TCP probes on port 8080; config and torrents mounts. |
| `httproute.yaml` | `qbittorrent.net.ecksd.ee` via Gateway `shared`. |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/qbittorrent" --enable-helm | kubectl apply -f -
```

Set the default save path to `/data/torrents` (or a subfolder). Sonarr/Radarr use the same ingest export for completed downloads.

## VPN egress

Torrent traffic is routed through **[pod-gateway](../vpn-gateway/README.md)** + Gluetun:

- Namespace uses **`pod-security.kubernetes.io/enforce: privileged`** (pod-gateway requires `NET_ADMIN` / `NET_RAW`)
- Namespace label **`allows-vpn-gateway: "true"`** (`namespace.yaml`)
- Pod label **`vpn-gateway: "true"`** (`values.yaml` → `defaultPodOptions.labels`)
- **`qbittorrent`** listed under **`routed_namespaces`** in `apps/vpn-gateway/values-pod-gateway.yaml`

Apply order: **vpn-gateway** (if `routed_namespaces` changed), then recreate the qBittorrent pod. Verify:

```bash
kubectl exec -n qbittorrent deploy/qbittorrent -c main -- curl -4 -sS --max-time 15 https://api.ipify.org
```

Sonarr/Radarr stay off the VPN; they reach qBittorrent via the cluster Service as usual.

Pin the image `tag` in `values.yaml` when upgrading.
