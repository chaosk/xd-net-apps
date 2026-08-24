# Spoolman

[Spoolman](https://github.com/Donkie/Spoolman) filament spool inventory via bjw-s `app-template` and `ghcr.io/donkie/spoolman`. SQLite database on Synology PVC at `/home/app/.local/share/spoolman`.

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, data PVC, HTTPRoute, Helm chart. |
| `pvc.yaml` | SQLite data on StorageClass `synology` (2Gi). |
| `values.yaml` | Image, probes, data mount (path must stay as upstream expects). |
| `httproute.yaml` | `spoolman.net.ecksd.ee` via Gateway `shared`. |
| `securitypolicy-forward-auth.yaml` | Envoy Gateway forward auth to Authentik for this HTTPRoute. |

Forward auth applies only to browser traffic on the public hostname. BamBuddy and Moonraker should use the in-cluster API URL — that path does not go through the Gateway. Forward auth needs **authentik** applied first (shared **ReferenceGrant** and outpost route). See **`apps/authentik/README.md`**.

## Access

- UI: `https://spoolman.net.ecksd.ee` (Authentik)
- In-cluster API: `http://spoolman.spoolman.svc.cluster.local:8000` (no forward auth)

## Printer integration

In Moonraker or BamBuddy, point Spoolman at the in-cluster URL. Example Moonraker `[spoolman]` block:

```ini
[spoolman]
server: http://spoolman.spoolman.svc.cluster.local:8000
sync_rate: 5
```

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/spoolman" --enable-helm | kubectl apply -f -
```

**Argo CD Image Updater** tracks `ghcr.io/donkie/spoolman` in `apps/argocd-image-updater/image-updater.yaml`.
