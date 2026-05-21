# Tracearr

[Tracearr](https://tracearr.com) is a self-hosted dashboard for Plex, Jellyfin, and Emby (sessions, bandwidth, rules, maps). This app bundles **Gateway exposure** and **Helm values** around the **official Helm chart** from the Tracearr repo, as described in the [Kubernetes (Helm) installation guide](https://docs.tracearr.com/getting-started/installation/kubernetes).

## What lives here

| Piece | Role |
|--------|------|
| `kustomization.yaml` | **Namespace**, **HTTPRoute**, **ImageCatalog**, CNPG **`Cluster`**, and **vendored Helm chart** (`helmCharts` + `values.yaml`). |
| `namespace.yaml` | `tracearr` namespace. |
| `httproute.yaml` | Gateway route + **[Homepage](https://gethomepage.dev/)** annotations (Media group; **Plex** widget on this tile). |
| `image-catalog.yaml` | CNPG **ImageCatalog** for `timescale/timescaledb:2.25.1-pg18` (PG 18 / Timescale 2.25, same lineage as the chart’s bundled image). |
| `postgres.yaml` | CNPG cluster **`tracearr-db`** (Timescale image, **`postgresUID`/`postgresGID` 70**, **10Gi** `local-path`, `postInitApplicationSQL` for Timescale + `pg_trgm`). |
| `values.yaml` | Helm overrides: **`timescale.enabled: false`**, **`externalDatabase.host: tracearr-db-rw`**, app/Redis **resources**, backups/cache storage, `ingress.enabled: false`. |
| `vendor/tracearr-0.1.0/tracearr/` | Vendored copy of upstream [`docker/helm/tracearr`](https://github.com/connorgallopo/Tracearr/tree/main/docker/helm/tracearr) so `helm` does not need a separate `git clone`. |

PostgreSQL is **[CloudNativePG](https://cloudnative-pg.io/)** (operator from **xd-net**), not the chart’s bundled TimescaleDB StatefulSet. The chart still deploys **Redis** and the Tracearr app.

The chart itself is maintained upstream; this directory is wiring for **xd-net** (Gateway API, Synology `StorageClass`, CNPG, etc.).

## Prerequisites

- **Gateway API** HTTPRoute parent `shared` in namespace `gateway` (same pattern as other apps in this repo).
- **StorageClass** `local-path` for the database (`postgres.yaml`); **`synology`** for Redis/backups/cache in `values.yaml` (change to match your cluster).
- **CloudNativePG operator** installed cluster-wide (see **xd-net** / `cnpg-system`).
- **Helm 3** (used by Kustomize to render the vendored chart under `vendor/tracearr-0.1.0/tracearr/`).

The upstream chart is not on a public Helm repo index; this app **vendors** it so `kubectl kustomize --enable-helm` can install app + Redis alongside the HTTPRoute and CNPG cluster in one apply.

## Before you apply

1. **Secret `tracearr-db`** (namespace **`tracearr`**) — CNPG bootstrap and Helm (`secrets.existingSecret: tracearr-db`). Template: [`secrets/tracearr-db.yaml`](../../secrets/tracearr-db.yaml). SOPS-encrypt and sync via **platform-secrets** ([`secrets/README.md`](../../secrets/README.md)).

   | Key | Purpose |
   |-----|---------|
   | `username` | CNPG bootstrap owner (`tracearr`) |
   | `password` | Database password |
   | `DB_PASSWORD` | Same value as `password` (Tracearr `DATABASE_URL`) |
   | `JWT_SECRET` | App signing (e.g. `openssl rand -hex 32`) |
   | `COOKIE_SECRET` | Session cookies (e.g. `openssl rand -hex 32`) |

2. **Fresh install only** — PostgreSQL 18 data is not compatible with older chart Timescale volumes. Do not point CNPG at an existing `tracearr-timescale` PVC without a planned dump/restore.

## Install

1. **Platform secret** (if not already synced by Argo):

   ```bash
   kubectl apply -f secrets/tracearr-db.yaml   # after SOPS encrypt + real values
   ```

2. **Apply** (namespace, CNPG, Helm app + Redis, HTTPRoute — needs `--enable-helm` so the `tracearr` Service exists for the route):

   ```bash
   kubectl kustomize "$HOME/Projects/xd-net-apps/apps/tracearr" --enable-helm | kubectl apply -f -
   ```

   Wait until `kubectl cnpg status -n tracearr tracearr-db` reports the cluster ready and `kubectl get svc tracearr -n tracearr` exists.

Back up `JWT_SECRET` and `COOKIE_SECRET` from `tracearr-db` after first install; changing them invalidates sessions. `timescaledb_toolkit` is optional (Tracearr enables it only when the extension is available on the server); the CNPG image includes TimescaleDB and `pg_trgm`, not the HA image’s preinstalled toolkit.

## Networking

Tracearr relies on **WebSockets** and **SSE**. Your Gateway must allow **HTTP upgrade** and timeouts long enough for idle streams. The upstream doc shows **nginx** annotations as an example; tune timeouts on the Envoy Gateway path in **xd-net** if streams drop.

## Storage

CNPG provisions the **database PVC** (**10Gi**, `local-path`) via `postgres.yaml`. The Helm chart still provisions **Redis**, backups, and image cache PVCs; `values.yaml` pins **`synology`** for those. To back volumes with **NFS**, use a **StorageClass** whose provisioner writes to NFS (for example a Synology or NFS CSI driver), not a hand-written `PersistentVolume` like Plex media in this repo.

## Refreshing the vendored chart

When [`docker/helm/tracearr`](https://github.com/connorgallopo/Tracearr/tree/main/docker/helm/tracearr) changes, replace the whole `vendor/tracearr-<Chart.Version>/tracearr/` tree from upstream (do not patch files in place). Adjust `helmCharts.version` in `kustomization.yaml` if `Chart.yaml` `version` bumps. Bump the app image in **`values.yaml`** (`tracearr.image.tag`), not in the vendored chart. Re-apply with `kubectl kustomize … --enable-helm | kubectl apply -f -`.

## Upgrading the running release

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/tracearr" --enable-helm | kubectl apply -f -
```

See upstream [Upgrading](https://docs.tracearr.com/getting-started/installation/kubernetes) notes for database password changes and chart behavior across versions.
