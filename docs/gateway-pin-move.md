# Gateway pin move

North/south traffic for `*.net.ecksd.ee` uses **Envoy Gateway** with a Cilium **LoadBalancer** VIP announced via **L2**. Both the Envoy proxy pods and the Cilium L2 announcement policy are pinned to one worker so `externalTrafficPolicy: Local` preserves client IPs.

Default pin: worker **`xd-w-2`** (`192.168.4.152`), label **`xd.ecksd.ee/gateway=true`**. Configured in **xd-net** `apps/` (`gateway_node_name`, `gateway_node_label`, `envoy_proxy_external_traffic_policy`).

## When to move

- Planned maintenance / EPHEMERAL wipe on `xd-w-2`
- Hardware failure on the pinned worker
- Need ingress up while the pinned node is down for longer than a reboot

Moving the pin is a short outage window: VIP ARP and Envoy pods relocate to the new worker.

## Procedure (Terraform)

Work in **xd-net** `apps/` (not this GitOps repo).

1. Pick a healthy worker that will own the VIP (example: `xd-w-1` or `xd-w-3`). Confirm it is Ready and has capacity.

2. Set the pin in gitignored `config.auto.tfvars` (or override for one apply):

   ```hcl
   gateway_node_name = "xd-w-1"
   # Keep Local when pinning so client IP still works:
   envoy_proxy_external_traffic_policy = "Local"
   ```

   Defaults for the label are already `xd.ecksd.ee/gateway = "true"` — do not change the key/value unless you also update every selector that uses `local.gateway_node_selector`.

3. Apply:

   ```bash
   cd ~/Projects/xd-net/apps
   terraform apply
   ```

   Terraform labels the target node (`kubernetes_labels.gateway_node`), updates Envoy Gateway Helm values (`nodeSelector`), and keeps `CiliumL2AnnouncementPolicy` `gateway-l2-announce` matched to that label.

4. Verify:

   ```bash
   kubectl get nodes -L xd.ecksd.ee/gateway
   kubectl -n envoy-gateway-system get pods -o wide
   kubectl get svc -A | grep -i gateway   # EXTERNAL-IP should stay in 192.168.4.201–210
   curl -sS -o /dev/null -w '%{http_code}\n' https://argocd.net.ecksd.ee/
   ```

   Only the new worker should show the gateway label. Envoy dataplane pods should schedule there. L2 announcement follows the same label.

5. Optional cleanup: remove the stale label from the old worker if Terraform did not (usually the `kubernetes_labels` resource moves with `gateway_node_name`):

   ```bash
   kubectl label node xd-w-2 xd.ecksd.ee/gateway-
   ```

## Notes

- Disabling the pin (`gateway_node_name = ""`) and using `envoy_proxy_external_traffic_policy = "Cluster"` is possible but changes client-IP behavior — avoid for Authentik / IP policies unless intentional.
- App-level L2 Services (for example Plex LAN) use a **separate** policy (`apps-l2-announce` / `ecksd.ee/l2-loadbalancer`) and are not moved by `gateway_node_name`.
- Pangolin public hostnames (`*.ecksd.ee` via the edge) are independent of this pin; only the homelab Gateway VIP path moves.
