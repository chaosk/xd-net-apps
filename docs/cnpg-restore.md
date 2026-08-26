# CNPG restore

CloudNativePG clusters live under `apps/*/postgres.yaml` (ten clusters today). The operator is installed from **xd-net** (`apps/postgres-operator.tf`, namespace `cnpg-system`).

## Current durability (honest)

As of this writing:

- Every cluster uses **`instances: 1`**, **`enablePDB: false`**, **`storageClass: local-path`**.
- There is **no** `backup` / Barman object-store / `ScheduledBackup` configuration in Git.
- `local-path` data lives on the worker **data disk** (`scsi1` → UserVolume `/var/mnt/local-path-data`), so a [worker EPHEMERAL wipe](worker-ephemeral-wipe.md) does **not** erase those PVCs. Losing the VM/data disk, wiping that UserVolume, or a failed node with no dump still loses the database.

Until object-store backups land (tracked separately), the only practical recovery paths are **logical dumps you took beforehand** or **re-bootstrap + app reconfigure**.

## Inventory

| Cluster | Namespace | Notes |
|---------|-----------|-------|
| `authentik-db` | `authentik` | Stock Postgres; Identity DB |
| `immich-db` | `immich` | VectorChord image + extensions — restore must keep the same image family |
| `invidious-db` | `invidious` | |
| `tracearr-db` | `tracearr` | |
| `bitmagnet-db` | `bitmagnet` | |
| `paperless-db` | `paperless-ngx` | |
| `speedtest-tracker-db` | `speedtest-tracker` | |
| `miniflux-db` | `miniflux` | |
| `mealie-db` | `mealie` | |
| `grafana-db` | `monitoring` | Grafana internal metadata |

Bootstrap secrets (`*-db` in `secrets/`) must exist before a Cluster can `initdb` again — see `secrets/README.md`.

## Before risky work (recommended)

Take a logical dump while the cluster is healthy:

```bash
NS=authentik
CLUSTER=authentik-db
DB=authentik

kubectl -n "$NS" exec -i "${CLUSTER}-1" -c postgres -- \
  pg_dump -Fc -d "$DB" > "${CLUSTER}-$(date +%F).dump"
```

Store the dump off-cluster (Synology share, encrypted backup, etc.). For Immich use the same pattern against `immich` / `immich-db-1`, keeping dumps paired with the VectorChord major.

## After PVC / node loss (no object-store backup)

1. Confirm the Cluster is unhealthy and the PVC is gone or empty:

   ```bash
   kubectl -n "$NS" get cluster,pods,pvc -l cnpg.io/cluster="$CLUSTER"
   ```

2. If the Cluster object still exists but the volume is empty, delete the Cluster (and orphaned PVC if needed) so CNPG can recreate, **or** keep the object and follow upstream [recovery](https://cloudnative-pg.io/documentation/current/recovery/) once Barman backups exist.

3. With only `bootstrap.initdb` in Git, a fresh Cluster runs **empty** `initdb` using the existing `*-db` Secret. Apps that expect existing schema/data need either:
   - restore from your `pg_dump` into the new primary, or
   - accept a clean slate (Authentik: re-run first install; Grafana: lose preferences; Immich: catastrophic without a dump).

4. Example restore into a new primary (adjust names):

   ```bash
   kubectl -n "$NS" exec -i "${CLUSTER}-1" -c postgres -- \
     pg_restore -d "$DB" --clean --if-exists < "${CLUSTER}-YYYY-MM-DD.dump"
   ```

5. Restart the app Deployment/Pods so they reconnect; watch CNPG and app logs.

## When object-store backups exist (future)

Add CNPG `backup` + `ScheduledBackup` (and preferably Synology-backed storage) per cluster. Restore then uses `bootstrap.recovery` / PITR from the object store as documented upstream — update this runbook when that lands. Do not invent a recovery stanza until the backup destination and credentials are real.
