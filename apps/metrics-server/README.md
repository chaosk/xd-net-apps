# metrics-server

[Metrics Server](https://github.com/kubernetes-sigs/metrics-server) implements the **`metrics.k8s.io`** API so tools can read node and pod CPU/memory (for example **`kubectl top`**, the Horizontal Pod Autoscaler, and the Homepage **kubernetes** widget).

This app installs the upstream [**metrics-server** Helm chart](https://kubernetes-sigs.github.io/metrics-server/) into **`kube-system`** (not the Argo app directory name).

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Helm chart **`metrics-server`** 3.12.2, namespace **`kube-system`**. |
| `values.yaml` | **`apiService.create`**, kubelet args (including **`--kubelet-insecure-tls`** for typical homelab kubelet certificates), resource requests/limits. |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/metrics-server" --enable-helm | kubectl apply -f -
```
