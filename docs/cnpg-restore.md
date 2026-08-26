# CNPG restore

CloudNativePG clusters live under `apps/*/postgres.yaml` (ten clusters today). The operator and Barman Cloud plugin are installed from **xd-net** (`apps/postgres-operator.tf`, `apps/postgres-barman-plugin.tf`, namespace `cnpg-system`).

## Durability model

- Every cluster uses **`instances: 1`**, **`enablePDB: false`**, **`storageClass: local-path`** (fast worker data disk; not Synology iSCSI).
- `local-path` data lives on the worker **data disk** (`scsi1` → UserVolume `/var/mnt/local-path-data`), so a [worker EPHEMERAL wipe](worker-ephemeral-wipe.md) does **not** erase those PVCs. Losing the VM/data disk, wiping that UserVolume, or a failed node with no backup still loses the live database.
- Continuous WAL archiving + scheduled base backups go to **Garage** on the NAS (`https://s3.nas.net.ecksd.ee`, bucket `cnpg-barman`) via the Barman Cloud plugin (`ObjectStore` + `ScheduledBackup` in each app’s `backup.yaml`).

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

Bootstrap secrets (`*-db` in `secrets/`) must exist before a Cluster can `initdb` again — see `secrets/README.md`. Barman credentials are per-namespace Secret `cnpg-barman-s3` (`ACCESS_KEY_ID`, `ACCESS_SECRET_KEY`, `REGION=garage`).

## Garage credentials (once per workspace)

On the NAS (from [XD-24](https://github.com/chaosk/xd-nas) bootstrap):

```bash
alias garage='docker exec -it garage /garage'
garage bucket create cnpg-barman          # if not already created
garage key create cnpg-barman-key         # print Key ID + secret once
garage bucket allow cnpg-barman --read --write --owner --key cnpg-barman-key
```

Then create SOPS secrets (same key values in every CNPG namespace):

```bash
# Example for authentik; repeat for immich, monitoring, invidious, tracearr,
# bitmagnet, paperless-ngx, speedtest-tracker, miniflux, mealie.
cat > secrets/authentik-cnpg-barman-s3.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: cnpg-barman-s3
  namespace: authentik
  labels:
    cnpg.io/reload: "true"
stringData:
  ACCESS_KEY_ID: "PASTE_KEY_ID" # sops:encrypt
  ACCESS_SECRET_KEY: "PASTE_SECRET_KEY" # sops:encrypt
  REGION: "garage"
EOF
sops --encrypt --in-place secrets/authentik-cnpg-barman-s3.yaml
```

Commit ciphertext only. Argo **platform-secrets** syncs them before (or with) the app Applications.

## Verify backups

```bash
kubectl -n authentik get objectstore,scheduledbackup,backup
kubectl -n authentik describe backup   # newest Completed?
# On the NAS (Garage CLI): list objects under s3://cnpg-barman/
```

Nightly schedules are staggered between 03:00–04:30 UTC (`apps/*/backup.yaml`). Authentik / Immich / Grafana set `immediate: true` so the first backup runs on sync.

## Restore from Garage (PITR / base backup)

1. Confirm a Completed `Backup` exists and WALs are archiving for the source cluster name (Barman `serverName` defaults to the Cluster name).

2. Scale down or remove the broken Cluster (and PVC if empty/corrupt). Keep the `cnpg-barman-s3` Secret and `ObjectStore` `garage` in the namespace.

3. Temporarily change `apps/<app>/postgres.yaml` to recover instead of `initdb` (do **not** leave this as the steady-state Git config). Example for Authentik:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: authentik-db
spec:
  instances: 1
  enablePDB: false
  imageName: ghcr.io/cloudnative-pg/postgresql:18.3
  # Keep storage / resources / plugins as in Git
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: garage
  bootstrap:
    recovery:
      source: garage-source
  externalClusters:
    - name: garage-source
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: garage
          serverName: authentik-db
```

4. Apply, wait for the primary to become Ready, then restore the steady-state `bootstrap.initdb` stanza in Git (recovery is one-shot). For Immich, keep the VectorChord `imageName` and extension-related fields.

5. Restart the app Deployment/Pods; watch CNPG and app logs.

Upstream detail: [Barman Cloud plugin — Restoring a Cluster](https://cloudnative-pg.io/plugin-barman-cloud/docs/usage/).

## Logical dump escape hatch

Still useful before risky work or if the object store is unavailable:

```bash
NS=authentik
CLUSTER=authentik-db
DB=authentik

kubectl -n "$NS" exec -i "${CLUSTER}-1" -c postgres -- \
  pg_dump -Fc -d "$DB" > "${CLUSTER}-$(date +%F).dump"
```

Restore into a fresh primary:

```bash
kubectl -n "$NS" exec -i "${CLUSTER}-1" -c postgres -- \
  pg_restore -d "$DB" --clean --if-exists < "${CLUSTER}-YYYY-MM-DD.dump"
```

Store dumps off-cluster when you take them. For Immich keep dumps paired with the VectorChord major.
