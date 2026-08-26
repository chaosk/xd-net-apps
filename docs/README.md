# Platform runbooks

Cluster-wide day-2 ops for the **xd-net** Talos cluster. Per-app install docs stay under `apps/<name>/README.md`; secrets inventory stays in `secrets/README.md`.

| Runbook | When to use |
|---------|-------------|
| [Worker EPHEMERAL wipe](worker-ephemeral-wipe.md) | Wedged containerd / sandbox timeouts on one worker |
| [CNPG restore](cnpg-restore.md) | Recover a CloudNativePG database after wipe or PVC loss |
| [Gateway pin move](gateway-pin-move.md) | Move shared Envoy Gateway + Cilium L2 off `xd-w-2` |
| [Pangolin rebuild](pangolin-rebuild.md) | Rebuild or re-deploy the OCI Pangolin edge VM |
| [Age / SOPS rotation](sops-age-rotation.md) | Rotate the Age key used by SOPS and Argo CD |

Platform Terraform lives in **[xd-net](https://github.com/chaosk/xd-net)** (`infra/`, `apps/`, `pangolin-edge/`). Cluster access notes: [`AGENTS.md`](../AGENTS.md).
