# Immich

Deploys [Immich](https://immich.app/) with the **official Helm chart** ([Kubernetes install docs](https://docs.immich.app/install/kubernetes/), chart repo [immich-charts](https://github.com/immich-app/immich-charts)).

PostgreSQL is a **[CloudNativePG](https://cloudnative-pg.io/) `Cluster`** (`postgres.yaml`) using **[VectorChord](https://github.com/tensorchord/cloudnative-vectorchord)** with `shared_preload_libraries: vchord.so`, extensions `vchord` and `earthdistance`, and **`ALTER USER immich WITH SUPERUSER`** at bootstrap ([Immich pre-existing Postgres — with superuser](https://docs.immich.app/administration/postgres-standalone/#with-superuser-permission)). The CNPG operator is installed from **xd-net**.

## Before sync

1. **`nfs-library.yaml`** — set NFS `server`, `path`, and capacity to your photo export (same pattern as Plex media). Allow **every node** that can run `immich-server` to mount that export, or constrain scheduling later.

2. **`httproute.yaml`** — set the hostname to one covered by the shared Gateway TLS cert in **xd-net** (`gateway_tls_dns_names`). Homepage discovery uses **`gethomepage.dev/*`** annotations; add an API key in **`secrets/homepage-immich-widget.yaml`** (`server.statistics` permission) and sync **platform-secrets**.

3. **Secret `immich-db`** in namespace **`immich`** — required **before** the CNPG cluster can bootstrap and for the Immich chart. Use **one** Secret for both CNPG (`bootstrap.initdb.secret`) and the app connection keys:

   | Key | Value |
   |-----|--------|
   | `username` | Same as `user` (e.g. `immich`) — **required by CloudNativePG** bootstrap |
   | `password` | Strong password |
   | `host` | `immich-db-rw` (same namespace) or `immich-db-rw.immich.svc.cluster.local` |
   | `user` | e.g. `immich` (Immich chart reads this) |
   | `dbname` | e.g. `immich` |

   Encrypt with **SOPS** under `secrets/` and set **`metadata.namespace: immich`** ([`secrets/README.md`](../../secrets/README.md)).

4. **Application settings** — Non-default options live in **`secrets/immich-config.yaml`** (Secret **`immich-config`**, key **`immich-config.yaml`**; whole key SOPS-encrypted — see **`secrets/README.md`**). The Helm chart mounts it via **`immich.existingConfiguration`** in `values.yaml`. Edit with `sops secrets/immich-config.yaml`. Compared to defaults: **OAuth** with Authentik, **storage template** enabled, **`server.externalDomain`** `https://photos.net.ecksd.ee`, **`ffmpeg.accel: qsv`** on GPU nodes.

5. **Chart version** — `kustomization.yaml` pins `helmCharts.version`. Bump after checking [immich-charts releases](https://github.com/immich-app/immich-charts/releases). Override **`controllers.main.containers.main.image.tag`** in `values.yaml` when you want a newer Immich app version than the chart default.

6. **Hardware transcoding** — `values.yaml` schedules **`immich-server`** on Intel GPU nodes (`intel.feature.node.kubernetes.io/gpu`, `gpu.intel.com/i915`) like Plex, with **`ffmpeg.accel: qsv`** in `immich.configuration`. The GPU node must reach the NFS library export. Confirm in **Administration → Video transcoding** after deploy; see [Immich hardware transcoding](https://docs.immich.app/features/hardware-transcoding/).

7. **Hardware-accelerated ML (Intel Arc)** — **`immich-machine-learning`** uses image tag **`v2.7.5-openvino`** (OpenVINO for Intel discrete/integrated GPUs) on the same GPU nodes and **`gpu.intel.com/i915`** resource as Plex. Bump the **`-openvino`** tag together with **`controllers.main.containers.main.image.tag`** when upgrading Immich. After deploy, check ML logs for `Available ORT providers` including OpenVINO; see [hardware-accelerated ML](https://docs.immich.app/features/ml-hardware-acceleration). Plex, server transcoding, and ML may contend for one GPU — ensure the node exposes enough **`gpu.intel.com/i915`** capacity or accept serialized load.

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/immich" --enable-helm | kubectl apply -f -
```

## Optional

- **Machine-learning model cache** — default is `emptyDir` (models re-download on restart). For persistent cache, configure `machine-learning.persistence.cache` per upstream `values.yaml`.
- **Alpine + `search` in resolv.conf** — see [Immich Kubernetes doc](https://docs.immich.app/install/kubernetes/) note on DNS; set `dnsConfig` / `dnsPolicy` on pods if needed.
