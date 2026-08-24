# metrics-server

[Metrics Server](https://github.com/kubernetes-sigs/metrics-server) in **`kube-system`** — implements **`metrics.k8s.io`** for `kubectl top`, HPA, and the Homepage Kubernetes widget.

Upstream [**metrics-server** Helm chart](https://kubernetes-sigs.github.io/metrics-server/).

## Layout

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Helm release in **`kube-system`** |
| `values.yaml` | **`apiService.create`**, **`--kubelet-insecure-tls`** (homelab kubelet certs), resources |

## Apply

```bash
kubectl kustomize "$HOME/Projects/xd-net-apps/apps/metrics-server" --enable-helm | kubectl apply -f -
```

**Argo CD Image Updater** tracks `registry.k8s.io/metrics-server/metrics-server` in `apps/argocd-image-updater/image-updater.yaml`.

Helm chart version is pinned in **`kustomization.yaml`**.
