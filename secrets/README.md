# secrets

SOPS-encrypted Kubernetes Secrets synced by Argo CD **platform-secrets** (**xd-net** `apps/argocd-gitops.tf`). Each file sets `metadata.namespace` to the target namespace.

## New secrets

1. Add `secrets/<name>.yaml` with `metadata.name` and `metadata.namespace` (see table below).
2. Put values in `stringData`. Mark sensitive scalars with trailing `# sops:encrypt` (see [`.sops.yaml`](../.sops.yaml): `encrypted_comment_regex: sops:encrypt`). Unmarked keys stay plaintext in the decrypted file.

   **Nested config keys** (`secrets/immich-config.yaml`, `secrets/peanut.yaml`): multiline blocks (`immich-config.yaml:`, `settings.yml:`). SOPS encrypts the whole key via `encrypted_regex` on the key name — edit with `sops secrets/<file>.yaml`.

3. Encrypt before commit:

   ```bash
   sops --encrypt --in-place secrets/<name>.yaml
   ```

   Or create encrypted from the start: `sops secrets/<name>.yaml`.

## Editing

```bash
sops secrets/<name>.yaml
```

Requires the age private key matching `.sops.yaml` recipients (`SOPS_AGE_KEY_FILE`).

Commit ciphertext only.

## Inventory

