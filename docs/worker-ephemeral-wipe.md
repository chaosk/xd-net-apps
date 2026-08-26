# Worker EPHEMERAL wipe

Clear wedged containerd / kubelet state on a **worker**. Machine config is kept. The worker data disk (`scsi1` / UserVolume `local-path-data` at `/var/mnt/local-path-data`) is **not** wiped by `--system-labels-to-wipe EPHEMERAL`.

## Symptoms

On one worker: many pods stuck in `ContainerCreating` or `Init:0/1`, events like `FailedCreatePodSandBox` / `FailedKillPod` with `context deadline exceeded` or `sandbox name … is reserved for`, while the node may still show **Ready**. A normal `talosctl reboot` or deleting all pods at once often does not clear stale containerd state.

## Do not

- `talosctl restart containerd` (wrong target)
- `talosctl service cri restart` — Talos **blocks CRI restart via API** by design
- Wipe EPHEMERAL on **control plane** nodes without understanding etcd impact — this runbook is for **workers** (`xd-w-*`) only

## Procedure

Workers: **xd-w-1** `192.168.4.151`, **xd-w-2** `192.168.4.152`, **xd-w-3** `192.168.4.153` (Proxmox VMIDs 904–906).

```bash
kubectl cordon xd-w-2   # replace with the sick worker

talosctl -n 192.168.4.152 reset \
  --system-labels-to-wipe EPHEMERAL \
  --graceful=false \
  --reboot=true
```

After the node is **Ready** again, `kubectl uncordon` it and let pods recreate. Avoid mass-deleting every pod on the node at once — that can re-wedge containerd during recovery. Pods will re-pull images (slow once).

Optional: `talosctl -n <IP> service kubelet restart` may help for kubelet-only issues; it is usually **not** enough for wedged sandboxes.

If Talos reset fails or the VM is hung, hard-reset from Proxmox (xd-w-2 = VM **905**): `qm stop 905 --skiplock && sleep 30 && qm start 905`. Prefer EPHEMERAL wipe over repeated soft reboots when sandbox metadata is corrupt.

## What is wiped vs kept

| Kept | Wiped |
|------|-------|
| Machine config | containerd / kubelet state on the Talos OS disk |
| Worker data disk (`scsi1`) / UserVolume `local-path-data` (`/var/mnt/local-path-data`) | Image cache and other EPHEMERAL contents |

## Interaction with CNPG / local-path

CNPG clusters in this repo use `storageClass: local-path`. On these workers, Rancher local-path-provisioner writes under **`/var/mnt/local-path-data`**, which is the Talos **UserVolume** on the extra Proxmox disk (`scsi1` from `nvme_pool`) — see **xd-net** `infra/patches/local-path-user-volume.yaml.tmpl` and `apps` `local_path_default_path`.

An **EPHEMERAL** wipe therefore **does not** erase `local-path` PVC data (including `*-db` volumes). Pods still need to come back on the same node for those volumes to remount; after uncordon, CNPG should reattach to the existing data directory.

Still node-local and single-instance: destroying the VM disk, wiping that UserVolume, or losing the node without a backup remains data loss — see [CNPG restore](cnpg-restore.md).

Gateway note: shared Envoy + Cilium L2 are pinned to **`xd-w-2`**. Wiping that worker takes north/south ingress down until the node is Ready again (or until you [move the pin](gateway-pin-move.md)).
