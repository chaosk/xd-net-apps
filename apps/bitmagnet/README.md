# Bitmagnet

Self-hosted [Bitmagnet](https://bitmagnet.io/) DHT crawler and torrent search (Web UI on port **3333**).

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, config PVC, CNPG cluster, HTTPRoute, Helm chart. |
| `pvc-config.yaml` | App config on StorageClass `synology` (5Gi) at `/root/.config/bitmagnet`. |
| `postgres.yaml` | CloudNativePG cluster `bitmagnet-db` (PostgreSQL 18.3, `local-path` 300Gi). |
| `values.yaml` | Image `ghcr.io/bitmagnet-io/bitmagnet`, workers via `worker run --all`, DB env from secret. |
| `httproute.yaml` | `bitmagnet.net.ecksd.ee` → Service `bitmagnet-main:3333` (homelab Gateway only). |
| `private-resource-pangolin.yaml` | Pangolin **private** HTTP at `bitmagnet.ecksd.ee` (Pangolin client required; not public internet). |

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

Wait for `bitmagnet-db` to be ready before the app pod stays healthy. Open `https://bitmagnet.net.ecksd.ee` on the LAN after sync.

## Pangolin (private remote)

`private-resource-pangolin.yaml` registers **`https://bitmagnet.ecksd.ee`** as a Pangolin **private** HTTP resource (`mode: http`). It is **not** reachable from the public internet without the [Pangolin client](https://docs.pangolin.net/) connected — unlike Plex’s `httproute-pangolin.yaml` public route.

1. **`ecksd.ee`** must be a domain in your Pangolin org (same as other `*.ecksd.ee` resources).
2. Argo syncs the `PrivateResource`; pangolin-operator reconciles it against the Integration API (`NewtSite` **`xd-net`**).
3. Connect with the Pangolin desktop/mobile client, then open **`https://bitmagnet.ecksd.ee`**.
4. Grant access in the Pangolin dashboard (users/roles) if you restricted the resource; omitting `roleIds`/`userIds` in the CR leaves org-admin access per Pangolin defaults.

Do **not** add `pangolin-operator/site-ref` to `httproute.yaml` — that would create a duplicate **public** resource for the same app.

## Prowlarr

Add Bitmagnet as a Torznab/newznab-style indexer using the in-cluster URL or public hostname; see [Bitmagnet docs](https://bitmagnet.io/guides/indexers.html).
