# Actual Budget

[Actual Budget](https://actualbudget.org/) via bjw-s `app-template`. Budget files and server state live on a Synology PVC at `/data`.

## Access

- Host: `https://actual.net.ecksd.ee` (Gateway `shared`, TLS `*.net.ecksd.ee`)

Authentication is Actual’s **server password** in the UI, not Authentik forward-auth.

## Layout

| File | Purpose |
|------|---------|
| `pvc.yaml` | Budget data on StorageClass `synology` (5Gi) |
| `values.yaml` | `ghcr.io/actualbudget/actual-server`, probes, resources |
| `httproute.yaml` | `actual.net.ecksd.ee` + Homepage discovery (Data storage group) |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/actual-budget" --enable-helm | kubectl apply -f -
```

On first visit, set the **Actual server password** in the UI. It is stored on the PVC, not in this repo.

**Argo CD Image Updater** tracks `ghcr.io/actualbudget/actual-server` (semver) in `apps/argocd-image-updater/image-updater.yaml`.
