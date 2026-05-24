# Actual Budget

Deploys [Actual Budget](https://actualbudget.org/) with the **bjw-s app-template** chart. Budget files and server state live on a Synology PVC at `/data`.

## Access

- Host: `https://actual.net.ecksd.ee` (Gateway API via shared cluster Gateway)

Authentication is handled by Actual’s own **server password** in the UI, not Authentik forward-auth.

## Before sync

1. **DNS** — point `actual.net.ecksd.ee` at the cluster ingress like your other `*.net.ecksd.ee` apps.

2. **Storage** — `pvc.yaml` uses **`synology`** (5Gi) for `/data` (`server-files` and `user-files` are created by the container).

3. **First visit** — after sync, open the URL and set the **Actual server password** in the UI. That password protects sync and admin actions; it is stored in the PVC, not in this repo.

## Layout

| File | Purpose |
|------|---------|
| `pvc.yaml` | Budget data on Synology |
| `values.yaml` | `ghcr.io/actualbudget/actual-server` container, probes, resources |
| `httproute.yaml` | `actual.net.ecksd.ee` + Homepage discovery |

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/actual-budget" --enable-helm | kubectl apply -f -
```

Pin the image `tag` in `values.yaml` when upgrading ([Docker tags](https://actualbudget.org/docs/install/docker)).
