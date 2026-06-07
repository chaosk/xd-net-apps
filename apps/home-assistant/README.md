# Home Assistant

Deploys [Home Assistant Container](https://www.home-assistant.io/installation/) with the **bjw-s app-template** chart, Synology-backed config storage, Gateway API ingress, and **Authentik OIDC** via [hass-oidc-auth](https://github.com/christiaangoossens/hass-oidc-auth).

Zigbee/USB hardware is not wired in this manifest — add a coordinator via MQTT (Zigbee2MQTT) or revisit once you know what radios you need.

## HACS

An init container installs **[HACS](https://hacs.xyz/)** (**2.0.5**) into **`/config/custom_components/hacs`** on each pod start when Home Assistant has been onboarded (`.HA_VERSION` exists). Bump **`HACS_VERSION`** in **`hacs-install.yaml`** to upgrade.

**After sync (or first restart post-onboarding):**

1. Enable **Advanced mode** on your HA user profile.
2. **Settings → Devices & services → Add integration → HACS** — accept the warnings.
3. Complete **GitHub device login** at [github.com/login/device](https://github.com/login/device).
4. HACS appears in the sidebar; install custom integrations, cards, and themes from there.

If HACS is missing after deploy, finish the HA onboarding wizard first, then restart the pod so the init container can write the component.

## Matter

The pod runs **[python-matter-server](https://github.com/home-assistant-libs/python-matter-server)** as a sidecar (port **5580**, fabric data on **`home-assistant-matter`** PVC). It shares the pod network namespace with Home Assistant, including Multus **`net1`**, so Matter/mDNS traffic uses the IoT LAN.

**After sync:**

1. Confirm **`net1`** is configured in HA (**Settings → System → Network**).
2. **Settings → Devices & services → Add integration → Matter** — use **`ws://127.0.0.1:5580/ws`** if auto-discovery does not appear.
3. Commission devices with a **setup code** or QR (BLE commissioning is not wired; no host Bluetooth passthrough).

For **Thread** devices via a border router (e.g. HomePod on **192.168.2.0/24**), worker nodes need IPv6 Router Advertisement acceptance on the IoT NIC (**`ens19`** in **xd-net**). Wi‑Fi Matter on **192.168.2.x** usually works once **`net1`** is up.

**Aqara Hub M2 (Matter bridge):** firmware **4.0+**, enable Matter in the Aqara Home app, then add the bridge through the Matter integration. HomeKit Controller still exposes more entities on the M2 if you prefer that path instead.

## LAN macvlan (HomeKit / mDNS / local IoT)

| Subnet | Role |
|--------|------|
| **192.168.0.0/24** | Users — reach HA via **`https://homeassistant.net.ecksd.ee`** (Cilium/Envoy), not macvlan |
| **192.168.2.0/24** | IoT with internet (HomePod, Apple TV) — **HA `net1` lives here** |
| **192.168.4.0/24** | Compute (Talos nodes, cluster) — primary pod NIC stays on Cilium |
| **192.168.6.0/24** | Isolated IoT — **`net1` route only** (UniFi must allow **192.168.2 → 192.168.6**) |

Home Assistant gets a **second NIC** on **192.168.2.0/24** via [Multus](https://github.com/k8snetworkplumbingwg/multus-cni) **macvlan** (`macvlan-network.yaml`, pod annotation in `values.yaml`). That puts it on the same L2 as HomeKit targets. Reachability to **192.168.6.0/24** is handled in the NAD by **`ipam.routes`** plus the CNI **`sbr`** plugin (policy routing from **`net1`** — check with `ip rule` / `ip route show table 100` in the pod).

**Platform prerequisites ([xd-net](https://github.com/chaosk/xd-net)):**

1. **`apps/`** — `multus_enabled = true` (Multus + `cni.exclusive=false`, includes **macvlan** and **sbr** binaries). See **`apps/multus.tf`**.
2. **`infra/`** — workers get a **second Proxmox NIC** on **`worker_iot_vlan_id`** (default **2** / 192.168.2.0/24) and Talos **`ens19`** with no address (`patches/worker-iot-nic.yaml`).

The namespace uses **`pod-security: privileged`** because the OIDC init container runs as root to write the config PVC.

**After sync:**

1. In HA: **Settings → System → Network** — enable **Advanced mode**, configure **`net1`** (192.168.2.x), leave **Home Assistant URL** as `https://homeassistant.net.ecksd.ee`.
2. Restart HA if **`net1`** does not appear (usually means **`ens19`** parent missing on the scheduled worker).

Edit **`macvlan-network.yaml`** for **`master`**, **`subnet`**, **`rangeStart`/`rangeEnd`** (default **192.168.2.220–229**), gateway **192.168.2.1**, and the **192.168.6.0/24** route.

## Access

- Host: `https://homeassistant.net.ecksd.ee` (Gateway API via shared cluster Gateway; TLS covered by **`*.net.ecksd.ee`**)

## Before sync

1. **Secret `home-assistant`** — Authentik provider slug **`home-assistant`** (redirect **`https://homeassistant.net.ecksd.ee/auth/oidc/callback`**) is configured in Authentik; client credentials live in **`secrets/home-assistant.yaml`**. Commit and sync **platform-secrets** before expecting OIDC to activate ([`secrets/README.md`](../../secrets/README.md)).

## First-time setup order

1. Deploy the app (without OIDC credentials the init container only installs the custom component).
2. Open **`https://homeassistant.net.ecksd.ee`**, complete the **onboarding wizard** (creates `configuration.yaml`).
3. **Restart** the Home Assistant pod so the init container writes **`oidc/http.yaml`** (Envoy reverse proxy) and, once the secret is synced, **`auth_oidc`** config.
4. Commit/push **`secrets/home-assistant.yaml`** and sync **platform-secrets** if not already done.
5. **Restart** again if the secret appeared after the first restart, so OIDC YAML is written.
6. Sign in via **Authentik** at **`https://homeassistant.net.ecksd.ee/auth/oidc/welcome`** (hass-oidc-auth’s documented entry point; **`/`** may show “Login aborted” until upstream improves that flow). With **`default_redirect`**, the welcome page sends you straight to Authentik on desktop.

Set **Settings → System → Network → Home Assistant URL** to `https://homeassistant.net.ecksd.ee`.

**Homepage widget (optional)** — generate a **long-lived access token** in HA (**Profile → Security**). Put it in **`secrets/homepage-homeassistant-widget.yaml`** as `HOMEPAGE_VAR_HOMEASSISTANT_TOKEN`, SOPS-encrypt, sync **platform-secrets**, and restart Homepage if the widget was already deployed.

## Layout

| File | Purpose |
|------|---------|
| `namespace.yaml` | **`home-assistant`** namespace (`pod-security: privileged`) |
| `pvc.yaml` | Config volume on Synology (`/config`, **10Gi**) |
| `pvc-matter.yaml` | Matter fabric storage on Synology (`/data`, **2Gi**) |
| `values.yaml` | HA + **python-matter-server** sidecar, probes, Multus annotation |
| `authentik-oidc-install.yaml` | Init script: **hass-oidc-auth** + OIDC YAML |
| `hacs-install.yaml` | Init script: **HACS** custom component |
| `macvlan-network.yaml` | Multus NAD — **192.168.2.0/24** macvlan on worker **`ens19`**, route to **192.168.6.0/24** |
| `httproute.yaml` | `homeassistant.net.ecksd.ee` + Homepage discovery |

## Apply (local test)

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/home-assistant" --enable-helm | kubectl apply -f -
```

The Deployment uses **Recreate** strategy (single replica, RWO PVC). First boot can take a few minutes before port **8123** listens.

## Image updates

**Argo CD Image Updater** (`apps/argocd-image-updater/image-updater.yaml`, `home-assistant` entry) tracks **`ghcr.io/home-assistant/home-assistant`** release tags (`YYYY.M.P`, no beta/dev) and **`python-matter-server`** semver **`6.x.y`**, writing bumps to `values.yaml`. The first bot commit replaces **`stable`** with a pinned release tag.

Manual override: set **`controllers.main.containers.main.image.tag`** (and **`matter-server`** if needed) in `values.yaml`. See [GitHub packages](https://github.com/home-assistant/core/pkgs/container/home-assistant) for release notes before merging updater commits.
