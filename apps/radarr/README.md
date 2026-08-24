# Radarr

Movie automation ([Radarr](https://radarr.video/)) via bjw-s `app-template` and `ghcr.io/home-operations/radarr`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS volumes, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (5Gi). |
| `nfs-media.yaml` | RWX NFS library (same export as Plex). |
| `nfs-torrents.yaml` | RWX NFS ingest at `/volume1/ingest/torrents` → `/data/torrents`. |
| `values.yaml` | Image, probes, mounts at `/config`, `/data/media`, and `/data/torrents`. |
| `httproute.yaml` | `radarr.net.ecksd.ee` via Gateway `shared`; Homepage **radarr** widget (API key in `secrets/homepage-radarr-widget.yaml`). |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik for this HTTPRoute. |

Forward auth needs **authentik** applied first (shared **ReferenceGrant** and outpost route). See **`apps/authentik/README.md`**.

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/radarr" --enable-helm | kubectl apply -f -
```

Set root folders under `/data/media` (for example `/data/media/Movies`). Point the download client at `/data/torrents`.

**Argo CD Image Updater** tracks `ghcr.io/home-operations/radarr` in `apps/argocd-image-updater/image-updater.yaml`.
