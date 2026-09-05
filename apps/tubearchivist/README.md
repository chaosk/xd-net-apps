# Tube Archivist

[Tube Archivist](https://www.tubearchivist.com/) — official Docker stack (Tube Archivist, Redis, Elasticsearch 8) on Kubernetes with Gateway API and **Authentik forward-auth**.

## Access

- Host: `https://tubearchivist.net.ecksd.ee` (Gateway `shared`)

Forward auth needs **authentik** applied first. **`TA_AUTH_PROXY_LOGOUT_URL`** points at Authentik. After first forward-auth login, grant admin in **Settings → User** using local **`TA_USERNAME`** / **`TA_PASSWORD`**.

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, PVCs, ES, Redis, bgutil, Deployment, Service, HTTPRoute |
| `namespace.yaml` | **`tubearchivist`**; Pod Security **`privileged`** (pod-gateway `NET_ADMIN`/`NET_RAW` + Elasticsearch privileged sysctl / `IPC_LOCK`) |
| `pvc.yaml` | **`tubearchivist-youtube`**: NFS RWX (`Retain`); cache/redis/es on **`synology`** |
| `elasticsearch.yaml` | **`archivist-es`** StatefulSet + Service (port 9200) |
| `redis.yaml` | **`archivist-redis`** StatefulSet + Service (port 6379) |
| `bgutil-provider.yaml` | [bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider) (port 4416) |
| `deployment.yaml` | **`tubearchivist`** Deployment; **`TA_AUTO_UPDATE_YTDLP=release`**; **`Recreate`** strategy |
| `httproute.yaml` | `tubearchivist.net.ecksd.ee` |
| `securitypolicy-forward-auth.yaml` | Envoy forward-auth |

## Resources

| Workload | Request | Limit |
|----------|---------|-------|
| `archivist-es` | 1536Mi | 3Gi |
| `tubearchivist` | 768Mi | 1536Mi |
| `archivist-redis` | 64Mi | 256Mi |
| `bgutil-provider` | 128Mi | 384Mi |

## VPN egress

YouTube-related pods (`tubearchivist`, `bgutil-provider`) use **pod-gateway** label **`vpn-gateway: "true"`** ([vpn-gateway](../vpn-gateway/README.md)). Namespace **`allows-vpn-gateway: "true"`**. Elasticsearch and Redis stay on normal cluster routing.

## PO token provider

**Settings → Application → PO Token Provider URL**:

```text
http://bgutil-provider:4416
```

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/vpn-gateway" --enable-helm | kubectl apply -f -
kubectl apply -k "$HOME/Projects/xd-net-apps/apps/tubearchivist"
```

**Argo CD Image Updater** tracks `bbilly1/tubearchivist` via `kustomization.yaml` write-back in `apps/argocd-image-updater/image-updater.yaml`. Elasticsearch, Redis, and bgutil images are pinned in manifests and bumped manually.
