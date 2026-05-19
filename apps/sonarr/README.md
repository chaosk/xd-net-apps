# Sonarr

TV automation ([Sonarr](https://sonarr.tv/)) via [bjw-s app-template](https://bjw-s-labs.github.io/helm-charts/docs/app-template/) and `ghcr.io/home-operations/sonarr`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS media, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (5Gi). |
| `nfs-media.yaml` | RWX NFS library (same export as Plex). |
| `values.yaml` | Container image, probes, mounts at `/config` and `/data/media`. |
| `httproute.yaml` | `sonarr.net.ecksd.ee` via Gateway `shared`; Homepage **sonarr** widget (API key in `secrets/homepage-sonarr-widget.yaml`). |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/sonarr" --enable-helm | kubectl apply -f -
```

Set root folders in Sonarr to paths under `/data/media` (for example `/data/media/TV`). Pin the image `tag` in `values.yaml` when upgrading.
