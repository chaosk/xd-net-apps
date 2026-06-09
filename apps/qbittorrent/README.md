# qBittorrent

BitTorrent client via bjw-s `app-template` and `ghcr.io/home-operations/qbittorrent`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS torrents, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (10Gi). |
| `nfs-torrents.yaml` | RWX NFS ingest at `/volume1/ingest/torrents` → `/data/torrents`. |
| `values.yaml` | Image, TCP probes on port 8080; config and torrents mounts. |
| `httproute.yaml` | `qbittorrent.net.ecksd.ee` via Gateway `shared`. |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik for this HTTPRoute. |

Forward auth needs **authentik** applied first (shared **ReferenceGrant** and outpost route). In Authentik, a **forward_single** **Proxy provider** on the **embedded outpost** sends HTTP Basic auth to qBittorrent (`qbittorrent_user` / `qbittorrent_password` on the **`*arr users`** group — same pattern as Sonarr). **Intercept header authentication** must be **off** so the `Authorization` header reaches qBittorrent. Those Authentik attributes must match the **existing** qBittorrent WebUI username/password (do not rotate the WebUI password unless you update the group attributes too). Requires qBittorrent **5.2+** (WebUI Basic auth behind a reverse proxy). See **`apps/authentik/README.md`** and [Authentik header authentication](https://docs.goauthentik.io/add-secure-apps/providers/proxy/header_authentication/).

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

**Argo CD Image Updater** tracks **`ghcr.io/home-operations/qbittorrent`** on the **`5.x`** line (`~5` in `apps/argocd-image-updater/image-updater.yaml`). Manual bump: **`controllers.main.containers.main.image.tag`** in `values.yaml`.
