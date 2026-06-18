# Zilean

[DMM hashlist indexer](https://github.com/Thoroslives/zilean) (Thoroslives fork) via bjw-s `app-template` and CNPG PostgreSQL. Consumed by Prowlarr as a custom indexer; the **web dashboard** is exposed on the homelab Gateway with **Authentik forward auth**. Outbound traffic (DMM sync) uses **[pod-gateway](../vpn-gateway/README.md)** + Gluetun; PostgreSQL stays on normal cluster routing.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, PVC, CNPG, HTTPRoute, forward auth, Helm chart. |
| `namespace.yaml` | `allows-vpn-gateway: "true"`, PSA `privileged`. |
| `pvc-data.yaml` | App data on StorageClass `synology` (20Gi; DMM hashlists + IMDB title file need several GB). |
| `postgres.yaml` | CNPG cluster `zilean-db` on `local-path` (20Gi). |
| `values.yaml` | Image, probes, DB env, dashboard enabled, mount at `/app/data`, pod label `vpn-gateway: "true"`. |
| `httproute.yaml` | `zilean.net.ecksd.ee` via Gateway `shared`; Authentik outpost path. |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik for this HTTPRoute. |

Forward auth needs **authentik** applied first (shared **ReferenceGrant** includes `zilean`). See **`apps/authentik/README.md`**.

## VPN

- Namespace label **`allows-vpn-gateway: "true"`** and PSA **`privileged`** (`namespace.yaml`)
- Pod label **`vpn-gateway: "true"`** (`values.yaml` → `defaultPodOptions.labels`)
- **`zilean`** in `routed_namespaces` in `apps/vpn-gateway/values-pod-gateway.yaml`

Apply **vpn-gateway** first if you changed `routed_namespaces`, then recreate the Zilean pod. CNPG (`zilean-db-rw`) has no VPN label.

## Before sync

**Secret `zilean-db`** in namespace **`zilean`** — CNPG bootstrap and Zilean `POSTGRES_*` env vars. Keys: `username` (`zilean`), `password` (random, `# sops:encrypt`). Encrypt with **SOPS** and sync **platform-secrets** before the CNPG cluster and app start. See [`secrets/README.md`](../../secrets/README.md).

If migrating from the old `prowlarr` namespace layout, recreate or move the secret into **`zilean`** before applying this app.

## Dashboard access

After Argo syncs **zilean** and **authentik**:

1. Open **`https://zilean.net.ecksd.ee`** (or the **Zilean** tile on Homepage).
2. **Authentik** prompts for login (same domain-level forward-auth provider as other `*.net.ecksd.ee` apps — see `apps/authentik/README.md`).
3. The Zilean UI asks for its **API key**. Read it from the app data volume (generated on first start into `settings.json`):

   ```bash
   kubectl exec -n zilean deploy/zilean -c main -- cat /app/data/settings.json \
     | jq -r '.Zilean.ApiKey'
   ```

   Paste that key into the dashboard login. The browser keeps it for later visits.

**In-cluster only:** Prowlarr and other *arr apps still reach Torznab at `http://zilean.zilean.svc.cluster.local:8181` without going through the Gateway or Authentik.

Dashboard is enabled with **`Zilean__EnableDashboard=true`** in `values.yaml`. If the UI stays unavailable after a pod restart, confirm `/app/data/settings.json` has `"EnableDashboard": true` or delete `settings.json` and let Zilean recreate it (you will need the new API key from the regenerated file).

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/zilean" --enable-helm | kubectl apply -f -
```

Prowlarr reaches Zilean via **Generic Torznab** at `http://zilean.zilean.svc.cluster.local:8181/torznab` (API path `/api`; see `apps/prowlarr/README.md`). First DMM sync can take a long time and use significant CPU/memory; see the [fork README](https://github.com/Thoroslives/zilean).

Pin the image `tag` in `values.yaml` when upgrading.