| Encrypted file (example name) | `metadata.namespace` | Purpose |
|------------------------------|----------------------|---------|
| `authentik-secret-key.yaml` | `authentik` | Authentik app signing key (`authentik-secret-key`, key `secret_key`). |
| `authentik-db.yaml` | `authentik` | CNPG bootstrap + Authentik DB password (`authentik-db`, keys `username`, `password`). |
| `authentik-geoip.yaml` | `authentik` | MaxMind GeoLite2 updater (`authentik-geoip`, keys `account_id`, `license_key`). See [GeoIP](https://docs.goauthentik.io/sys-mgmt/ops/geoip/). |
| `immich-db.yaml` | `immich` | CNPG bootstrap + Immich connection (`immich-db`, keys `username`, `password`, `host`, `user`, `dbname`). |
| `immich-config.yaml` | `immich` | Immich config file for Helm (`immich-config`, key `immich-config.yaml`; whole key SOPS-encrypted). See `apps/immich/README.md`. |
| `homepage-authentik-widget.yaml` | `homepage` | Authentik API token for Homepage widget via env `HOMEPAGE_VAR_AUTHENTIK_TOKEN` ([widget](https://gethomepage.dev/widgets/services/authentik/), [secrets](https://gethomepage.dev/installation/docker/#secrets)). |
| `homepage-tubearchivist-widget.yaml` | `homepage` | Tube Archivist API token for Homepage widget via env `HOMEPAGE_VAR_TUBEARCHIVIST_API_KEY` ([widget](https://gethomepage.dev/widgets/services/tubearchivist/)). |
| `plex-tubearchivist-plex.yaml` | `plex` | Tube Archivist API token and in-cluster URL for [tubearchivist-plex](https://github.com/tubearchivist/tubearchivist-plex) scanner/agent (`TA_API_KEY`, `TA_URL`). Use the same API token as the Homepage widget. |
| `homepage-tracearr-widget.yaml` | `homepage` | Tracearr API key for Homepage widget via env `HOMEPAGE_VAR_TRACEARR_API_KEY` ([widget](https://gethomepage.dev/widgets/services/tracearr/)); shown on the **Plex** tile. |
| `homepage-plex-widget.yaml` | `homepage` | Plex token for Homepage widget via env `HOMEPAGE_VAR_PLEX_TOKEN` ([widget](https://gethomepage.dev/widgets/services/plex/)); shown on the **Tracearr** tile. |
| `homepage-sonarr-widget.yaml` | `homepage` | Sonarr API key for Homepage widget via env `HOMEPAGE_VAR_SONARR_API_KEY` ([widget](https://gethomepage.dev/widgets/services/sonarr/)); shown on the **Sonarr** tile. |
| `homepage-radarr-widget.yaml` | `homepage` | Radarr API key for Homepage widget via env `HOMEPAGE_VAR_RADARR_API_KEY` ([widget](https://gethomepage.dev/widgets/services/radarr/)); shown on the **Radarr** tile. |
| `homepage-immich-widget.yaml` | `homepage` | Immich API key for Homepage widget via env `HOMEPAGE_VAR_IMMICH_API_KEY` ([widget](https://gethomepage.dev/widgets/services/immich/)); shown on the **Immich** tile. |
| `homepage-dsm-widget.yaml` | `homepage` | Synology DSM Disk Station widget credentials via env `HOMEPAGE_VAR_DSM_USERNAME` and `HOMEPAGE_VAR_DSM_PASSWORD` ([widget](https://gethomepage.dev/widgets/services/diskstation/)); used on the **DSM** tile in `services.yaml`. |
| `homepage-unifi-widget.yaml` | `homepage` | UniFi controller widget via env `HOMEPAGE_VAR_UNIFI_USERNAME` and `HOMEPAGE_VAR_UNIFI_PASSWORD` ([widget](https://gethomepage.dev/widgets/services/unifi-controller/)); use the same local admin as **`unpoller-unifi`**. |
| `homepage-argocd-widget.yaml` | `homepage` | Argo CD API token for Homepage widget via env `HOMEPAGE_VAR_ARGOCD_API_KEY` ([widget](https://gethomepage.dev/widgets/services/argocd/)); used on the **Argo CD** HTTPRoute in **xd-net**. Token from **Settings → Accounts → homepage → Tokens** (readonly account). |
| `peanut.yaml` | `peanut` | PeaNUT `settings.yml` (Synology NUT host `nas.net.ecksd.ee:3493`, credentials). See `apps/peanut/README.md`. |
| `homepage-pangolin-widget.yaml` | `homepage` | Pangolin Integration API for Homepage widget via env `HOMEPAGE_VAR_PANGOLIN_API_URL`, `HOMEPAGE_VAR_PANGOLIN_DASHBOARD_URL`, `HOMEPAGE_VAR_PANGOLIN_ORG`, and `HOMEPAGE_VAR_PANGOLIN_API_KEY` ([widget](https://gethomepage.dev/widgets/services/pangolin/)); used on the **Pangolin** tile in `services.yaml`. |
| `tubearchivist.yaml` | `tubearchivist` | Elasticsearch (`tubearchivist`, keys `ELASTIC_PASSWORD`). See [env vars](https://docs.tubearchivist.com/installation/env-vars/). |
| `vpn-gateway.yaml` | `vpn-gateway` | Gluetun VPN (`vpn-gateway`). See [vpn-gateway README](../apps/vpn-gateway/README.md). |
| `tracearr-db.yaml` | `tracearr` | CNPG bootstrap + Tracearr Helm (`tracearr-db`: `username`, `password`, `DB_PASSWORD`, `JWT_SECRET`, `COOKIE_SECRET`; `DB_PASSWORD` must match `password`). |
| `bitmagnet-db.yaml` | `bitmagnet` | CNPG bootstrap (`bitmagnet-db`, keys `username`, `password`; owner/database `bitmagnet` in `apps/bitmagnet/postgres.yaml`). |
| `bitmagnet.yaml` | `bitmagnet` | TMDB API key (`bitmagnet`, key `TMDB_API_KEY`) for metadata enrichment. |
| `paperless-db.yaml` | `paperless-ngx` | CNPG bootstrap (`paperless-db`, keys `username`, `password`; owner/database `paperless` in `apps/paperless-ngx/postgres.yaml`). |
| `paperless.yaml` | `paperless-ngx` | Django secret and first-run admin (`paperless`, keys `PAPERLESS_SECRET_KEY`). |
| `homepage-paperless-widget.yaml` | `homepage` | Paperless API token for Homepage widget via env `HOMEPAGE_VAR_PAPERLESS_API_TOKEN` ([widget](https://gethomepage.dev/widgets/services/paperlessngx/)). |
| `speedtest-tracker-db.yaml` | `speedtest-tracker` | CNPG bootstrap (`speedtest-tracker-db`, keys `username`, `password`; owner `speedtest`, database `speedtest_tracker` in `apps/speedtest-tracker/postgres.yaml`). |
| `speedtest-tracker.yaml` | `speedtest-tracker` | Laravel app key (`speedtest-tracker`, key `APP_KEY`). |
| `homepage-speedtest-tracker-widget.yaml` | `homepage` | Speedtest Tracker API token for Homepage widget via env `HOMEPAGE_VAR_SPEEDTEST_TRACKER_API_KEY` ([widget](https://gethomepage.dev/widgets/services/speedtest-tracker/)). |
| `miniflux-db.yaml` | `miniflux` | CNPG bootstrap (`miniflux-db`, keys `username`, `password`; owner/database `miniflux` in `apps/miniflux/postgres.yaml`). |
| `miniflux.yaml` | `miniflux` | `DATABASE_URL`, `OAUTH2_CLIENT_ID`, and `OAUTH2_CLIENT_SECRET` for Miniflux (`miniflux`; DB password must match `miniflux-db`). |
| `homepage-miniflux-widget.yaml` | `homepage` | Miniflux API key for Homepage widget via env `HOMEPAGE_VAR_MINIFLUX_API_KEY` ([widget](https://gethomepage.dev/widgets/services/miniflux/)). |
| `homepage-homeassistant-widget.yaml` | `homepage` | Home Assistant long-lived access token for Homepage widget via env `HOMEPAGE_VAR_HOMEASSISTANT_TOKEN` ([widget](https://gethomepage.dev/widgets/services/homeassistant/)); used on the **Home Assistant** HTTPRoute tile. |
| `mealie-db.yaml` | `mealie` | CNPG bootstrap (`mealie-db`, keys `username`, `password`; owner/database `mealie` in `apps/mealie/postgres.yaml`). |
| `mealie.yaml` | `mealie` | `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET` for Mealie Authentik OIDC (`mealie`). |
| `grafana-admin.yaml` | `monitoring` | Grafana admin login (`grafana-admin`, keys `admin-user`, `admin-password`) for kube-prometheus-stack. See `apps/monitoring/README.md`. |
| `grafana-oidc.yaml` | `monitoring` | Authentik Generic OAuth (`grafana-oidc`, keys `client_id`, `client_secret`). See `apps/monitoring/README.md`. |
| `home-assistant.yaml` | `home-assistant` | Authentik OIDC for [hass-oidc-auth](https://github.com/christiaangoossens/hass-oidc-auth) (`OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`). See `apps/home-assistant/README.md`. |
| `grafana-db.yaml` | `monitoring` | CNPG bootstrap (`grafana-db`, keys `username`, `password`; owner/database `grafana` in `apps/monitoring/postgres.yaml`). |
| `unpoller.yaml` | `unpoller` | UniFi API (`unpoller-unifi`, keys `unifi-url`, `unifi-user`, `password`). See `apps/unpoller/README.md`. |
