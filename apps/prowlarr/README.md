# Prowlarr

Indexer manager ([Prowlarr](https://prowlarr.com/)) via bjw-s `app-template` and `ghcr.io/home-operations/prowlarr`. Config only (no media mount).

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (5Gi). |
| `values.yaml` | Prowlarr image, probes, mount at `/config`. |
| `httproute.yaml` | `prowlarr.net.ecksd.ee` via Gateway `shared`. |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik for this HTTPRoute. |

Forward auth needs **authentik** applied first (shared **ReferenceGrant** and outpost route). See **`apps/authentik/README.md`**.

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/prowlarr" --enable-helm | kubectl apply -f -
```

Sync apps to Sonarr and Radarr from the Prowlarr UI. Pin the image `tag` in `values.yaml` when upgrading.
