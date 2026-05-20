# Bitmagnet

Self-hosted [Bitmagnet](https://bitmagnet.io/) DHT crawler and torrent search (Web UI on port **3333**).

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, CNPG cluster, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App config on StorageClass `synology` (5Gi) at `/root/.config/bitmagnet`. |
| `postgres.yaml` | CloudNativePG cluster `bitmagnet-db` (PostgreSQL 18.3, `local-path` 300Gi). |
| `values.yaml` | Image `ghcr.io/bitmagnet-io/bitmagnet`, workers via `worker run --all`, DB env from secret. |
| `httproute.yaml` | `bitmagnet.net.ecksd.ee` → Service `bitmagnet-main:3333`. |

## Before you apply

1. Create and encrypt **`secrets/bitmagnet-db.yaml`** and **`secrets/bitmagnet.yaml`** (Postgres bootstrap + `TMDB_API_KEY` from [TMDB API settings](https://www.themoviedb.org/settings/api)). See `secrets/README.md`.

2. Apply **platform-secrets** (or `kubectl apply` the decrypted secrets) before the CNPG cluster and app.

3. **DHT port 3334** is exposed as ClusterIP TCP/UDP services (`bitmagnet-torrent-tcp`, `bitmagnet-torrent-udp`). For full DHT participation you may need a **NodePort**, **LoadBalancer**, or **hostNetwork** so peers can reach UDP 3334 from outside the cluster.

## VPN egress

DHT and BitTorrent traffic use **[pod-gateway](../vpn-gateway/README.md)** (same as qBittorrent):

- Namespace **`pod-security.kubernetes.io/enforce: privileged`** (pod-gateway requires `NET_ADMIN` / `NET_RAW`)
- Namespace label **`allows-vpn-gateway: "true"`**
- Pod label **`vpn-gateway: "true"`** on the Bitmagnet deployment
- **`bitmagnet`** in `routed_namespaces` in `apps/vpn-gateway/values-pod-gateway.yaml`

Apply **vpn-gateway** first if you changed `routed_namespaces`, then recreate the Bitmagnet pod. Postgres (`bitmagnet-db-rw`) stays on normal cluster routing.

```bash
kubectl exec -n bitmagnet deploy/bitmagnet -c main -- curl -4 -sS --max-time 15 https://api.ipify.org
```

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/vpn-gateway" --enable-helm | kubectl apply -f -
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/bitmagnet" --enable-helm | kubectl apply -f -
```

If the CNPG cluster already exists, growing PVCs to 300Gi or upgrading Postgres 16→18 may require [CNPG volume expansion](https://cloudnative-pg.io/documentation/current/storage/) or a fresh cluster — plan before changing a live database.

Wait for `bitmagnet-db` to be ready before the app pod stays healthy. Open `https://bitmagnet.net.ecksd.ee` after sync.

## Prowlarr

Add Bitmagnet as a Torznab/newznab-style indexer using the in-cluster URL or public hostname; see [Bitmagnet docs](https://bitmagnet.io/guides/indexers.html).
