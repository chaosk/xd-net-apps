# Radarr

Movie automation ([Radarr](https://radarr.video/)) via bjw-s `app-template` and `ghcr.io/home-operations/radarr`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS media, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (5Gi). |
| `nfs-media.yaml` | RWX NFS library (same export as Plex). |
| `values.yaml` | Image, probes, mounts at `/config` and `/data/media`. |
| `httproute.yaml` | `radarr.net.ecksd.ee` via Gateway `shared`; Homepage **radarr** widget (API key in `secrets/homepage-radarr-widget.yaml`). |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/radarr" --enable-helm | kubectl apply -f -
```

Set root folders under `/data/media` (for example `/data/media/Movies`). Pin the image `tag` in `values.yaml` when upgrading.
