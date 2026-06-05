# Plex

[Plex Media Server](https://www.plex.tv/) is a media library and streaming stack. This app deploys the upstream **plex-media-server** Helm chart from the [Plex `pms-docker` chart repo](https://github.com/plexinc/pms-docker) (`https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages`), which packages the same image the project publishes for Docker.

`values.yaml` targets **Intel Quick Sync** via the **`gpu.intel.com/i915`** resource and a **`nodeSelector`** on `intel.feature.node.kubernetes.io/gpu`. Your cluster needs the [Intel device plugin for Kubernetes](https://github.com/intel/intel-device-plugins-for-kubernetes) (or equivalent) and labeled nodes, or change those fields to match how you expose transcoding.

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Namespace, **`pvc.yaml`**, **`nfs-media.yaml`**, **`httproute-pangolin.yaml`**, Helm chart **`plex-media-server`**. |
| `namespace.yaml` | **`plex`** namespace. |
| `pvc.yaml` | **`plex-config`** PVC (**Synology** `StorageClass` **`synology`**, **ReadWriteOnce**, **20Gi**) for Plex application data (`pms.configExistingClaim`). |
| `nfs-media.yaml` | Static **NFS** PV **`plex-media-pv`** + claim **`plex-media`** (**ReadWriteMany**, empty `storageClassName`) bound for the chart mount at **`/media`**. |
| `values.yaml` | **`fullnameOverride`**, **`httpRoute`** (**`plex.net.ecksd.ee`** on gateway **shared**, Homepage + **Tracearr** widget), **`nodeSelector`**, **`pms`**, NFS mounts, Intel GPU, **Tube Archivist Plex** init container. |
| `tubearchivist-plex-install.yaml` | ConfigMap script that installs [tubearchivist-plex](https://github.com/tubearchivist/tubearchivist-plex) **v0.1.8** on the Plex config PVC. |
| `httproute-pangolin.yaml` | **`plex.ecksd.ee`** only; **`pangolin-operator/site-ref: xd-net`** (separate from Helm route so Pangolin gets one public resource). |

## Before you apply

1. **`nfs-media.yaml`** — Set **`nfs.server`**, **`nfs.path`**, **`spec.capacity`** on the PV, and the PVC **`resources.requests.storage`** so they match your export (PVC requests must fit the PV capacity). Adjust **`mountOptions`** if your server needs something other than NFSv4.1.

2. **`pvc.yaml`** — Confirm **`storageClassName`**, access mode, and size for **`plex-config`** match what your storage provides.

3. **`values.yaml`** — Align **`httpRoute.hostnames`** and Gateway **`parentRefs`** with your cluster gateway and TLS names. **`nodeSelector`** and **`pms.resources`** must match nodes where Plex is allowed to run and how GPU is exposed; remove or replace **`gpu.intel.com/i915`** if you do not use the Intel plugin.

4. **NFS reachability** — Every node that can schedule Plex must reach the NFS export, or tighten **`nodeSelector`** / affinity so the pod only lands on allowed nodes.

5. **Pangolin** — **`NewtSite`** **`xd-net`** (xd-net). **`httproute-pangolin.yaml`** is the only route with **`site-ref`**; do not add Pangolin annotations on the Helm HTTPRoute or you will get duplicate public resources.

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/plex" --enable-helm | kubectl apply -f -
```

## After install

Open the URL from **`httpRoute.hostnames`**, complete Plex server setup, and add libraries under **`/media`** (for example **`/media/Movies`**). In **Settings → Transcoder**, enable **hardware acceleration** when the GPU path is working.

## Tube Archivist Plex integration

An init container installs [tubearchivist-plex](https://github.com/tubearchivist/tubearchivist-plex) **v0.1.8** on the Plex config volume before PMS starts. It writes **`ta_config.json`** with the in-cluster Tube Archivist URL (**`http://tubearchivist.tubearchivist.svc.cluster.local:8000`**) and API token from **`secrets/plex-tubearchivist-plex.yaml`** (same token as **`homepage-tubearchivist-widget`** — Tube Archivist **Settings → Application → API Token**).

Add a **TV Shows** library pointing at **`/media/youtube`** (NFS subpath under the shared media export). In **Manage Library → Edit → Advanced**, set **Scanner** to **TubeArchivist Scanner**, **Agent** to **TubeArchivist Agent**, and match the **TubeArchivist URL** / **API Key** fields to the in-cluster URL and token. Restart Plex after upgrading the integration (roll the StatefulSet).

## Logs in Grafana (Loki)

Plex writes **`Plex Media Server.log`** on the config volume, not to stdout. A **`log-tailer`** sidecar tails that file so cluster **Alloy** can forward it to Loki. Alloy parses Plex’s timestamp (UTC) and **`level`** (`DEBUG`, `INFO`, `WARN`, `ERROR`). In Grafana **Explore → Loki**, use `{namespace="plex", container="log-tailer"}` or `{namespace="plex", container="log-tailer", level="ERROR"}`.

## Upgrades

Bump **`helmCharts.version`** in **`kustomization.yaml`** to a published chart version from the **`pms-docker`** chart index, then re-apply. Read upstream release notes for image or value changes that affect your cluster.
