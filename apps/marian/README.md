# Marian

[Marian](https://github.com/chaosk/marian) Discord scheduler (`ghcr.io/chaosk/marian`). One process opens the Discord gateway outbound and serves the dashboard. The live database is CloudNativePG cluster **`marian-db`**. The old SQLite file stays on the Synology PVC at `/data/marian.db` so it can be copied off. Do not scale past one replica.

## Access

- Host: `https://marian.ecksd.ee` (Pangolin public resource, `NewtSite` **xd-net**)
- There is no `*.net.ecksd.ee` route. Discord OAuth and Google Calendar fetch the calendar feed from this host.

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, SQLite PVC, CNPG cluster, Pangolin HTTPRoute, Helm chart. |
| `pvc.yaml` | Old SQLite file on StorageClass `synology` (1Gi), kept for a copy. |
| `postgres.yaml` | CNPG cluster `marian-db` on `local-path`. |
| `backup.yaml` | Barman backups of `marian-db` to Garage. |
| `values.yaml` | Image, probes, `/data` mount, public URL, `DATABASE_URL`. |
| `httproute-pangolin.yaml` | **`marian.ecksd.ee`** only; **`pangolin-operator/site-ref: xd-net`**. |

## Secrets

Create **`secrets/marian-db.yaml`** (CNPG bootstrap: `username`, `password`; owner and database `marian`) and **`secrets/marian.yaml`** in namespace **`marian`**. The app secret holds `DATABASE_URL`, `DISCORD_TOKEN`, `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET`, `GOOGLE_CLIENT_ID`, and `GOOGLE_CLIENT_SECRET`. The password in `DATABASE_URL` must match `marian-db`. Also create **`secrets/marian-cnpg-barman-s3.yaml`** so WAL archiving can reach Garage. Encrypt each file (`sops --encrypt --in-place`) and let **platform-secrets** sync them before the cluster and the pod start. Marian exits when `DISCORD_TOKEN` is empty. Without `DISCORD_CLIENT_SECRET` the site stays on the landing page. Empty Google credentials leave Google Calendar disconnected.

In the Discord application, add redirect **`https://marian.ecksd.ee/auth/discord/callback`**. In the Google OAuth client, add redirect **`https://marian.ecksd.ee/auth/google/callback`**. Invite the bot with permissions integer `326686174272` (View Channel, Send Messages, Manage Messages, Embed Links, Read Message History, Mention Everyone, Add Reactions, Manage Roles, and public threads):

```text
https://discord.com/api/oauth2/authorize?client_id=YOUR_ID&permissions=326686174272&scope=bot%20applications.commands
```

The gateway needs egress to `discord.com` and `gateway.discord.gg`. Nothing needs to reach the pod for Discord interactions. Spans go to Tempo over OTLP/HTTP at `http://tempo.monitoring.svc.cluster.local:4318` (`OTEL_EXPORTER_OTLP_ENDPOINT`).

`ghcr.io/chaosk/marian` is a private package. The cluster pulls public GHCR images with no per-app pull secret, so make this package public (GitHub → Packages → Package settings → Change visibility) or the pod cannot pull `0.1.0`.

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/marian" --enable-helm | kubectl apply -f -
```

Point **`marian.ecksd.ee`** DNS at the Pangolin edge, same as **`auth.ecksd.ee`** and **`plex.ecksd.ee`**.

**Argo CD Image Updater** tracks `ghcr.io/chaosk/marian` (semver tags such as `0.1.0`) in `apps/argocd-image-updater/image-updater.yaml`.
