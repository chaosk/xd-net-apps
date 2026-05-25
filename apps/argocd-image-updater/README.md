# Argo CD Image Updater

Deploys [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/) in the **`argocd`** namespace. Image tracking and Git write-back are configured in **`image-updater.yaml`** (`applicationRefs` per Argo CD Application name). No per-app files under `apps/<name>/` and no ApplicationSet merge in **xd-net**.

## Bot GitHub account (checklist)

Use a **dedicated GitHub account** (not your personal one). You need **two SSH key pairs** on that account:

| Key / token | Where it goes | xd-net → Secret |
|-------------|---------------|-----------------|
| **Deploy** | Repo **Deploy keys** ([xd-net-apps settings](https://github.com/chaosk/xd-net-apps/settings/keys)), **Allow write access** | `git_image_updater_ssh_private_key` → `argocd-image-updater-git` |
| **Signing** | Bot profile → **Settings → SSH and GPG keys → Signing keys** | `git_image_updater_signing_ssh_private_key` → `argocd-image-updater-signing` |
| **GHCR PAT** | Bot profile → **Settings → Developer settings → PAT** with **read:packages** | `ghcr_image_updater_token` (+ `ghcr_image_updater_username`) → `argocd-image-updater-ghcr` (`creds` = `user:token`) |

## Layout

| File | Purpose |
|------|---------|
| `values.yaml` | Helm chart: RBAC, Argo CD namespace, GHCR registry creds, Git user/email, commit signing mount |
| `image-updater.yaml` | `ImageUpdater` CR: git write-back + one `applicationRefs` entry per opted-in app |
| `image-updater.example.yaml` | Copy-paste templates for new apps (Helm vs Kustomize) |

## Opt in an app

1. Confirm the Argo CD Application name matches the app directory (e.g. `homepage`).
2. Add an `applicationRefs` block to `image-updater.yaml` (see `image-updater.example.yaml`).
3. Commit and sync the `argocd-image-updater` Application.

To disable updates for an app, remove its `applicationRefs` entry (or comment it out).

## Apply (local test)

```bash
kubectl kustomize "$REPO_ROOT/apps/argocd-image-updater" --enable-helm | kubectl apply -f -
```

After sync: `kubectl get imageupdater -n argocd` and `kubectl logs -n argocd deploy/argocd-image-updater-controller`.

Argo CD UI does not show a dedicated image-updater panel; use the `ImageUpdater` status and controller logs.
