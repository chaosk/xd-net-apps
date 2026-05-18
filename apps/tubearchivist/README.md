# Tube Archivist

[Tube Archivist](https://www.tubearchivist.com/) archives and indexes YouTube subscriptions. This app runs the [official Docker stack](https://docs.tubearchivist.com/installation/docker-compose/) (Tube Archivist, Redis, Elasticsearch 8) on Kubernetes with **Gateway API** exposure. User docs: [https://docs.tubearchivist.com](https://docs.tubearchivist.com).

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, **`pvc.yaml`**, Elasticsearch, Redis, Tube Archivist Deployment, Service, HTTPRoute. |
| `namespace.yaml` | **`tubearchivist`** namespace; **Pod Security `privileged`** labels for Elasticsearch. |
| `pvc.yaml` | **`tubearchivist-youtube`**: static **NFS** PV + claim (**ReadWriteMany**, **`Retain`**). **`tubearchivist-cache`**, **`tubearchivist-redis`**, **`tubearchivist-es`**: **Synology** `storageClass` **`synology`** (**ReadWriteOnce**). |
| `elasticsearch.yaml` | **`archivist-es`** StatefulSet + Service (`bbilly1/tubearchivist-es:latest`, port **9200**). |
| `redis.yaml` | **`archivist-redis`** StatefulSet + Service (`redis:7-alpine`, port **6379**). |
| `bgutil-provider.yaml` | **[bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider)** (`brainicism/bgutil-ytdlp-pot-provider:1.3.1`, port **4416**). |
| `deployment.yaml` | **`tubearchivist`** Deployment (`bbilly1/tubearchivist:v0.5.10`), mounts **`/youtube`** and **`/cache`**, **`Recreate`** strategy. |
| `service.yaml` | ClusterIP **`tubearchivist`** → port **8000** (HTTPRoute backend). |
| `httproute.yaml` | Gateway **`shared`** in **`gateway`**; hostname **`tubearchivist.net.ecksd.ee`**. |

## PO token provider

Tube Archivist talks to the provider over the cluster network. After sync, set **Settings → Application → PO Token Provider URL** to:

```text
http://bgutil-provider:4416
```

See [Application settings](https://docs.tubearchivist.com/settings/application/#po-token-provider-url). The image tag matches **v0.5.10** (`bgutil-ytdlp-pot-provider==1.3.1` in upstream `requirements.plugins.txt`).

## Apply

```bash
kubectl apply -k "$HOME/Projects/xd-net-apps/apps/tubearchivist"
```
