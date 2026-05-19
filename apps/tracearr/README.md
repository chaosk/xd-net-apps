# Tracearr

[Tracearr](https://tracearr.com) is a self-hosted dashboard for Plex, Jellyfin, and Emby (sessions, bandwidth, rules, maps). This app bundles **Gateway exposure** and **Helm values** around the **official Helm chart** from the Tracearr repo, as described in the [Kubernetes (Helm) installation guide](https://docs.tracearr.com/getting-started/installation/kubernetes).

## What lives here

| Piece | Role |
|--------|------|
| `kustomization.yaml` | **Namespace**, **HTTPRoute**, **ImageCatalog**, and CNPG **`Cluster`**. |
| `namespace.yaml` | `tracearr` namespace. |
| `httproute.yaml` | Gateway route + **[Homepage](https://gethomepage.dev/)** link annotations (Media group; no widget). |
| `image-catalog.yaml` | CNPG **ImageCatalog** for `timescale/timescaledb:2.25.1-pg18` (PG 18 / Timescale 2.25, same lineage as the chart’s bundled image). |
| `postgres.yaml` | CNPG cluster **`tracearr-db`** (single instance, **10Gi** on **`local-path`**, Timescale + `pg_trgm` via `postInitApplicationSQL`). |
| `values.yaml` | Helm overrides: **`timescale.enabled: false`**, **`externalDatabase.host: tracearr-db-rw`**, Redis/backups/cache storage, `ingress.enabled: false`. |
| `vendor/tracearr-0.1.0/tracearr/` | Vendored copy of upstream [`docker/helm/tracearr`](https://github.com/connorgallopo/Tracearr/tree/main/docker/helm/tracearr) so `helm` does not need a separate `git clone`. |

PostgreSQL is **[CloudNativePG](https://cloudnative-pg.io/)** (operator from **xd-net**), not the chart’s bundled TimescaleDB StatefulSet. The chart still deploys **Redis** and the Tracearr app.

The chart itself is maintained upstream; this directory is wiring for **xd-net** (Gateway API, Synology `StorageClass`, CNPG, etc.).

## Prerequisites

- **Gateway API** HTTPRoute parent `shared` in namespace `gateway` (same pattern as other apps in this repo).
- **StorageClass** `local-path` for the database (`postgres.yaml`); **`synology`** for Redis/backups/cache in `values.yaml` (change to match your cluster).
- **CloudNativePG operator** installed cluster-wide (see **xd-net** / `cnpg-system`).
- **Helm 3** on the machine where you run install commands.

Tracearr is not published as a public **Helm repo index** or **OCI** chart, so `kubectl kustomize --enable-helm` cannot pull it by `repo`/`version` alone the way charts on Artifact Hub do. Either use the **vendored path** below or an **Argo CD Helm** application with `repoURL` = `https://github.com/connorgallopo/Tracearr` and `path` = `docker/helm/tracearr` if you prefer not to vendor.

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

2. **Cluster extras** (namespace, route, CNPG DB):

   ```bash
   kubectl apply -k "$HOME/Projects/xd-net-apps/apps/tracearr"
   ```

   Wait until `kubectl cnpg status -n tracearr tracearr-db` reports the cluster ready.

3. **Helm release** (app + Redis; DB is external CNPG):

   ```bash
   helm upgrade --install tracearr "$HOME/Projects/xd-net-apps/apps/tracearr/vendor/tracearr-0.1.0/tracearr" \
     --namespace tracearr \
     -f "$HOME/Projects/xd-net-apps/apps/tracearr/values.yaml"
   ```

Back up `JWT_SECRET` and `COOKIE_SECRET` from `tracearr-db` after first install; changing them invalidates sessions. `timescaledb_toolkit` is optional (Tracearr enables it only when the extension is available on the server); the CNPG image includes TimescaleDB and `pg_trgm`, not the HA image’s preinstalled toolkit.

## Networking

Tracearr relies on **WebSockets** and **SSE**. Your Gateway (or any ingress in front of it) must allow **HTTP upgrade** and timeouts long enough for idle streams. The upstream doc shows **nginx** annotations as an example; translate that to whatever controls idle timeouts on your path (`tracearr.net.ecksd.ee` → Gateway → Service `tracearr`).

## Storage

CNPG provisions the **database PVC** (**10Gi**, `local-path`) via `postgres.yaml`. The Helm chart still provisions **Redis**, backups, and image cache PVCs; `values.yaml` pins **`synology`** for those. To back volumes with **NFS**, use a **StorageClass** whose provisioner writes to NFS (for example a Synology or NFS CSI driver), not a hand-written `PersistentVolume` like Plex media in this repo.

## Refreshing the vendored chart

When [`docker/helm/tracearr`](https://github.com/connorgallopo/Tracearr/tree/main/docker/helm/tracearr) changes, re-copy `Chart.yaml`, `values.yaml`, and everything under `templates/` from `main` (or a release tag), then adjust the `vendor/tracearr-<Chart.Version>/` directory name if `Chart.yaml` `version` bumps. Re-run `helm upgrade` with the new path.

## Upgrading the running release

```bash
helm upgrade tracearr "$HOME/Projects/xd-net-apps/apps/tracearr/vendor/tracearr-0.1.0/tracearr" \
  --namespace tracearr \
  -f "$HOME/Projects/xd-net-apps/apps/tracearr/values.yaml"
```

See upstream [Upgrading](https://docs.tracearr.com/getting-started/installation/kubernetes) notes for database password changes and chart behavior across versions.
