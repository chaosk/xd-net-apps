# Authentik

[Authentik](https://goauthentik.io/) is an open-source identity provider (SSO, OIDC, SAML, LDAP, and more). This app deploys it with the **official Helm chart** from [`oci://ghcr.io/goauthentik/helm-charts`](https://github.com/goauthentik/helm), following the [Kubernetes installation documentation](https://docs.goauthentik.io/docs/installation/kubernetes/).

PostgreSQL is a **[CloudNativePG](https://cloudnative-pg.io/) `Cluster`** (`postgres.yaml`) in the `authentik` namespace. The operator is installed from **xd-net** (`apps/postgres-operator.tf`, namespace `cnpg-system` by default).

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, **`postgres.yaml`**, **`pvc-authentik-data.yaml`**, Helm chart `authentik`. |
| `namespace.yaml` | `authentik` namespace. |
| `postgres.yaml` | CNPG cluster **`authentik-db`** (single instance, **`local-path`** PVC, stock `postgresql` image). |
| `pvc-authentik-data.yaml` | **`authentik-data`** PVC (**Synology** `storageClass` **`synology`**, **ReadWriteOnce**, **1Gi**) at **`/data`**. Server and worker are pinned to the same node via **`worker` podAffinity** in `values.yaml`. |
| `values.yaml` | **`global.volumes`** / **`volumeMounts`** for `/data`, `AUTHENTIK_HOST`, **`AUTHENTIK_SECRET_KEY`**, Gateway **`server.route.main`**, external Postgres, **GeoIP**, Bitnami **disabled**. |

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

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/authentik" --enable-helm | kubectl apply -f -
```

The Authentik chart no longer pulls Bitnami PostgreSQL (`postgresql.enabled: false`).

## After install

Complete the **initial setup wizard** at your public URL. See [Post-installation](https://docs.goauthentik.io/docs/installation/post-install/) in the Authentik docs.

## Upgrades

Bump `helmCharts.version` in `kustomization.yaml` to match a published chart tag from [goauthentik/helm releases](https://github.com/goauthentik/helm/releases), then re-apply. Read upstream release notes for breaking changes.
