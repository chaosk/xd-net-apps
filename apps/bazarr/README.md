# Bazarr

Subtitle management ([Bazarr](https://www.bazarr.media/)) via bjw-s `app-template` and `ghcr.io/home-operations/bazarr`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS media, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (5Gi). |
| `nfs-media.yaml` | RWX NFS library (same export as Plex). |
| `values.yaml` | Image, health checks, mounts at `/config` and `/data/media`. |
| `httproute.yaml` | `bazarr.net.ecksd.ee` via Gateway `shared`. |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/bazarr" --enable-helm | kubectl apply -f -
```

Link Sonarr and Radarr in the Bazarr UI after install. Pin the image `tag` in `values.yaml` when upgrading.
