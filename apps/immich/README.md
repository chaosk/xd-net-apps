# Immich

[Immich](https://immich.app/) via the [official Helm chart](https://github.com/immich-app/immich-charts). PostgreSQL is a **CloudNativePG** cluster with **VectorChord** (`postgres.yaml`); operator from **xd-net**.

## Access

- Host: `https://photos.net.ecksd.ee` (Gateway `shared`)
- Homepage widget: API key in **`secrets/homepage-immich-widget.yaml`**

## Secrets

| Secret | Namespace | Purpose |
|--------|-----------|---------|
| `immich-db` | `immich` | CNPG bootstrap + app connection (`username`, `password`, `host`, `user`, `dbname`) |
| `immich-config` | `immich` | Non-default app config (OAuth/Authentik, QSV, external domain); whole key SOPS-encrypted — edit with `sops secrets/immich-config.yaml` |

Sync via **platform-secrets** before the CNPG cluster reconciles ([`secrets/README.md`](../../secrets/README.md)).

## Storage and scheduling

- Photo library: NFS **`nas.net.ecksd.ee`**, path **`/volume1/malachit/photos/`** (`nfs-library.yaml`, RWX)
- **`immich-server`** and **`immich-machine-learning`** on Intel GPU nodes (`gpu.intel.com/i915`, same pattern as Plex)
- **`ffmpeg.accel: qsv`** in immich config; ML image uses **`-openvino`** tags (Image Updater keeps server and ML tags in lockstep)

Plex, server transcoding, and ML share GPU capacity on the same node.

## Layout

| File | Purpose |
|------|---------|
| `postgres.yaml` | CNPG **`immich-db`** on `local-path` |
| `nfs-library.yaml` | RWX library mount |
| `values.yaml` | Server + ML controllers, metrics, GPU, existingConfiguration |
| `httproute.yaml` | `photos.net.ecksd.ee` + Homepage |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/immich" --enable-helm | kubectl apply -f -
```

**Argo CD Image Updater** tracks `ghcr.io/immich-app/immich-server` and matching **`v3.x.y-openvino`** ML tags in `apps/argocd-image-updater/image-updater.yaml`.

Helm chart version is pinned in **`kustomization.yaml`**; bump when [immich-charts](https://github.com/immich-app/immich-charts/releases) requires it.

Machine-learning model cache is **`emptyDir`** (models re-download on pod restart).
