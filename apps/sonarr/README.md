# Sonarr

TV automation ([Sonarr](https://sonarr.tv/)) via [bjw-s app-template](https://bjw-s-labs.github.io/helm-charts/docs/app-template/) and `ghcr.io/home-operations/sonarr`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS volumes, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (5Gi). |
| `nfs-media.yaml` | RWX NFS library (same export as Plex). |
| `nfs-torrents.yaml` | RWX NFS ingest at `/volume1/ingest/torrents` → `/data/torrents`. |
| `values.yaml` | Container image, probes, mounts at `/config`, `/data/media`, and `/data/torrents`. |
| `httproute.yaml` | `sonarr.net.ecksd.ee` via Gateway `shared`; Homepage **sonarr** widget (API key in `secrets/homepage-sonarr-widget.yaml`). |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik for this HTTPRoute. |

Forward auth needs **authentik** applied first (shared **ReferenceGrant** and outpost route). In Authentik, use a **domain-level** forward-auth **Proxy provider** on the **embedded outpost** (see **`apps/authentik/README.md`**).

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/sonarr" --enable-helm | kubectl apply -f -
```

Set root folders under `/data/media` (for example `/data/media/TV`). Point the download client at `/data/torrents`. Pin the image `tag` in `values.yaml` when upgrading.
