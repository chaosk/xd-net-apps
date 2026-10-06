# JDownloader

[JDownloader 2](https://jdownloader.org/) via [jlesage/jdownloader-2](https://github.com/jlesage/docker-jdownloader-2) on bjw-s `app-template`. Browser GUI on port **5800** (no VNC client needed).

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, NFS downloads, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App data on StorageClass `synology` (2Gi). |
| `nfs-downloads.yaml` | RWX NFS `/volume1/ingest/downloads` → container `/output`. |
| `values.yaml` | Image, UID/GID, VPN label; mounts config, downloads, and `/dev/shm`. |
| `httproute.yaml` | `jdownloader.net.ecksd.ee` via Gateway `shared`. |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik. |

Forward auth needs **authentik** applied first (`referencegrants/forward-auth-jdownloader.yaml`). Domain-level forward-auth Proxy provider on **`net.ecksd.ee`** covers this hostname (see `apps/authentik/README.md`). Container web auth stays off (`WEB_AUTHENTICATION=0`).

## Apply

1. Create the NAS share **`/volume1/ingest/downloads`** (NFS export) if it does not exist yet.
2. Re-apply **vpn-gateway** if `routed_namespaces` changed (includes **`jdownloader`**).
3. Re-apply **authentik** (ReferenceGrant), then this app:

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/jdownloader" --enable-helm | kubectl apply -f -
```

Downloads appear on the NAS at `/volume1/ingest/downloads/`.

**Argo CD Image Updater** tracks **`docker.io/jlesage/jdownloader-2`** in `apps/argocd-image-updater/image-updater.yaml`.
