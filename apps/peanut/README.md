# PeaNUT

In-cluster [PeaNUT](https://github.com/Brandawg93/PeaNUT) UI for Synology NUT on **`nas.net.ecksd.ee:3493`**. Prometheus scrapes `/api/v1/metrics`; Grafana dashboard in **`apps/monitoring`** (folder **Misc**).

## Synology NUT

1. UPS on USB to the NAS
2. **Control Panel → Hardware & Power → UPS** — enable UPS support and **Enable network UPS server**
3. **Permitted Synology NAS devices** — allow the **peanut** pod IP (or pod CIDR)
4. NUT credentials from `/usr/syno/etc/ups/upsd.users` on the NAS

## Secrets

**`secrets/peanut.yaml`** — `USERNAME` / `PASSWORD` in `settings.yml`; SOPS-encrypt and sync **platform-secrets**.

After sync, enable **Prometheus** in PeaNUT **Settings** and allow in-cluster scrapes (`10.0.0.0/8`).

## Access

- UI: `https://peanut.net.ecksd.ee` (Gateway `shared`, Authentik forward-auth; Management group on Homepage)
- In-cluster: `http://peanut.peanut.svc.cluster.local:8080` (no forward auth — Prometheus and Homepage widget)

Forward auth needs **authentik** applied first (ReferenceGrant **`forward-auth-peanut`** and outpost route). Domain-level Proxy provider on **`net.ecksd.ee`** covers this hostname; see **`apps/authentik/README.md`**.

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, PVC, Helm `app-template`, HTTPRoute, SecurityPolicy, ServiceMonitor |
| `values.yaml` | PeaNUT container, PVC `/config`, init seeds `settings.yml` from Secret |
| `pvc.yaml` | `peanut-config` on `synology` |
| `httproute.yaml` | `peanut.net.ecksd.ee` + outpost path + Homepage widget |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik |
| `servicemonitor.yaml` | `/api/v1/metrics` for kube-prometheus-stack |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/peanut" --enable-helm | kubectl apply -f -
```

**Argo CD Image Updater** tracks `docker.io/brandawg93/peanut` in `apps/argocd-image-updater/image-updater.yaml`.

Verify: `kubectl logs -n peanut deploy/peanut -c main`; Prometheus target **`peanut`** or Grafana **Misc → PeaNUT**.
