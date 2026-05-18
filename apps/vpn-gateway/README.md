# vpn-gateway

[pod-gateway](https://github.com/angelnu/pod-gateway) + Gluetun routes pod traffic through a VPN. The [gateway-admission-controller](https://github.com/angelnu/gateway-admision-controller) webhook injects init/sidecar into matching pods.

## Per-pod opt-in

- Webhook runs only in namespaces labeled **`allows-vpn-gateway: "true"`** (never on **`vpn-gateway`**).
- **`gatewayDefault: false`** — pods without the label are unchanged.
- Label pod template: **`vpn-gateway: "true"`** (ES/Redis stay off VPN).

```text
tubearchivist / bgutil (vpn-gateway=true)
  → VXLAN → vpn-gateway-pod-gateway-main.vpn-gateway.svc → Gluetun → VPN

archivist-es / archivist-redis (no label)
  → normal cluster routing
```

Helm release **`vpn-gateway`** (`angelnu-charts/pod-gateway`) via `kustomization.yaml` (`kubectl kustomize --enable-helm`). VPN credentials: `secrets/vpn-gateway.yaml` → Secret **`vpn-gateway`** in namespace **`vpn-gateway`**.

## Setup

1. SOPS-encrypt `secrets/vpn-gateway.yaml`, sync **platform-secrets**
2. `kubectl kustomize apps/vpn-gateway --enable-helm | kubectl apply -f -`
3. `kubectl apply -k apps/tubearchivist` (pods need **`vpn-gateway: "true"`** on template)

## Verify

```bash
kubectl get pods -n vpn-gateway -o wide
kubectl get pods -n tubearchivist -o wide

kubectl exec -n tubearchivist deploy/tubearchivist -c tubearchivist -- wget -qO- https://api.ipify.org
kubectl exec -n tubearchivist deploy/archivist-es -- wget -qO- https://api.ipify.org
```

After changing `values-pod-gateway.yaml` or the VPN secret:  
`kubectl rollout restart deployment -n vpn-gateway -l app.kubernetes.io/instance=vpn-gateway`

## Cluster DNS from VPN pods

Routed pods use gateway dnsmasq (`172.16.0.1`). `cluster.local` queries must be forwarded to **CoreDNS**, not Gluetun/VPN DNS. Set **`DNS_LOCAL_SERVER`** in `values-pod-gateway.yaml` to your kube-dns ClusterIP, and **`FIREWALL_OUTBOUND_SUBNETS`** on Gluetun so the gateway can reach Service/Pod networks.

```bash
kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}{"\n"}'
kubectl exec -n tubearchivist deploy/tubearchivist -c tubearchivist -- getent hosts archivist-redis.tubearchivist.svc.cluster.local
```

## Verify VPN egress

Routed pods have no IPv6 default route; use **IPv4** when testing public egress:

```bash
kubectl exec -n tubearchivist deploy/tubearchivist -c tubearchivist -- curl -4 -sS --max-time 15 https://api.ipify.org
kubectl exec -n tubearchivist deploy/archivist-es -- curl -4 -sS --max-time 15 https://api.ipify.org
```

The first command should print your VPN exit IP; the second should print your cluster/home IP.

## Add another VPN-routed pod

1. Label the namespace **`allows-vpn-gateway: "true"`** and add it under **`routed_namespaces`** in `values-pod-gateway.yaml`.
2. Add **`vpn-gateway: "true"`** to the pod template labels.
3. Re-apply vpn-gateway and recreate the pod.
