# Authentik

[Authentik](https://goauthentik.io/) is an open-source identity provider (SSO, OIDC, SAML, LDAP, and more). This app deploys it with the **official Helm chart** from [`oci://ghcr.io/goauthentik/helm-charts`](https://github.com/goauthentik/helm), following the [Kubernetes installation documentation](https://docs.goauthentik.io/docs/installation/kubernetes/).

PostgreSQL is a **[CloudNativePG](https://cloudnative-pg.io/) `Cluster`** (`postgres.yaml`) in the `authentik` namespace. The operator is installed from **xd-net** (`apps/postgres-operator.tf`, namespace `cnpg-system` by default).

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, **`postgres.yaml`**, **`pvc-authentik-data.yaml`**, **`httproute-pangolin.yaml`**, Helm chart `authentik`. |
| `namespace.yaml` | `authentik` namespace. |
| `postgres.yaml` | CNPG cluster **`authentik-db`** (single instance, **`local-path`** PVC, stock `postgresql` image). |
| `pvc-authentik-data.yaml` | **`authentik-data`** PVC (**Synology** `storageClass` **`synology`**, **ReadWriteOnce**, **1Gi**) at **`/data`**. Server and worker are pinned to the same node via **`worker` podAffinity** in `values.yaml`. |
| `referencegrant-forward-auth.yaml` | Shared **ReferenceGrant**: each app namespace with a forward-auth **SecurityPolicy** is listed under **`spec.from`**; all policies may call **`authentik-server`**. |
| `values.yaml` | **`global.volumes`** / **`volumeMounts`** for `/data`, `AUTHENTIK_HOST`, **`AUTHENTIK_SECRET_KEY`**, Gateway **`server.route.main`** (includes `/outpost.goauthentik.io`), external Postgres, **GeoIP**, Bitnami **disabled**, **memory requests/limits**. |
| `httproute-pangolin.yaml` | **`auth.ecksd.ee`** only; **`pangolin-operator/site-ref: xd-net`** (separate from Helm route so Pangolin gets one public resource). |

## Resources

Set in `values.yaml` and `postgres.yaml` from `kubectl top` (server ~450Mi, worker ~460Mi, CNPG ~330Mi). Server and worker were **BestEffort** before this and were OOM-killed on busy nodes.

| Component | Request | Limit |
|-----------|---------|-------|
| `server` | 512Mi | 1Gi |
| `worker` | 512Mi | 1Gi |
| GeoIP sidecar | 64Mi | 256Mi |
| `authentik-db` (CNPG) | 384Mi | 768Mi |

## Before you apply

1. **Secret `authentik-secret-key`** (namespace **`authentik`**) — Authentik **`secret_key`** (cookie signing, etc.). Generate once, e.g. `openssl rand -base64 48`, put it in key **`secret_key`**, SOPS-encrypt the file under `secrets/` ([`secrets/README.md`](../../secrets/README.md)). **Do not change** after the first production install unless you intend to invalidate sessions.

2. **`AUTHENTIK_HOST`** and **`server.route.main.hostnames`** in `values.yaml` — both must describe the **public HTTPS URL** users use (scheme + host, no path). Change `authentik.net.ecksd.ee` to your real hostname and keep them aligned.

3. **Secret `authentik-db`** in namespace **`authentik`** — required **before** the CNPG cluster can bootstrap. It must contain:

   | Key | Value |
   |-----|--------|
   | `username` | `authentik` (must match `bootstrap.initdb.owner` in `postgres.yaml`) |
   | `password` | Strong password; same value is read by Authentik via `global.env` (`AUTHENTIK_POSTGRESQL__PASSWORD`) |

   Create it under `secrets/` with **`metadata.namespace: authentik`**, then **SOPS-encrypt** and commit ([`secrets/README.md`](../../secrets/README.md)). The Argo CD **platform-secrets** app must sync this file so the Secret exists when the `Cluster` reconciles.

4. **Secret `authentik-geoip`** (namespace **`authentik`**) — required for **`geoip.enabled: true`**. Create a [MaxMind GeoLite2](https://www.maxmind.com/en/geolite2/signup) account and add a Secret with keys **`account_id`** and **`license_key`** (see [GeoIP](https://docs.goauthentik.io/sys-mgmt/ops/geoip/)). The chart mounts the GeoIP updater sidecar on server and worker; databases land under **`/geoip`** and Authentik reloads when files change. Encrypt with **SOPS** under `secrets/` like the other secrets.

5. **Pangolin** — **`NewtSite`** **`xd-net`** (xd-net). **`httproute-pangolin.yaml`** is the only route with **`site-ref`**; do not add Pangolin annotations on the Helm HTTPRoute or you will get duplicate public resources. Point **`auth.ecksd.ee`** DNS at the Pangolin edge (not the homelab Gateway LB). Homelab stays on **`authentik.net.ecksd.ee`**; **`AUTHENTIK_HOST`** in `values.yaml` still targets that URL. If logins over Pangolin redirect to the wrong host, set **`AUTHENTIK_HOST`** to **`https://auth.ecksd.ee`** or add an Authentik **Brand** for **`auth.ecksd.ee`**. Forward-auth providers scoped to **`net.ecksd.ee`** do not apply to **`auth.ecksd.ee`**; homelab apps keep using **`authentik.net.ecksd.ee`** for the outpost.

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/authentik" --enable-helm | kubectl apply -f -
```

The Authentik chart no longer pulls Bitnami PostgreSQL (`postgresql.enabled: false`).

## Forward auth (Envoy Gateway)

Two mechanisms work together:

1. **HTTPRoute** — On each protected app hostname and on **`authentik.net.ecksd.ee`**, paths under **`/outpost.goauthentik.io`** go to **`authentik-server`** (browser callbacks and outpost UI). App routes list this rule **before** the catch-all **`/`** rule to the app Service.
2. **SecurityPolicy** — Envoy calls **`authentik-server`** in-cluster at **`/outpost.goauthentik.io/auth/envoy`** to allow or deny each request before it reaches the app.

Each protected app ships **`securitypolicy-forward-auth.yaml`** and the outpost rule on its **HTTPRoute**. This app supplies the shared **ReferenceGrant** (for both **SecurityPolicy** and cross-namespace **HTTPRoute** backend refs) and **`additionalRules`** on the Authentik chart route in `values.yaml`.

To protect another app: copy Sonarr’s **SecurityPolicy** and outpost **HTTPRoute** rule, add **`spec.from`** entries for that namespace in **`referencegrant-forward-auth.yaml`**, re-apply **authentik** then the app. In the Authentik UI, one **domain-level** forward-auth **Proxy provider** (cookie domain **`net.ecksd.ee`**) on the **embedded outpost** is usually enough for all `*.net.ecksd.ee` hostnames; **single-application** providers require the outpost path on that app’s hostname as above.

## Argo CD (Dex OIDC)

Argo CD lives in **xd-net** Terraform (`apps/modules/argocd`), not under `apps/argocd/` here. Login uses **bundled Dex** with an **OIDC connector** to Authentik ([integration guide](https://integrations.goauthentik.io/infrastructure/argocd/)), not Envoy forward auth.

In Authentik: **OAuth2/OpenID Provider** slug **`argocd`**, redirect URIs **`https://argocd.net.ecksd.ee/api/dex/callback`** and **`https://localhost:8085/auth/callback`** (strict), grant types **`authorization_code`** and **`refresh_token`**, authentication flow **Welcome to authentik!**, plus scope mappings for **`profile`** (name/username only — do not use the default profile mapping, it embeds all groups) and **`groups`** (only **`ArgoCD Admins`** / **`ArgoCD Viewers`**). Put users in those groups for **`role:admin`** / **`role:readonly`** in Argo CD.

In **xd-net** `config.auto.tfvars` (gitignored): set **`argocd_oidc_issuer`**, **`argocd_oidc_client_id`**, **`argocd_oidc_client_secret`**, and **`argocd_rbac_policy_csv`**, then `terraform apply` in **`apps/`**. The UI shows **Log in via Authentik**; the CLI can use the same Dex flow.

## Grafana (Generic OAuth)

Grafana uses native **Generic OAuth** in `apps/monitoring/values-prometheus.yaml`, not forward auth. Authentik provider slug **`grafana`**, redirect URI **`https://grafana.net.ecksd.ee/login/generic_oauth`**, grant types **`authorization_code`** and **`refresh_token`**, plus scoped **`profile`** (no groups) and **`groups`** mappings (**`Grafana Admins`** / **`Grafana Editors`** only). Credentials live in **`secrets/grafana-oidc.yaml`**. See `apps/monitoring/README.md`.

## Client IP in audit events

Authentik reads the client address from **`X-Forwarded-For`** when the request comes from a [trusted proxy network](https://docs.goauthentik.io/install-config/reverse-proxy/) (private ranges including **`10.0.0.0/8`** are trusted by default). OAuth and login traffic hits **`authentik-server`** through Envoy Gateway; if the gateway SNATs ingress (**`externalTrafficPolicy: Cluster`**) or does not append the real client to **`X-Forwarded-For`**, events show the Envoy pod IP (**`10.244.x.x`**) instead of the browser.

Fix at the gateway (xd-net): apply **`ClientTrafficPolicy`** **`client-ip-detection`** on the shared Gateway and, when Cilium L2 allows, set **`envoy_proxy_external_traffic_policy = "Local"`** so the dataplane sees the real LAN client. For **`auth.ecksd.ee`** via Pangolin, increase **`gateway_xff_num_trusted_hops`** if the edge already sends **`X-Forwarded-For`**. No Authentik env change is required unless the proxy connects from a public IP outside the default trusted CIDRs.

## After install

Complete the **initial setup wizard** at your public URL. See [Post-installation](https://docs.goauthentik.io/docs/installation/post-install/) in the Authentik docs.

## Upgrades

Bump `helmCharts.version` in `kustomization.yaml` to match a published chart tag from [goauthentik/helm releases](https://github.com/goauthentik/helm/releases), then re-apply. Read upstream release notes for breaking changes.
