# Bambuddy

Self-hosted [BamBuddy](https://github.com/maziggy/bambuddy) command center for Bambu Lab printers — Gateway UI, Synology-backed storage, and **Multus macvlan** on **192.168.2.0/24** for local printer control (developer mode / LAN MQTT and FTP).

Home Assistant uses the **[hacs_bambuddy](https://github.com/Spegeli/hacs_bambuddy)** custom component (installed by the home-assistant init container) pointing at the in-cluster service.

## Access

- Host: `https://bambuddy.net.ecksd.ee` (Gateway API; TLS via **`*.net.ecksd.ee`**)
- In-cluster API: `http://bambuddy.bambuddy.svc.cluster.local:8000`

Sign in with **OpenID Connect** (Authentik) after the provider is configured in the BamBuddy UI. Envoy forward auth is **not** used — BamBuddy has built-in OIDC (WebSockets and in-cluster API keys stay unaffected).

## LAN macvlan

| Item | Value |
|------|--------|
| NAD | `lan-macvlan` (same **`ens19`** parent as Home Assistant) |
| IP pool | **192.168.2.220–224** (HA uses **.210–219**) |
| Route | **192.168.6.0/24** via **192.168.2.1** (isolated IoT printers) |

Printers must be reachable from **`net1`**. Add printers **by IP** in the BamBuddy UI if SSDP discovery does not find them (common in Kubernetes bridge/macvlan setups).

**Platform prerequisites:** Multus + worker **`ens19`** on VLAN 2 — same as [`apps/home-assistant/`](../home-assistant/README.md).

## Before sync

No Kubernetes secret is required for OIDC — BamBuddy stores the IdP client credentials in its database (encrypted when **`MFA_ENCRYPTION_KEY`** is set). Create the Authentik provider first so you can paste the client ID and secret during first-run setup.

1. **Authentik OIDC** — create an **OAuth2/OpenID Provider** with slug **`bambuddy`**, client type **confidential**, grant types **`authorization_code`** and **`refresh_token`**, and redirect URI **`https://bambuddy.net.ecksd.ee/api/v1/auth/oidc/callback`** (strict). Attach an **Application** so users can sign in. Issuer URL for BamBuddy: **`https://authentik.net.ecksd.ee/application/o/bambuddy/`** (trailing slash is fine; BamBuddy normalises it). Swap the default **`email`** scope mapping for a custom one that sets **`email_verified: True`** — BamBuddy requires verified emails for OIDC login ([Authentik docs](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/#email-scope-verification)). See [`apps/authentik/README.md`](../authentik/README.md).

## First-time setup

1. Sync the app (Argo or `kubectl kustomize … --enable-helm | kubectl apply -f -`).
2. Open **`https://bambuddy.net.ecksd.ee`**, create the local admin account (required before SSO can be configured).
3. **Settings → Authentication → SSO / OIDC** — add provider **Authentik**: issuer **`https://authentik.net.ecksd.ee/application/o/bambuddy/`**, client ID and secret from step 1 above, scopes **`openid email profile`**, **Enabled**. For the admin you just created, turn on **Auto-link existing accounts** (email must match Authentik) or sign in locally once and link manually; for other users, enable **Auto-create users** if you want Authentik-only onboarding.
4. **Settings → Printers** — add each Bambu printer by IP (developer mode / access code).
5. **Settings → API Keys** — create a key for Home Assistant (in-cluster traffic uses the API key, not OIDC).
6. In HA: **Settings → Devices & services → Add integration → BamBuddy** — host `http://bambuddy.bambuddy.svc.cluster.local`, port **8000**, API key from step 5. Configure printers via the integration wrench menu.

Optional: embed BamBuddy in HA with a **Webpage** dashboard panel — `TRUSTED_FRAME_ORIGINS` includes **`https://homeassistant.net.ecksd.ee`**.

## Layout

| File | Purpose |
|------|---------|
| `namespace.yaml` | **`bambuddy`** namespace |
| `pvc.yaml` | **`/app/data`** (10Gi) and **`/app/logs`** (2Gi) on Synology |
| `values.yaml` | Official image, probes, macvlan annotation, `NET_BIND_SERVICE` |
| `macvlan-network.yaml` | Multus NAD — **192.168.2.220–224** |
| `httproute.yaml` | `bambuddy.net.ecksd.ee` + Homepage tile |

Virtual printer / slicer sidecars and extra port ranges are not wired here — see [BamBuddy Docker docs](https://wiki.bambuddy.cool/getting-started/docker/) if you need VP or OrcaSlicer API.

## Apply (local test)

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/bambuddy" --enable-helm | kubectl apply -f -
```

## Image updates

**Argo CD Image Updater** tracks **`ghcr.io/maziggy/bambuddy`** with **`newest-build`** (not semver) in `apps/argocd-image-updater/image-updater.yaml`. GHCR tags omit the **`v`** prefix used on GitHub releases (image **`0.2.4.5`**, not **`v0.2.4.5`**), and only **four-part** release tags are considered — semver would misread **`0.2.4.5`** as an older prerelease of **`0.2.4`**. Manual bump: **`controllers.main.containers.main.image.tag`** in `values.yaml`.
