# Invidious

[Invidious](https://invidious.io/) (privacy-friendly YouTube frontend) via bjw-s `app-template` and CNPG PostgreSQL, exposed on the homelab Gateway with **Authentik forward auth**.

Modern Invidious cannot fetch streams on its own — the **`invidious-companion`** service is mandatory for playback. It runs as a second controller in the same release; the web container talks to it over in-cluster DNS, and the two share a 16-character secret key.

## Access

- Host: `https://invidious.net.ecksd.ee` (Gateway API via shared cluster Gateway), or the **Invidious** tile on Homepage.

**Authentik** prompts for login (same domain-level forward-auth provider as other `*.net.ecksd.ee` apps — see `apps/authentik/README.md`). Forward auth also covers `/companion`; an authenticated browser passes its cookie, so playback works. Forward auth needs **authentik** applied first (its `ReferenceGrant` set includes `invidious`).

## Before sync

1. **Secret `invidious-db`** in namespace **`invidious`** — CNPG bootstrap (`postgres.yaml`). Keys: `username` (`invidious`), `password`. See [`secrets/invidious-db.yaml`](../../secrets/invidious-db.yaml).

2. **Secret `invidious`** in namespace **`invidious`** — app secrets injected as `INVIDIOUS_*` env (`values.yaml`):
   - `database_url` — `postgres://invidious:<password>@invidious-db-rw:5432/invidious?sslmode=disable` (password must match `invidious-db`).
   - `hmac_key` — random signing key.
   - `companion_key` — **exactly 16 characters** (`pwgen 16 1`), different from `hmac_key`. Stored once and wired into both containers (web `INVIDIOUS_INVIDIOUS_COMPANION_KEY` and companion `SERVER_SECRET_KEY`) so the two copies cannot drift.

   The committed files are **placeholders**. Fill real values, then encrypt and sync **platform-secrets** before the CNPG cluster and app start ([`secrets/README.md`](../../secrets/README.md)):

   ```bash
   sops --encrypt --in-place secrets/invidious-db.yaml
   sops --encrypt --in-place secrets/invidious.yaml
   ```

3. **platform-secrets** (in **xd-net**) must include the new **`invidious`** namespace so the SOPS secrets sync.

4. **Authentik** — create a **Proxy provider** for `invidious.net.ecksd.ee` and add it to the embedded outpost (same as other forward-auth apps), so `securitypolicy-forward-auth.yaml` succeeds.

## Configuration

Only non-secret settings live in `INVIDIOUS_CONFIG` in `values.yaml`. Invidious overrides any **top-level** config key from an env var named `INVIDIOUS_<UPPERCASED_KEY>`, so the DB connection (`INVIDIOUS_DATABASE_URL`), `hmac_key`, and the companion key come from the `invidious` Secret instead of the plaintext config. `check_tables: true` builds the schema on first start against the empty CNPG database — no SQL files to mount.

## Layout

| File | Purpose |
|------|---------|
| `namespace.yaml` | `invidious` namespace |
| `postgres.yaml` | CNPG cluster `invidious-db` on `local-path` (5Gi) |
| `values.yaml` | `invidious` web + `invidious-companion` controllers, probes, non-secret `INVIDIOUS_CONFIG`, secret env |
| `service-companion.yaml` | **Service** (`invidious-companion:8282`) for the companion controller |
| `httproute.yaml` | `invidious.net.ecksd.ee`; `/` → web, `/companion` → companion; Authentik outpost path + Homepage tile |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik for this HTTPRoute |
| `restart-cronjob.yaml` | Daily rollout-restart of the web + companion deployments (refreshes YouTube session/po-token state) |

The companion runs read-only and non-root (uid 10001) with an `emptyDir` cache at `/var/tmp/youtubei.js`. Image tags follow upstream date-stamped builds (e.g. `2025.09.29-0065a3e`) and are auto-bumped in lockstep by Argo CD Image Updater (`newest-build`); pin `controllers.main.containers.main.image.tag` / `controllers.companion.containers.main.image.tag` in `values.yaml` to override.

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/invidious" --enable-helm | kubectl apply -f -
```

Wait for **`invidious-db`** to report ready before the app pod stays healthy. If playback breaks between the daily restarts as YouTube rotates tokens, raise the CronJob cadence in `restart-cronjob.yaml` (upstream suggests up to hourly).
